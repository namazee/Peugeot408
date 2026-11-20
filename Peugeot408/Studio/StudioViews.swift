import CarKit
import SwiftUI
import UniformTypeIdentifiers

/// Studio tab: designs, template gallery, seasonal packs, My Car, data sources.
struct StudioView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    @Binding var path: [DataSource]
    @State private var importing = false
    @State private var building: CardDesign?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink {
                        TemplateGalleryView { building = $0 }
                    } label: {
                        Label("Template gallery", systemImage: "square.grid.2x2")
                    }
                    Button {
                        building = CardDesign(name: "My design")
                    } label: {
                        Label("New blank design", systemImage: "plus.square.dashed")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Import a design file", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Create")
                }

                if !studio.state.designs.isEmpty {
                    Section {
                        ForEach(studio.state.designs) { design in
                            Button {
                                building = design
                            } label: {
                                DesignRow(design: design)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            studio.delete(Set(offsets.map { studio.state.designs[$0].id }))
                        }
                    } header: {
                        Text("My designs")
                    } footer: {
                        Text("Assign a design to a Car Slot on the Slots tab (Shows → Studio designs).")
                    }
                }

                Section("Extras") {
                    NavigationLink {
                        SeasonalPacksView()
                    } label: {
                        Label("Seasonal packs", systemImage: "sparkles")
                    }
                    NavigationLink {
                        MyCarView { building = $0 }
                    } label: {
                        Label("My Car photo", systemImage: "car.side")
                    }
                }

                Section("Data sources") {
                    ForEach([DataSource.map, .photos, .music]) { source in
                        NavigationLink(value: source) {
                            Label(source.displayName, systemImage: source.symbol)
                        }
                    }
                }

                Section("Sound") {
                    NavigationLink {
                        ConnectSoundView()
                    } label: {
                        Label("Connect sounds", systemImage: "speaker.wave.2.fill")
                    }
                }

                if let error = studio.lastError {
                    Section { Text(error).foregroundStyle(Theme.overdue) }
                }
            }
            .navigationTitle("Studio")
            .navigationDestination(for: DataSource.self) { DataSourceScreen(source: $0) }
            .fullScreenCover(item: $building) { design in
                DesignBuilderView(initial: design)
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { studio.importDesign(from: url) }
            }
        }
    }
}

