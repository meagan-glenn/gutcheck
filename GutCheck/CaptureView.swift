import SwiftUI
import PhotosUI

/// W2 — Log an output. Camera is stubbed (simulator has no camera; the PRD's
/// manual-override path is the whole flow for now). AI suggestion is mocked as
/// a prefilled normal reading — the user corrects, which is the real interaction.
struct CaptureSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var petID: UUID?
    @State private var reading: StoolReading = .normal
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showMoreConsistency = false
    @State private var showMoreColors = false
    @State private var savedResult: LogResult?
    @State private var showWatchPrompt = false
    @State private var lookbackPetID: UUID?

    private var liveTier: Tier {
        guard let petID = petID else { return .normal }
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        let liquidCount = store.data.events.filter {
            $0.petID == petID && $0.date >= dayAgo && $0.reading.consistency == .liquid
        }.count + (reading.consistency == .liquid ? 1 : 0)
        return triageTier(for: reading, liquidCountLast24h: liquidCount)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let lookbackPet = lookbackPetID {
                    LookbackView(petID: lookbackPet) { dismiss() }
                } else {
                    captureForm
                }
            }
            .navigationTitle(lookbackPetID == nil ? "Log an output" : "48-hour lookback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var captureForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Pet picker
                HStack {
                    Text("For")
                        .foregroundColor(.secondary)
                    Picker("Pet", selection: $petID) {
                        ForEach(store.data.pets) { pet in
                            Text("\(pet.avatar) \(pet.name)").tag(Optional(pet.id))
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                    TierBadge(tier: liveTier)
                }

                // Photo-first capture. On a real phone this is where the camera
                // opens; the simulator falls back to the photo library.
                PhotosPicker(selection: $photoItem, matching: .images) {
                    if let data = photoData, let image = UIImage(data: data) {
                        HStack(spacing: 12) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Photo attached")
                                    .font(.subheadline.weight(.semibold))
                                Text("AI scored all four axes — tap any chip to correct")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Snap a photo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("AI prefills all four axes from the photo — or skip it and tap chips below")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: photoItem) { item in
                    guard let item = item else { return }
                    Task { @MainActor in
                        photoData = try? await item.loadTransferable(type: Data.self)
                    }
                }

                axisSection(title: "Consistency", tier: reading.consistency.tier) {
                    chipWrap {
                        ForEach(ConsistencyChoice.primary) { choice in
                            Chip(label: choice.label,
                                 isSelected: reading.consistency == choice,
                                 tint: choice.tier.color) {
                                reading.consistency = choice
                            }
                        }
                        if showMoreConsistency || reading.consistency == .hard {
                            Chip(label: ConsistencyChoice.hard.label,
                                 isSelected: reading.consistency == .hard,
                                 tint: ConsistencyChoice.hard.tier.color) {
                                reading.consistency = .hard
                            }
                        } else {
                            Chip(label: "more…", isSelected: false, tint: .secondary) {
                                showMoreConsistency = true
                            }
                        }
                    }
                }

                axisSection(title: "Color", tier: reading.color.tier) {
                    chipWrap {
                        ForEach(StoolColor.primary) { color in
                            Chip(label: color.label,
                                 isSelected: reading.color == color,
                                 tint: color.tier.color) {
                                reading.color = color
                            }
                        }
                        if showMoreColors || StoolColor.secondary.contains(reading.color) {
                            ForEach(StoolColor.secondary) { color in
                                Chip(label: color.label,
                                     isSelected: reading.color == color,
                                     tint: color.tier.color) {
                                    reading.color = color
                                }
                            }
                        } else {
                            Chip(label: "more…", isSelected: false, tint: .secondary) {
                                showMoreColors = true
                            }
                        }
                    }
                }

                axisSection(title: "Coating", tier: reading.coating.tier) {
                    chipWrap {
                        ForEach(Coating.allCases) { coating in
                            Chip(label: coating.label,
                                 isSelected: reading.coating == coating,
                                 tint: coating.tier.color) {
                                reading.coating = coating
                            }
                        }
                    }
                }

                axisSection(title: "Contents", tier: reading.contents.tier) {
                    chipWrap {
                        ForEach(Contents.allCases) { contents in
                            Chip(label: contents.label,
                                 isSelected: reading.contents == contents,
                                 tint: contents.tier.color) {
                                reading.contents = contents
                            }
                        }
                    }
                }

                TextField("Optional note", text: $note)
                    .textFieldStyle(.roundedBorder)

                saveArea
            }
            .padding()
        }
        .confirmationDialog("Open watch mode?", isPresented: $showWatchPrompt, titleVisibility: .visible) {
            Button("Yes — start watching") {
                if let petID = petID {
                    store.startEpisode(petID: petID, note: "Abnormal output logged")
                    lookbackPetID = petID
                }
            }
            Button("Not now", role: .cancel) { dismiss() }
        } message: {
            Text("That log was abnormal. Watch mode tracks everything until it resolves.")
        }
    }

    /// Urgent findings break the layout (W2): the vet action becomes the primary
    /// button and the save is demoted to a text link.
    @ViewBuilder
    private var saveArea: some View {
        if liveTier == .urgent {
            VStack(spacing: 12) {
                Label("This is one of the things vets want to know about promptly.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Tier.urgent.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Tier.urgent.color.opacity(0.12)))
                Button {
                    save()
                } label: {
                    Text("Save & prepare a vet summary")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tier.urgent.color)
                Button("Just save the log") { save() }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            Button {
                save()
            } label: {
                Text("Looks right — save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(liveTier == .normal ? Tier.normal.color : liveTier.color)
        }
    }

    private func save() {
        guard let petID = petID else { return }
        let filename = photoData.map { store.savePhoto($0) }
        let result = store.logOutput(petID: petID, reading: reading, note: note, photoFilename: filename)
        savedResult = result
        if result.suggestWatch {
            showWatchPrompt = true
        } else {
            dismiss()
        }
    }

    private func axisSection<Content: View>(title: String, tier: Tier, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: title)
                if tier > .normal {
                    TierBadge(tier: tier)
                }
            }
            content()
        }
    }

    private func chipWrap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FlowLayout(spacing: 8) {
            content()
        }
    }
}

/// Minimal wrapping layout for chips (iOS 16+).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
