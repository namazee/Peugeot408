import CarKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import Vision

/// Background removal with Vision (fully on-device), plus a mask that can be touched up.
enum CarCutout {
    enum CutoutError: Error, LocalizedError {
        case unreadable
        case noSubject

        var errorDescription: String? {
            switch self {
            case .unreadable: "Couldn't read that photo."
            case .noSubject: "No subject found. Try a photo where the car stands out from the background."
            }
        }
    }

    /// The photo (downsampled to 1,200 px for editing) and its foreground mask (white = keep).
    static func makeMask(from data: Data) async throws -> (image: UIImage, mask: UIImage) {
        guard let jpeg = ImageDownsampler.jpeg(from: data, maxPixelSize: 1_200, quality: 0.95),
              let image = UIImage(data: jpeg), let cgImage = image.cgImage else { throw CutoutError.unreadable }
        // A nonisolated async function, so Vision runs off the main thread.
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else { throw CutoutError.noSubject }
        let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        let ciMask = CIImage(cvPixelBuffer: buffer)
        guard let maskCG = CIContext().createCGImage(ciMask, from: ciMask.extent) else { throw CutoutError.noSubject }
        return (UIImage(cgImage: cgImage), UIImage(cgImage: maskCG))
    }

    /// Photo with the mask applied, cropped to the car and downsampled to 600 px (widget size).
    static func composite(image: UIImage, mask: UIImage, maxPixelSize: Double = 600) -> UIImage? {
        guard let cgImage = image.cgImage, let maskCG = mask.cgImage else { return nil }
        let source = CIImage(cgImage: cgImage)
        var maskImage = CIImage(cgImage: maskCG)
        // Match sizes in case the mask came back at a different scale.
        maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: source.extent.width / maskImage.extent.width, y: source.extent.height / maskImage.extent.height))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = CIImage.empty().cropped(to: source.extent)
        blend.maskImage = maskImage
        guard let output = blend.outputImage else { return nil }
        let context = CIContext()
        guard let full = context.createCGImage(output, from: source.extent) else { return nil }
        let bounds = opaqueBounds(of: maskCG, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) ?? CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        guard let cropped = full.cropping(to: bounds) else { return nil }
        let scale = min(1, maxPixelSize / max(bounds.width, bounds.height))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Bounding box of mask pixels that are mostly white, in image pixels.
    static func opaqueBounds(of mask: CGImage, imageSize: CGSize) -> CGRect? {
        let width = 200, height = max(1, Int(200 * Double(mask.height) / Double(mask.width)))
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] > 128 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let sx = imageSize.width / Double(width), sy = imageSize.height / Double(height)
        // CGContext rows start at the bottom; flip to top-left origin.
        let rect = CGRect(x: Double(minX) * sx, y: Double(height - 1 - maxY) * sy, width: Double(maxX - minX + 1) * sx, height: Double(maxY - minY + 1) * sy)
        return rect.insetBy(dx: -8, dy: -8).intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Paints a stroke into the mask: white restores, black erases.
    static func paint(_ points: [CGPoint], width: Double, restore: Bool, on mask: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = mask.scale
        return UIGraphicsImageRenderer(size: mask.size, format: format).image { context in
            mask.draw(at: .zero)
            let cg = context.cgContext
            cg.setStrokeColor(restore ? UIColor.white.cgColor : UIColor.black.cgColor)
            cg.setLineWidth(width)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            guard let first = points.first else { return }
            cg.move(to: first)
            for point in points.dropFirst() { cg.addLine(to: point) }
            if points.count == 1 { cg.addLine(to: first) }
            cg.strokePath()
        }
    }
}