struct DesignRow: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    let design: CardDesign

    var body: some View {
        HStack(spacing: 12) {
            DesignView(card: DesignResolver.card(for: design, data: cars.data, studio: studio.state, at: .now))
                .frame(width: design.canvas == .small ? 64 : 120, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(design.name).font(.headline)
                Text("\(design.canvas.displayName) · \(design.layers.count) layers")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                let warnings = DesignLinter.warnings(for: design)
                if !warnings.isEmpty {
                    Label("\(warnings.count) glanceability warning\(warnings.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.dueSoon)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

/// Every template with live previews from your real data, bindable to any data source.
struct TemplateGalleryView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    @Environment(\.dismiss) private var dismiss
    let onPick: (CardDesign) -> Void

    @State private var source: DataSource = .service
    @State private var canvas: DesignCanvas = .small

    var body: some View {
        List {
            Section {
                Picker("Size", selection: $canvas) {
                    ForEach(DesignCanvas.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Data", selection: $source) {
                    ForEach(DataSource.allCases) { Label($0.displayName, systemImage: $0.symbol).tag($0) }
                }
            } footer: {
                Text("Previews use your real data. Pick one to open it in the builder.")
            }

            ForEach(TemplateGroup.allCases) { group in
                Section(group.displayName) {
                    let columns = [GridItem(.adaptive(minimum: canvas == .small ? 140 : 300), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(group.styles) { style in
                            let design = template(style)
                            Button {
                                onPick(design)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    DesignView(card: DesignResolver.card(for: design, data: cars.data, studio: studio.state, at: .now))
                                        .aspectRatio(canvas.aspectRatio, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    HStack(spacing: 6) {
                                        Text(style.displayName).font(.subheadline.weight(.semibold))
                                        if style.isNew {
                                            Text("NEW")
                                                .font(.caption2.weight(.heavy))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Theme.accent, in: Capsule())
                                                .accessibilityLabel("New")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Templates")
    }

    private func template(_ style: TemplateStyle) -> CardDesign {
        let photo = cars.data.photos.photos.first?.fileName
        let anniversary = Calendar.current.date(byAdding: .day, value: -(9 * 365 + 213), to: .now)
        let countdown = Calendar.current.date(byAdding: .day, value: 42, to: .now)
        return Templates.make(
            style,
            source: source,
            canvas: canvas,
            photoFile: photo,
            eventDate: style == .anniversary ? anniversary : (style == .countdown ? countdown : nil),
            eventName: style == .countdown ? "Holiday" : "Married"
        )
    }
}

/// Seasonal packs: automatic takeover of one slot on the right dates.
struct SeasonalPacksView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars

    private var settings: SeasonalSettings { studio.state.seasonal }
    private let year = Calendar.current.component(.year, from: .now)

    var body: some View {
        List {
            Section {
                Toggle("Switch automatically", isOn: binding(\.enabled))
                Picker("Car Slot", selection: binding(\.slot)) {
                    ForEach(SlotsState.slotNumbers, id: \.self) { Text("Slot \($0)").tag($0) }
                }
                if let active = SeasonalCalendar.active(at: .now, settings: settings) {
                    Label("Now: \(active.displayName)", systemImage: "sparkles").foregroundStyle(Theme.accent)
                }
            } footer: {
                Text("On these dates the chosen slot shows the pack's design, then goes back to its normal design. Islamic dates follow the Umm al-Qura calendar and may differ from JAKIM's announcement by a day, so packs start a day or two early.")
            }

            Section("Packs") {
                ForEach(SeasonalOccasion.allCases) { occasion in
                    HStack(spacing: 12) {
                        DesignView(card: DesignResolver.card(for: Templates.seasonal(occasion), data: cars.data, studio: studio.state, at: .now))
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(occasion.displayName).font(.headline)
                            Text(nextText(occasion)).font(.subheadline).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: enabled(occasion)).labelsHidden()
                    }
                }
            }

            Section {
                ForEach(settings.deepavaliDates.keys.sorted(), id: \.self) { year in
                    DatePicker(String(year), selection: deepavali(year), displayedComponents: .date)
                }
            } header: {
                Text("Deepavali dates")
            } footer: {
                Text("Deepavali follows the Hindu calendar, which iOS doesn't have. 2026 and 2027 are confirmed; later years are estimates, so check them against the official holiday list.")
            }
        }
        .navigationTitle("Seasonal packs")
    }

    private func nextText(_ occasion: SeasonalOccasion) -> String {
        for y in [year, year + 1] {
            if let day = SeasonalCalendar.mainDay(of: occasion, year: y, settings: settings), day >= Calendar.current.startOfDay(for: .now) {
                return day.formatted(date: .long, time: .omitted)
            }
        }
        return "Date not known yet"
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SeasonalSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { value in studio.updateSeasonal { $0[keyPath: keyPath] = value } }
        )
    }

    private func enabled(_ occasion: SeasonalOccasion) -> Binding<Bool> {
        Binding(
            get: { !settings.disabled.contains(occasion) },
            set: { on in studio.updateSeasonal { if on { $0.disabled.remove(occasion) } else { $0.disabled.insert(occasion) } } }
        )
    }

    private func deepavali(_ year: Int) -> Binding<Date> {
        let calendar = PrayerCalendar.malaysia
        return Binding(
            get: { settings.deepavaliDates[year].flatMap { SeasonalCalendar.isoDate($0, calendar: calendar) } ?? .now },
            set: { date in
                let c = calendar.dateComponents([.year, .month, .day], from: date)
                let text = String(format: "%04d-%02d-%02d", c.year ?? year, c.month ?? 1, c.day ?? 1)
                studio.updateSeasonal { $0.deepavaliDates[year] = text }
            }
        )
    }
}
