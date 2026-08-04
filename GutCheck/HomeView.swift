import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSomethingsOff = false
    @State private var showCapture = false
    @State private var showCrossFeed = false
    @State private var showExposure = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // The home screen is one button (UX principle #1).
                    Button {
                        showSomethingsOff = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.title2)
                            Text("Something's off")
                                .font(.title3.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.87, green: 0.44, blue: 0.15))

                    HStack(spacing: 10) {
                        quickAction("Log output", symbol: "camera.fill") { showCapture = true }
                        quickAction("Food theft", symbol: "fork.knife.circle") { showCrossFeed = true }
                        quickAction("Med / stress", symbol: "pills.circle") { showExposure = true }
                    }

                    SectionHeader(title: "The household")

                    ForEach(store.data.pets) { pet in
                        NavigationLink {
                            PetScreen(petID: pet.id)
                        } label: {
                            PetCard(pet: pet)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Gut Check")
            .sheet(isPresented: $showSomethingsOff) {
                SomethingsOffSheet()
            }
            .sheet(isPresented: $showCapture) {
                CaptureSheet(petID: defaultCapturePet)
            }
            .sheet(isPresented: $showCrossFeed) {
                CrossFeedSheet()
            }
            .sheet(isPresented: $showExposure) {
                ExposureSheet()
            }
        }
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    /// Pre-select the pet most likely being logged: first one in watch mode.
    private var defaultCapturePet: UUID? {
        let watched = store.data.pets.first { $0.mode != .baseline }
        return (watched ?? store.data.pets.first)?.id
    }
}

struct PetCard: View {
    @EnvironmentObject var store: AppStore
    let pet: Pet

    var body: some View {
        let episode = store.activeEpisode(for: pet.id)
        HStack(spacing: 14) {
            Text(pet.avatar)
                .font(.system(size: 38))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(pet.name)
                        .font(.headline)
                    Text(pet.mode.label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(pet.mode.badgeColor.opacity(0.18)))
                        .foregroundColor(pet.mode.badgeColor)
                }
                if let episode = episode {
                    Text("Day \(episode.durationDays) · \(episode.note)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    ResolutionDots(progress: store.resolutionProgress(for: episode))
                } else {
                    Text("All quiet — nothing needed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

/// Progress toward resolution: 3 consecutive normal outputs.
struct ResolutionDots: View {
    let progress: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < progress ? Tier.normal.color : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
            Text("\(min(progress, 3)) of 3 normals to resolve")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - "Something's off" flow (W3)

struct SomethingsOffSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPetID: UUID?
    @State private var note = ""
    @State private var startedEpisode: Episode?

    var body: some View {
        NavigationStack {
            Group {
                if let episode = startedEpisode {
                    LookbackView(petID: episode.petID) {
                        dismiss()
                    }
                } else {
                    Form {
                        Section("Who's off?") {
                            ForEach(store.data.pets) { pet in
                                Button {
                                    selectedPetID = pet.id
                                } label: {
                                    HStack {
                                        Text(pet.avatar)
                                        Text(pet.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedPetID == pet.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        Section("What's wrong? (optional)") {
                            TextField("e.g. soft stool since this morning", text: $note)
                        }
                        Section {
                            Button {
                                guard let petID = selectedPetID else { return }
                                if let existing = store.activeEpisode(for: petID) {
                                    startedEpisode = existing
                                } else {
                                    startedEpisode = store.startEpisode(petID: petID, note: note.isEmpty ? "Something's off" : note)
                                }
                            } label: {
                                Text("Start watching")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline)
                            }
                            .disabled(selectedPetID == nil)
                        }
                    }
                }
            }
            .navigationTitle(startedEpisode == nil ? "Something's off" : "48-hour lookback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
