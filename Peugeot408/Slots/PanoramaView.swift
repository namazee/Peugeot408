import CarKit
import SwiftUI

/// Slots → Panorama hero (Phase 14): one wide design spread over Slots 1–3.
struct PanoramaView: View {
    @Environment(SlotsModel.self) private var slots
    @Environment(StudioModel.self) private var studio
    @Environment(CarDataModel.self) private var cars
    @State private var confirming = false
    @State private var editing: CardDesign?
    @State private var name = ""
    @State private var malay = false

    private var panoramaDesigns: [CardDesign] { studio.state.designs.filter { $0.canvas == .panorama } }
    private var settings: PanoramaSettings { slots.state.panorama ?? PanoramaSettings() }
    private var chosen: CardDesign? { studio.design(settings.designID) ?? panoramaDesigns.first }

    var body: some View {
        List {
            if let design = chosen {
                Section {
                    preview(design)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("As on a 3-column CarPlay screen: Slot 1, 2 and 3 each show their part; the thin gaps are drawn by CarPlay.")
                }
            }

            Section {
                Toggle("Show across Slots 1–3", isOn: Binding(
                    get: { slots.state.activePanoramaID != nil },
                    set: { on in
                        if on { confirming = true } else { slots.setPanorama(PanoramaSettings(enabled: false, designID: settings.designID)) }
                    }
                ))
                .disabled(chosen == nil)
            } footer: {
                Text(chosen == nil
                     ? "Create a Hero design first (below)."
                     : "Slots 1–3 keep their own designs underneath; turning the panorama off brings them back. Slots 4–5 aren't affected.")
            }

            Section {
                ForEach(panoramaDesigns) { design in
                    HStack {
                        Button {
                            slots.setPanorama(PanoramaSettings(enabled: settings.enabled, designID: design.id))
                        } label: {
                            HStack(spacing: 12) {
                                DesignView(card: DesignResolver.card(for: design, data: cars.data, studio: studio.state, at: .now))
                                    .aspectRatio(design.canvas.aspectRatio, contentMode: .fit)
                                    .frame(height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text(design.name).lineLimit(2)
                                Spacer()
                                if chosen?.id == design.id {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            editing = design
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(design.name)")
                    }
                }
                Menu {
                    ForEach(TemplateGroup.hero.styles) { style in
                        Button(style.displayName) {
                            let hero = Templates.make(style)
                            studio.save(hero)
                            slots.setPanorama(PanoramaSettings(enabled: settings.enabled, designID: hero.id))
                            editing = hero
                        }
                    }
                } label: {
                    Label("Create a Hero design", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Design")
            } footer: {
                Text("Pick a Hero template: the classic Hero (your My Car photo with big \"MY CAR\" lettering behind it), Sunset Road, Night City, Cockpit, Live Sky, Neon Grid or Glass Info. Any design you make on the Panorama canvas in the builder shows up here too.")
            }

            Section {
                TextField("Your name", text: $name)
                    .onSubmit { studio.setGreeting(name: name, malay: malay) }
                Picker("Language", selection: $malay) {
                    Text("English").tag(false)
                    Text("Bahasa Melayu").tag(true)
                }
                .pickerStyle(.segmented)
                LabeledContent("Says now", value: DesignResolver.greetingText(at: .now, name: name, malay: malay))
            } header: {
                Text("Greeting")
            } footer: {
                Text("Changes with the time of day: morning, afternoon and evening (pagi, tengah hari, petang and malam in Malay).")
            }
        }
        .navigationTitle("Panorama hero")
        .onAppear {
            name = studio.state.ownerName ?? ""
            malay = studio.state.greetingMalay ?? false
        }
        .onChange(of: malay) { _, value in studio.setGreeting(name: name, malay: value) }
        .onDisappear { studio.setGreeting(name: name, malay: malay) }
        .confirmationDialog("Show the panorama on Slots 1–3?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Show panorama") {
                slots.setPanorama(PanoramaSettings(enabled: true, designID: chosen?.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It replaces what Slots 1–3 show in the car until you turn it off. Their own designs are kept.")
        }
        .fullScreenCover(item: $editing) { design in
            DesignBuilderView(initial: design)
        }
    }

    private func preview(_ design: CardDesign) -> some View {
        let card = DesignResolver.card(for: design, data: cars.data, studio: studio.state, at: .now)
        return HStack(spacing: 8) {
            ForEach(0..<PanoramaGeometry.columns, id: \.self) { part in
                SlotTile(slot: part + 1, content: .panorama(card, part))
                    .aspectRatio(PanoramaGeometry.columnAspect, contentMode: .fit)
            }
        }
        .padding(8)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
