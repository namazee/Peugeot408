import CarKit
import SwiftUI
import UIKit

/// The layer-based custom builder. The canvas uses the exact aspect ratio of the CarPlay small or
/// medium widget, drawn by the same `DesignView` the widget uses.
struct DesignBuilderView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    @Environment(\.dismiss) private var dismiss

    @State private var design: CardDesign
    @State private var undoStack: [CardDesign] = []
    @State private var redoStack: [CardDesign] = []
    @State private var selectedID: UUID?
    @State private var snapToGrid = true
    @State private var showSafeArea = true
    @State private var editingBackground = false
    @State private var exportURL: URL?
    /// Design before the current gesture started (one undo step per gesture).
    @State private var gestureStart: CardDesign?

    init(initial: CardDesign) {
        _design = State(initialValue: initial)
    }

    private var selectedIndex: Int? {
        selectedID.flatMap { id in design.layers.firstIndex { $0.id == id } }
    }

    private var warnings: [DesignLinter.Warning] { DesignLinter.warnings(for: design) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvas
                    .padding(16)
                    .background(Color.black)
                Form {
                    if !warnings.isEmpty {
                        Section {
                            ForEach(warnings, id: \.self) { warning in
                                Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.dueSoon)
                                    .onTapGesture { if let id = warning.layerID { selectedID = id } }
                            }
                        }
                    }
                    if let index = selectedIndex {
                        LayerInspector(layer: layerBinding(index), onDuplicate: { duplicate(index) }, onDelete: { delete(index) }, onMove: { move(index, by: $0) })
                    } else {
                        designSection
                        layersSection
                    }
                }
            }
            .navigationTitle(design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $editingBackground) {
                BackgroundEditor(background: Binding(get: { design.background }, set: { value in change { $0.background = value } }), photos: cars.data.photos.photos)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let size = fitted(geo.size)
            ZStack {
                DesignView(card: DesignResolver.card(for: design, data: cars.data, studio: studio.state, at: .now))
                if snapToGrid {
                    GridOverlay().allowsHitTesting(false)
                }
                if showSafeArea {
                    // CarPlay keeps about 8% clear at the edges (the widget's content margins).
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(size.height * 0.08)
                        .allowsHitTesting(false)
                }
                ForEach(design.layers.reversed()) { layer in
                    handle(for: layer, in: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { selectedID = nil }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: design.canvas == .small ? 240 : 190)
    }

    private func fitted(_ space: CGSize) -> CGSize {
        let ratio = design.canvas.aspectRatio
        let width = min(space.width, space.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func handle(for layer: DesignLayer, in size: CGSize) -> some View {
        let isSelected = layer.id == selectedID
        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay {
                if isSelected {
                    Rectangle().strokeBorder(layer.locked ? Theme.dueSoon : Theme.accent, lineWidth: 2)
                }
            }
            .frame(width: max(layer.width * size.width, 24), height: max(layer.height * size.height, 24))
            .rotationEffect(.degrees(layer.rotation))
            .position(x: layer.x * size.width, y: layer.y * size.height)
            .onTapGesture { selectedID = layer.id }
            .gesture(dragGesture(layer.id, size: size), including: isSelected && !layer.locked ? .all : .subviews)
            .simultaneousGesture(scaleGesture(layer.id), including: isSelected && !layer.locked ? .all : .subviews)
            .simultaneousGesture(rotateGesture(layer.id), including: isSelected && !layer.locked ? .all : .subviews)
    }

    private func dragGesture(_ id: UUID, size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                beginGesture()
                guard let start = gestureStart?.layers.first(where: { $0.id == id }),
                      let index = design.layers.firstIndex(where: { $0.id == id }) else { return }
                design.layers[index].x = snap(start.x + value.translation.width / size.width)
                design.layers[index].y = snap(start.y + value.translation.height / size.height)
            }
            .onEnded { _ in endGesture() }
    }

    private func scaleGesture(_ id: UUID) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                beginGesture()
                guard let start = gestureStart?.layers.first(where: { $0.id == id }),
                      let index = design.layers.firstIndex(where: { $0.id == id }) else { return }
                let factor = value.magnification
                design.layers[index].width = min(max(start.width * factor, 0.05), 1.5)
                design.layers[index].height = min(max(start.height * factor, 0.05), 1.5)
                if design.layers[index].isText {
                    design.layers[index].fontSize = min(max(start.fontSize * factor, 8), 90)
                }
            }
            .onEnded { _ in endGesture() }
    }

    private func rotateGesture(_ id: UUID) -> some Gesture {
        RotateGesture()
            .onChanged { value in
                beginGesture()
                guard let start = gestureStart?.layers.first(where: { $0.id == id }),
                      let index = design.layers.firstIndex(where: { $0.id == id }) else { return }
                var angle = start.rotation + value.rotation.degrees
                if snapToGrid { angle = (angle / 15).rounded() * 15 }
                design.layers[index].rotation = angle
            }
            .onEnded { _ in endGesture() }
    }

    /// Snaps to a 1/24 grid.
    private func snap(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return snapToGrid ? (clamped * 24).rounded() / 24 : clamped
    }

    private func beginGesture() {
        if gestureStart == nil { gestureStart = design }
    }

    private func endGesture() {
        if let start = gestureStart, start != design {
            undoStack.append(start)
            redoStack.removeAll()
        }
        gestureStart = nil
    }

    // MARK: Editing with undo

    /// Applies a change as one undo step.
    private func change(_ edit: (inout CardDesign) -> Void) {
        var next = design
        edit(&next)
        guard next != design else { return }
        undoStack.append(design)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
        design = next
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(design)
        design = previous
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(design)
        design = next
    }

    private func layerBinding(_ index: Int) -> Binding<DesignLayer> {
        Binding(
            get: { design.layers.indices.contains(index) ? design.layers[index] : DesignLayer(content: .text("")) },
            set: { value in
                guard design.layers.indices.contains(index) else { return }
                change { $0.layers[index] = value }
            }
        )
    }

    private func add(_ content: LayerContent) {
        var layer = DesignLayer(content: content)
        switch content {
        case .symbol, .sticker, .carPhoto, .analogClock, .gauge, .ring, .seasonalArt:
            layer.width = design.canvas == .small ? 0.4 : 0.22
            layer.height = 0.4
            layer.colorHex = content == .carPhoto ? 0xFFFFFF : Theme.Hex.accent
        case .progressBar:
            layer.width = 0.8
            layer.height = 0.08
            layer.colorHex = 0x34D399
        case .plate:
            layer.width = 0.4
            layer.height = 0.16
            layer.fontSize = 16
        case .data, .text:
            layer.fontSize = 24
        }
        change { $0.layers.append(layer) }
        selectedID = layer.id
    }

    private func duplicate(_ index: Int) {
        var copy = design.layers[index]
        copy.id = UUID()
        copy.x = min(copy.x + 0.05, 1)
        copy.y = min(copy.y + 0.05, 1)
        copy.locked = false
        change { $0.layers.insert(copy, at: index + 1) }
        selectedID = copy.id
    }

    private func delete(_ index: Int) {
        change { $0.layers.remove(at: index) }
        selectedID = nil
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard design.layers.indices.contains(target) else { return }
        change { $0.layers.swapAt(index, target) }
    }

    // MARK: Sections

    private var designSection: some View {
        Section("Design") {
            TextField("Name", text: Binding(get: { design.name }, set: { name in change { $0.name = name } }))
            Picker("Size", selection: Binding(get: { design.canvas }, set: { canvas in change { $0.canvas = canvas } })) {
                ForEach(DesignCanvas.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Button {
                editingBackground = true
            } label: {
                Label("Background", systemImage: "square.fill.on.square.fill")
            }
            if design.dataFields.contains(.dayCounter) || design.dataFields.contains(.countdownDays) {
                DatePicker("Event date", selection: Binding(get: { design.eventDate ?? .now }, set: { date in change { $0.eventDate = date } }), displayedComponents: .date)
            }
            Toggle("Snap to grid", isOn: $snapToGrid)
            Toggle("Show safe area", isOn: $showSafeArea)
        }
    }

    private var layersSection: some View {
        Section {
            ForEach(design.layers.reversed()) { layer in
                Button {
                    selectedID = layer.id
                } label: {
                    HStack {
                        Text(layerName(layer))
                        Spacer()
                        if layer.locked { Image(systemName: "lock.fill").foregroundStyle(Theme.secondaryText) }
                    }
                }
            }
            if design.layers.isEmpty {
                Text("Add a layer with the + button.").foregroundStyle(Theme.secondaryText)
            }
        } header: {
            Text("Layers (top first)")
        } footer: {
            Text("Tap a layer on the canvas to select it, then drag to move, pinch to resize and twist to rotate.")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(undoStack.isEmpty)
                .accessibilityLabel("Undo")
            Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(redoStack.isEmpty)
                .accessibilityLabel("Redo")
            Menu {
                Button("Text", systemImage: "textformat") { add(.text("Text")) }
                Menu("Data field", systemImage: "chart.bar.doc.horizontal") {
                    ForEach(DataField.allCases) { field in
                        Button(field.displayName) { add(.data(field)) }
                    }
                }
                Menu("Icon", systemImage: "star") {
                    ForEach(SlotDesign.symbolChoices, id: \.self) { name in
                        Button(name, systemImage: name) { add(.symbol(name)) }
                    }
                }
                Menu("Seasonal art", systemImage: "sparkles") {
                    ForEach(SeasonalOccasion.allCases) { occasion in
                        Button(occasion.displayName) { add(.seasonalArt(occasion)) }
                    }
                }
                Menu("Sticker", systemImage: "seal") {
                    ForEach(ArtworkKind.stickers, id: \.self) { kind in
                        Button(kind.displayName) { add(.sticker(kind)) }
                    }
                }
                Button("My Car photo", systemImage: "car.side") { add(.carPhoto) }
                Button("Number plate", systemImage: "rectangle.and.text.magnifyingglass") { add(.plate("")) }
                Button("Gauge", systemImage: "gauge.with.dots.needle.67percent") { add(.gauge(.kmToService)) }
                Button("Progress ring", systemImage: "circle.dashed") { add(.ring(.kmToService)) }
                Button("Progress bar", systemImage: "chart.bar.fill") { add(.progressBar(.yearProgress)) }
                Button("Analogue clock", systemImage: "clock") { add(.analogClock) }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add layer")
        }
        ToolbarItemGroup(placement: .bottomBar) {
            if let url = exportURL {
                ShareLink(item: url) { Label("Export", systemImage: "square.and.arrow.up") }
            } else {
                Button("Export", systemImage: "square.and.arrow.up") { exportURL = studio.exportURL(for: design) }
            }
            Spacer()
            Button("Save") {
                studio.save(design)
                dismiss()
            }
            .bold()
            .disabled(DesignLinter.blocksSaving(design))
        }
    }

    private func layerName(_ layer: DesignLayer) -> String {
        switch layer.content {
        case .text(let text): "Text: \(text)"
        case .symbol(let name): "Icon: \(name)"
        case .sticker(let kind): "Sticker: \(kind.displayName)"
        case .carPhoto: "My Car photo"
        case .data(let field): "Data: \(field.displayName)"
        case .gauge(let field): "Gauge: \(field?.displayName ?? "decorative")"
        case .ring(let field): "Ring: \(field?.displayName ?? "decorative")"
        case .progressBar(let field): "Bar: \(field?.displayName ?? "decorative")"
        case .analogClock: "Analogue clock"
        case .plate(let text): "Plate \(text)"
        case .seasonalArt(let occasion): "Art: \(occasion.displayName)"
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            for i in 1..<6 {
                let x = size.width * Double(i) / 6
                let y = size.height * Double(i) / 6
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(.white.opacity(0.08)))
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(.white.opacity(0.08)))
            }
        }
    }
}

/// Per-layer settings: content, font, colour, size, rotation, opacity, shadow, lock.
private struct LayerInspector: View {
    @Binding var layer: DesignLayer
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        Section("Layer") {
            contentEditor
            if layer.isText {
                Picker("Font", selection: $layer.font) {
                    ForEach(DesignFont.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Weight", selection: $layer.weight) {
                    ForEach(DesignWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                LabeledSlider(title: "Size", value: $layer.fontSize, range: 8...90, format: "%.0f pt")
                Picker("Align", selection: $layer.alignment) {
                    ForEach(DesignAlignment.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ColorPicker("Colour", selection: color, supportsOpacity: false)
            LabeledSlider(title: "Opacity", value: $layer.opacity, range: 0.1...1, format: "%.0f%%", scale: 100)
            LabeledSlider(title: "Rotation", value: $layer.rotation, range: -180...180, format: "%.0f°")
            LabeledSlider(title: "Width", value: $layer.width, range: 0.05...1.5, format: "%.0f%%", scale: 100)
            LabeledSlider(title: "Height", value: $layer.height, range: 0.05...1.5, format: "%.0f%%", scale: 100)
            Toggle("Shadow", isOn: $layer.shadow)
            Toggle("Neon glow", isOn: Binding(get: { layer.glow == true }, set: { layer.glow = $0 ? true : nil }))
            Toggle("Lock", isOn: $layer.locked)
        }
        Section {
            Button("Bring forward", systemImage: "square.2.layers.3d.top.filled") { onMove(1) }
            Button("Send backward", systemImage: "square.2.layers.3d.bottom.filled") { onMove(-1) }
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
            Button("Delete layer", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var contentEditor: some View {
        switch layer.content {
        case .text(let text):
            TextField("Text", text: Binding(get: { text }, set: { layer.content = .text($0) }))
        case .plate(let text):
            TextField("Plate (empty = from My Car)", text: Binding(get: { text }, set: { layer.content = .plate($0) }))
        case .data(let field):
            Picker("Shows", selection: Binding(get: { field }, set: { layer.content = .data($0) })) {
                ForEach(DataField.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Small label (optional)", text: Binding(get: { layer.caption ?? "" }, set: { layer.caption = $0.isEmpty ? nil : $0 }))
        case .gauge(let field):
            progressPicker(field) { layer.content = .gauge($0) }
        case .ring(let field):
            progressPicker(field) { layer.content = .ring($0) }
        case .progressBar(let field):
            progressPicker(field) { layer.content = .progressBar($0) }
        case .symbol(let name):
            Picker("Icon", selection: Binding(get: { name }, set: { layer.content = .symbol($0) })) {
                ForEach(SlotDesign.symbolChoices, id: \.self) { Label($0, systemImage: $0).tag($0) }
            }
        case .sticker(let kind):
            Picker("Sticker", selection: Binding(get: { kind }, set: { layer.content = .sticker($0) })) {
                ForEach(ArtworkKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        case .carPhoto:
            Text("Set the photo in Studio → My Car photo.").foregroundStyle(Theme.secondaryText)
        case .analogClock:
            Text("Shows the time; the hands move every minute.").foregroundStyle(Theme.secondaryText)
        case .seasonalArt(let occasion):
            Picker("Artwork", selection: Binding(get: { occasion }, set: { layer.content = .seasonalArt($0) })) {
                ForEach(SeasonalOccasion.allCases) { Text($0.displayName).tag($0) }
            }
        }
    }

    /// Fields that have a 0…1 progress, for gauges, rings and bars.
    private func progressPicker(_ field: DataField?, set: @escaping (DataField?) -> Void) -> some View {
        Picker("Fills with", selection: Binding(get: { field }, set: set)) {
            Text("Nothing (decorative)").tag(DataField?.none)
            ForEach([DataField.kmToService, .kmPerLitre, .tngBalance, .daysToRoadTax, .airQuality, .yearProgress, .boost, .engineRPM], id: \.self) {
                Text($0.displayName).tag(DataField?.some($0))
            }
        }
    }

    private var color: Binding<Color> {
        Binding(
            get: { Color(hex: layer.colorHex) },
            set: { layer.colorHex = $0.hexValue }
        )
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var scale: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title, value: String(format: format, value * scale))
            Slider(value: $value, in: range)
        }
    }
}

private struct BackgroundEditor: View {
    @Binding var background: DesignBackground
    let photos: [PhotoItem]

    private enum Kind: String, CaseIterable { case solid, gradient, aurora, glow, texture, photo, state }

    private var kind: Kind {
        switch background {
        case .solid: .solid
        case .gradient: .gradient
        case .aurora: .aurora
        case .spotlight: .glow
        case .texture: .texture
        case .photo: .photo
        case .stateColor: .state
        }
    }

    var body: some View {
        Form {
            Picker("Type", selection: Binding(get: { kind }, set: { setKind($0) })) {
                ForEach(Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.menu)
            switch background {
            case .solid(let hex):
                ColorPicker("Colour", selection: Binding(get: { Color(hex: hex) }, set: { background = .solid($0.hexValue) }), supportsOpacity: false)
            case .gradient(let a, let b):
                ColorPicker("From", selection: Binding(get: { Color(hex: a) }, set: { background = .gradient($0.hexValue, b) }), supportsOpacity: false)
                ColorPicker("To", selection: Binding(get: { Color(hex: b) }, set: { background = .gradient(a, $0.hexValue) }), supportsOpacity: false)
            case .texture(let texture, let hex):
                Picker("Texture", selection: Binding(get: { texture }, set: { background = .texture($0, hex) })) {
                    ForEach(DesignTexture.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                ColorPicker("Base colour", selection: Binding(get: { Color(hex: hex) }, set: { background = .texture(texture, $0.hexValue) }), supportsOpacity: false)
            case .aurora(let a, let b, let c):
                ColorPicker("Colour 1", selection: Binding(get: { Color(hex: a) }, set: { background = .aurora($0.hexValue, b, c) }), supportsOpacity: false)
                ColorPicker("Colour 2", selection: Binding(get: { Color(hex: b) }, set: { background = .aurora(a, $0.hexValue, c) }), supportsOpacity: false)
                ColorPicker("Colour 3", selection: Binding(get: { Color(hex: c) }, set: { background = .aurora(a, b, $0.hexValue) }), supportsOpacity: false)
            case .spotlight(let centre, let edge):
                ColorPicker("Centre", selection: Binding(get: { Color(hex: centre) }, set: { background = .spotlight($0.hexValue, edge) }), supportsOpacity: false)
                ColorPicker("Edge", selection: Binding(get: { Color(hex: edge) }, set: { background = .spotlight(centre, $0.hexValue) }), supportsOpacity: false)
            case .stateColor(let hex):
                ColorPicker("Colour when all is fine", selection: Binding(get: { Color(hex: hex) }, set: { background = .stateColor($0.hexValue) }), supportsOpacity: false)
                Text("Turns amber when due soon, red when overdue, and the haze band colour for air quality.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            case .photo(let file):
                if photos.isEmpty {
                    Text("Add photos in Studio → Photo Frame first.").foregroundStyle(Theme.secondaryText)
                } else {
                    Picker("Photo", selection: Binding(get: { file }, set: { background = .photo($0) })) {
                        ForEach(photos) { Text($0.addedAt.formatted(date: .abbreviated, time: .shortened)).tag($0.fileName) }
                    }
                }
            }
        }
    }

    private func setKind(_ kind: Kind) {
        switch kind {
        case .solid: background = .solid(Theme.Hex.background)
        case .gradient: background = .gradient(Theme.Hex.accent, Theme.Hex.background)
        case .aurora: background = .aurora(0x6D28D9, 0x0EA5E9, 0xEC4899)
        case .glow: background = .spotlight(0x2B4C9E, 0x05070D)
        case .state: background = .stateColor(0x1F4FD8)
        case .texture: background = .texture(.carbon, 0x111318)
        case .photo: background = .photo(photos.first?.fileName ?? "")
        }
    }
}

extension Color {
    /// 0xRRGGBB of this colour (sRGB).
    var hexValue: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return channel(r) << 16 | channel(g) << 8 | channel(b)
    }
}