/// Studio → My Car photo: pick, cut out, touch up, save; plus the number plate and the My Car template.
struct MyCarView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    let onCreateDesign: (CardDesign) -> Void

    @State private var picked: PhotosPickerItem?
    @State private var working = false
    @State private var message: String?
    @State private var image: UIImage?
    @State private var mask: UIImage?
    @State private var maskHistory: [UIImage] = []
    @State private var restoreMode = false
    @State private var brush: Double = 40
    @State private var stroke: [CGPoint] = []
    @State private var preview: UIImage?
    @State private var plate = ""

    var body: some View {
        List {
            Section {
                if let preview {
                    editor(preview)
                } else if let path = savedPath, let saved = UIImage(contentsOfFile: path) {
                    Image(uiImage: saved)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .background(Checkerboard())
                }
                PhotosPicker(selection: $picked, matching: .images) {
                    Label(studio.state.carPhotoFile == nil ? "Choose a photo of your car" : "Choose a different photo", systemImage: "photo")
                }
                if working { ProgressView("Removing the background…") }
                if let message { Text(message).font(.footnote).foregroundStyle(Theme.secondaryText) }
            } footer: {
                Text("The background is removed on your iPhone with Apple's Vision framework; the photo never leaves the phone.")
            }

            if preview != nil {
                Section("Touch up") {
                    Picker("Brush", selection: $restoreMode) {
                        Text("Erase").tag(false)
                        Text("Restore").tag(true)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        LabeledContent("Brush size", value: "\(Int(brush)) px")
                        Slider(value: $brush, in: 10...120)
                    }
                    Button("Undo last stroke", systemImage: "arrow.uturn.backward") { undoStroke() }
                        .disabled(maskHistory.isEmpty)
                    Button("Save cut-out", systemImage: "checkmark.circle.fill") { save() }
                        .bold()
                }
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(BuiltInCarPhoto.all) { photo in
                            Button {
                                studio.useBuiltInCarPhoto(photo.id)
                                message = "Using the built-in \(photo.name.lowercased()) photo."
                            } label: {
                                VStack(spacing: 4) {
                                    BuiltInThumb(resource: photo.resource)
                                        .frame(width: 120, height: 72)
                                        .background(Checkerboard())
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(studio.state.builtInCarPhoto == photo.id ? Theme.accent : .clear, lineWidth: 2)
                                        )
                                    Text(photo.name).font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use the built-in \(photo.name) photo")
                        }
                    }
                    .padding(.vertical, 4)
                }
                if studio.state.builtInCarPhoto != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paint colour").font(.subheadline.weight(.semibold))
                        HStack(spacing: 12) {
                            ForEach(PaintRecolor.presets) { preset in
                                Button {
                                    studio.setPaint(preset.hex)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: preset.hex ?? 0x1A6FB5))
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                                        .overlay(
                                            Circle().strokeBorder(Theme.accent, lineWidth: studio.state.carPaintHex == preset.hex ? 3 : 0).padding(-4)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(preset.name)
                            }
                            ColorPicker("Any colour", selection: customPaint, supportsOpacity: false)
                                .labelsHidden()
                        }
                        Text(PaintRecolor.presets.first { $0.hex == studio.state.carPaintHex }?.name ?? "Custom colour")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Built-in photos")
            } footer: {
                Text(studio.state.builtInCarPhoto == nil ? "You're using your own photo. Tap one of these to switch back." : "Badges are blurred. Choose your own photo above to replace these.")
            }

            Section {
                TextField("e.g. VKL 408", text: $plate)
                    .textInputAutocapitalization(.characters)
                    .onSubmit { studio.setPlate(plate) }
                Button("Save plate") { studio.setPlate(plate) }
                    .disabled(plate == studio.state.plateText)
                Picker("Plate font", selection: Binding(get: { studio.state.plateFont ?? .classic }, set: { studio.setPlateFont($0) })) {
                    ForEach(PlateFont.allCases) { font in
                        Text(font.displayName).font(font.font(size: 17)).tag(font)
                    }
                }
                HStack {
                    Spacer()
                    Text(plate.isEmpty ? "ABC 408" : plate.uppercased())
                        .font((studio.state.plateFont ?? .classic).font(size: 26))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.black))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.8), lineWidth: 2))
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("Number-plate label")
            } footer: {
                Text("Optional. Drawn as a black plate with white characters on the built-in photos (front, front ¾, rear ¾, front detail) and in plate layers. Leave empty to keep the original \"408\" plate.")
            }

            Section {
                ForEach(DesignCanvas.allCases, id: \.self) { canvas in
                    Button {
                        onCreateDesign(Templates.make(.myCar, source: .service, canvas: canvas))
                    } label: {
                        Label("New \(canvas.displayName.lowercased()) My Car design", systemImage: "plus.square.on.square")
                    }
                }
            } footer: {
                Text("Your car over an Obsession Blue gradient with a data line underneath (change it in the builder).")
            }
        }
        .navigationTitle("My Car")
        .onAppear { plate = studio.state.plateText }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var customPaint: Binding<Color> {
        Binding(
            get: { Color(hex: studio.state.carPaintHex ?? 0x1A6FB5) },
            set: { studio.setPaint($0.hexValue) }
        )
    }

    private var savedPath: String? {
        studio.state.carPhotoFile.map { studio.directory.appending(path: $0, directoryHint: .notDirectory).path(percentEncoded: false) }
    }

    /// The cut-out over a checkerboard; drag to paint the mask.
    private func editor(_ preview: UIImage) -> some View {
        GeometryReader { geo in
            let fit = fittedRect(imageSize: image?.size ?? preview.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Checkerboard()
                if let image {
                    Image(uiImage: image).resizable().frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY).opacity(0.15)
                }
                if let masked = maskedPreview {
                    Image(uiImage: masked).resizable().frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY)
                }
                Path { path in
                    guard let first = stroke.first else { return }
                    path.move(to: first)
                    for point in stroke.dropFirst() { path.addLine(to: point) }
                }
                .stroke(restoreMode ? Color.green.opacity(0.6) : Color.red.opacity(0.6), style: StrokeStyle(lineWidth: brush * fit.width / Double(image?.size.width ?? 1), lineCap: .round, lineJoin: .round))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { stroke.append($0.location) }
                    .onEnded { _ in applyStroke(fit: fit) }
            )
        }
        .frame(height: 280)
    }

    /// Fast on-screen preview: the photo masked with the current mask (full res, no crop).
    private var maskedPreview: UIImage? {
        guard let image, let mask else { return nil }
        guard let cg = image.cgImage, let maskCG = mask.cgImage else { return nil }
        let blend = CIFilter.blendWithMask()
        let source = CIImage(cgImage: cg)
        blend.inputImage = source
        blend.backgroundImage = CIImage.empty().cropped(to: source.extent)
        var m = CIImage(cgImage: maskCG)
        m = m.transformed(by: CGAffineTransform(scaleX: source.extent.width / m.extent.width, y: source.extent.height / m.extent.height))
        blend.maskImage = m
        guard let output = blend.outputImage, let result = CIContext().createCGImage(output, from: source.extent) else { return nil }
        return UIImage(cgImage: result)
    }

    private func fittedRect(imageSize: CGSize, in space: CGSize) -> CGRect {
        let scale = min(space.width / max(imageSize.width, 1), space.height / max(imageSize.height, 1))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (space.width - size.width) / 2, y: (space.height - size.height) / 2, width: size.width, height: size.height)
    }

    private func applyStroke(fit: CGRect) {
        defer { stroke = [] }
        guard let image, let mask, !stroke.isEmpty, fit.width > 0 else { return }
        // Screen points → mask pixels.
        let sx = mask.size.width / fit.width, sy = mask.size.height / fit.height
        let points = stroke.map { CGPoint(x: ($0.x - fit.minX) * sx, y: ($0.y - fit.minY) * sy) }
        maskHistory.append(mask)
        if maskHistory.count > 20 { maskHistory.removeFirst() }
        self.mask = CarCutout.paint(points, width: brush * mask.size.width / image.size.width, restore: restoreMode, on: mask)
        preview = self.mask
    }

    private func undoStroke() {
        guard let previous = maskHistory.popLast() else { return }
        mask = previous
        preview = previous
    }

    private func load(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false; picked = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            message = "Couldn't load that photo."
            return
        }
        do {
            let result = try await CarCutout.makeMask(from: data)
            image = result.image
            mask = result.mask
            maskHistory = []
            preview = result.mask
            message = "Check the edges, touch up with the brush if needed, then tap Save cut-out."
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let image, let mask, let cutout = CarCutout.composite(image: image, mask: mask), let png = cutout.pngData() else {
            message = "Couldn't make the cut-out."
            return
        }
        do {
            try png.write(to: studio.directory.appending(path: StudioState.carPhotoFileName, directoryHint: .notDirectory), options: .atomic)
            studio.setCustomCarPhoto()
            self.preview = nil
            self.image = nil
            self.mask = nil
            message = "Saved. Designs with a My Car layer now show it."
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

/// Grey checkerboard behind transparent images.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell = 10.0
            var y = 0.0
            var row = 0
            while y < size.height {
                var x = row.isMultiple(of: 2) ? 0 : cell
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(.white.opacity(0.08)))
                    x += cell * 2
                }
                y += cell
                row += 1
            }
        }
    }
}

private struct BuiltInThumb: View {
    let resource: String

    var body: some View {
        if let url = Bundle.main.url(forResource: resource, withExtension: "png"), let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFit().padding(4)
        } else {
            Image(systemName: "car.side").foregroundStyle(Theme.secondaryText)
        }
    }
}
