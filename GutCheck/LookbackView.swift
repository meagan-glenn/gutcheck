import SwiftUI

/// W4 — The 48-hour lookback. Shown immediately on watch-mode entry or an
/// abnormal log: everything in the window, then "anything we missed?" chips.
struct LookbackView: View {
    @EnvironmentObject var store: AppStore
    let petID: UUID
    let onDone: () -> Void

    // Quick-add chips create real exposure events; toggling off removes them.
    @State private var addedExposures: [ExposureKind: UUID] = [:]

    private let quickAdds: [ExposureKind] = [
        .foundOutside, .tableFood, .newChew, .medChanged, .travelBoarding, .stressfulEvent,
    ]

    var body: some View {
        let lookback = store.lookback(petID: petID)
        let petName = store.pet(petID)?.name ?? "them"

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Stool reflects intake from 12–36 hours ago — here's everything from \(petName)'s window.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !lookback.newItems.isEmpty {
                    SectionHeader(title: "New in the last 2 weeks")
                    ForEach(lookback.newItems) { item in
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Tier.monitor.color)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.subheadline.weight(.semibold))
                                Text("\(item.kind) · introduced \(relativeDay(item.firstIntroduced))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Tier.monitor.color.opacity(0.08)))
                    }
                }

                if !lookback.crossFeeds.isEmpty {
                    SectionHeader(title: "Cross-feeding")
                    ForEach(lookback.crossFeeds) { feed in
                        HStack {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundColor(Tier.concern.color)
                            Text("\(store.pet(feed.eaterID)?.name ?? "?") ate \(store.pet(feed.foodOwnerID)?.name ?? "?")'s food (\(feed.amount)) — \(relativeDay(feed.date))")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: DS.rowRadius).fill(DS.surface))
                    }
                }

                if !lookback.exposures.isEmpty {
                    SectionHeader(title: "Meds, stress & intake (last 7 days)")
                    ForEach(lookback.exposures) { exposure in
                        ExposureRow(exposure: exposure)
                    }
                }

                if !lookback.outputs.isEmpty {
                    SectionHeader(title: "Outputs in the window")
                    ForEach(lookback.outputs) { event in
                        OutputRow(event: event)
                    }
                }

                SectionHeader(title: "Anything we missed?")
                FlowLayout(spacing: 8) {
                    ForEach(quickAdds) { kind in
                        let existing = addedExposures[kind]
                        Chip(label: kind.label, isSelected: existing != nil, tint: .accentColor) {
                            if let id = existing {
                                store.removeExposure(id: id)
                                addedExposures[kind] = nil
                            } else {
                                let exposure = store.logExposure(kind: kind, petID: kind.defaultsToHousehold ? nil : petID)
                                addedExposures[kind] = exposure.id
                            }
                        }
                    }
                }

                Button {
                    onDone()
                } label: {
                    Text("Done — start watching")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct OutputRow: View {
    @EnvironmentObject var store: AppStore
    let event: OutputEvent
    @State private var showPhoto = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.tier.color)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.reading.consistency.label)
                        .font(.subheadline.weight(.semibold))
                    Text("(vet score \(event.reading.consistency.vetScore))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    TierBadge(tier: event.tier)
                }
                Text(readingSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(shortDateTime(event.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let image = thumbnail {
                // Blurred until deliberately tapped — nobody wants this photo
                // ambushing them mid-scroll.
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .blur(radius: 10, opaque: true)
                    Image(systemName: "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { showPhoto = true }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: DS.rowRadius).fill(DS.surface))
        .sheet(isPresented: $showPhoto) {
            if let image = thumbnail {
                ZoomablePhotoView(image: image)
            }
        }
    }

    private var thumbnail: UIImage? {
        guard let filename = event.photoFilename,
              let data = try? Data(contentsOf: store.photoURL(filename)) else { return nil }
        return UIImage(data: data)
    }

    private var readingSummary: String {
        var parts = [event.reading.color.label]
        if event.reading.coating != Coating.none { parts.append(event.reading.coating.label) }
        if event.reading.contents != Contents.none { parts.append(event.reading.contents.label) }
        if !event.note.isEmpty { parts.append("“\(event.note)”") }
        return parts.joined(separator: " · ")
    }
}

/// Full-screen photo with pinch-to-zoom — the second-opinion flow means a
/// partner is judging this image on their own phone.
struct ZoomablePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width)
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Cross-feeding (one tap: who ate whose, roughly how much)

struct CrossFeedSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var eaterID: UUID?
    @State private var ownerID: UUID?
    @State private var amount = "a few bites"

    private let amounts = ["a few bites", "half the bowl", "the whole bowl", "unknown"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Who ate…") {
                    Picker("Eater", selection: $eaterID) {
                        Text("Pick a pet").tag(UUID?.none)
                        ForEach(store.activePets) { pet in
                            Text("\(pet.avatar) \(pet.name)").tag(Optional(pet.id))
                        }
                    }
                }
                Section("…whose food?") {
                    Picker("Food owner", selection: $ownerID) {
                        Text("Pick a pet").tag(UUID?.none)
                        ForEach(store.activePets) { pet in
                            Text("\(pet.avatar) \(pet.name)").tag(Optional(pet.id))
                        }
                    }
                }
                Section("How much?") {
                    FlowLayout(spacing: 8) {
                        ForEach(amounts, id: \.self) { option in
                            Chip(label: option, isSelected: amount == option, tint: .accentColor) {
                                amount = option
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Button {
                        if let eater = eaterID, let owner = ownerID {
                            store.logCrossFeed(eaterID: eater, foodOwnerID: owner, amount: amount)
                            dismiss()
                        }
                    } label: {
                        Text("Log it")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .disabled(eaterID == nil || ownerID == nil || eaterID == ownerID)
                }
            }
            .navigationTitle("Food theft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
