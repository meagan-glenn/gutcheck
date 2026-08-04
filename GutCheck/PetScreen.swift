import SwiftUI

/// Per-pet screen, ordered by what an owner actually reaches for here:
/// 1. the timeline, 2. a vet summary (they're standing in the exam room),
/// 3. editing what's going on with this animal. Logging an output is demoted
/// to a toolbar icon — that mostly happens from the home screen.
struct PetScreen: View {
    @EnvironmentObject var store: AppStore
    let petID: UUID

    @State private var showCapture = false
    @State private var showResolve = false
    @State private var showSummary = false
    @State private var showEdit = false
    @State private var replayedProtocol = false

    var body: some View {
        let pet = store.pet(petID)
        let episode = store.activeEpisode(for: petID)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let episode = episode {
                    statusCard(episode: episode)
                } else {
                    baselineCard
                }

                // Vet summary is the marquee action: one tap, exam-room ready.
                HStack(spacing: 10) {
                    Button {
                        showSummary = true
                    } label: {
                        Label("Vet summary", systemImage: "doc.text.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.bordered)
                }

                if let episode = episode {
                    episodeContext(episode: episode)
                }

                SectionHeader(title: "Timeline")
                timelineSection(episode: episode)

                if episode == nil {
                    let past = store.resolvedEpisodes(for: petID)
                    if !past.isEmpty {
                        SectionHeader(title: "Past episodes")
                        ForEach(past) { pastEpisode in
                            EpisodeCard(episode: pastEpisode)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(pet?.avatar ?? "") \(pet?.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCapture = true
                } label: {
                    Image(systemName: "camera.fill")
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureSheet(petID: petID)
        }
        .sheet(isPresented: $showSummary) {
            SummarySheet(petID: petID)
        }
        .sheet(isPresented: $showEdit) {
            if let pet = pet {
                PetEditSheet(pet: pet)
            }
        }
        .sheet(isPresented: $showResolve) {
            if let episode = store.activeEpisode(for: petID) {
                ResolveSheet(episode: episode)
            }
        }
    }

    // MARK: Status

    private func statusCard(episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Watch mode · Day \(episode.durationDays)")
                    .font(.headline)
                Spacer()
                TierBadge(tier: worstTier(in: episode))
            }
            Text(episode.note)
                .font(.subheadline)
                .foregroundColor(.secondary)
            ResolutionDots(progress: store.resolutionProgress(for: episode))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Tier.monitor.color.opacity(0.10)))
    }

    private var baselineCard: some View {
        let pet = store.pet(petID)
        return VStack(alignment: .leading, spacing: 6) {
            Label("Baseline — all quiet", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Every log quietly builds \(pet?.name ?? "their") normal for the day it matters.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: Episode context (med framing, replay, resolve)

    @ViewBuilder
    private func episodeContext(episode: Episode) -> some View {
        let logged = store.interventions(in: episode)

        if let medExposure = store.medExposureBefore(episode) {
            let noteSuffix = medExposure.note.isEmpty ? "" : " (\(medExposure.note))"
            let phrase = medExposure.kind == .medStarted ? "starting a med" : "a med change"
            Label {
                Text("This began \(hoursBetween(medExposure.date, episode.start))h after \(phrase)\(noteSuffix). That timing is common with med changes — worth mentioning to your vet.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "pills.fill")
                    .foregroundColor(Tier.concern.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Tier.concern.color.opacity(0.08)))
        }

        if let previous = store.lastProtocol(for: petID), !replayedProtocol, logged.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("This worked last time", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.subheadline.weight(.bold))
                Text("\(shortDate(previous.start)), \(previous.durationDays) days: " +
                     (previous.protocolKinds ?? []).map { $0.label.lowercased() }.joined(separator: ", ") +
                     ". Resolved day \(previous.durationDays).")
                    .font(.subheadline)
                Button {
                    store.replayProtocol(from: previous, petID: petID)
                    replayedProtocol = true
                } label: {
                    Text("Run the same protocol")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.10)))
        }

        if store.resolutionProgress(for: episode) >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                Label("Looks like this cleared up", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Tier.normal.color)
                Text("Three normal outputs in a row. Mark it resolved and save what you did?")
                    .font(.subheadline)
                Button {
                    showResolve = true
                } label: {
                    Text("Resolve & capture protocol")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tier.normal.color)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Tier.normal.color.opacity(0.10)))
        }

        // One-tap interventions, compact horizontal strip.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InterventionKind.allCases) { kind in
                    let alreadyLogged = logged.contains { $0.kind == kind }
                    Chip(label: kind.label, isSelected: alreadyLogged, tint: .accentColor) {
                        if !alreadyLogged {
                            store.addIntervention(kind: kind, petID: petID)
                        }
                    }
                }
            }
        }
    }

    // MARK: Timeline

    @ViewBuilder
    private func timelineSection(episode: Episode?) -> some View {
        let since = episode.map { $0.start.addingTimeInterval(-72 * 3600) }
            ?? Date().addingTimeInterval(-30 * 24 * 3600)
        let entries = store.timeline(for: petID, since: since)

        if entries.isEmpty {
            Text("Nothing in the last 30 days.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        ForEach(entries) { entry in
            switch entry {
            case .output(let event):
                OutputRow(event: event)
            case .intervention(let intervention):
                HStack(spacing: 10) {
                    Image(systemName: intervention.kind.symbol)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text(intervention.kind.label)
                        .font(.subheadline)
                    Spacer()
                    Text(shortDateTime(intervention.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            case .exposure(let exposure):
                ExposureRow(exposure: exposure)
            case .crossFeed(let feed):
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundColor(Tier.concern.color)
                        .frame(width: 24)
                    Text("Ate \(store.pet(feed.foodOwnerID)?.name ?? "?")'s food (\(feed.amount))")
                        .font(.subheadline)
                    Spacer()
                    Text(shortDateTime(feed.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }
        }
    }

    private func worstTier(in episode: Episode) -> Tier {
        store.events(in: episode).map { $0.tier }.max() ?? .normal
    }
}

// MARK: - Resolution (W5: capture the protocol while it's fresh)

struct ResolveSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let episode: Episode

    @State private var selected: Set<InterventionKind> = []
    @State private var seeded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Here's what you did — anything else? This gets saved as the protocol and offered next time.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Section("Interventions this episode") {
                    ForEach(InterventionKind.allCases) { kind in
                        Button {
                            if selected.contains(kind) {
                                selected.remove(kind)
                            } else {
                                selected.insert(kind)
                            }
                        } label: {
                            HStack {
                                Image(systemName: kind.symbol)
                                    .frame(width: 24)
                                Text(kind.label)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selected.contains(kind) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Tier.normal.color)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        store.resolveEpisode(episode, protocolKinds: InterventionKind.allCases.filter { selected.contains($0) })
                        dismiss()
                    } label: {
                        Text("Confirm resolved")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Episode resolved")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !seeded {
                    selected = Set(store.interventions(in: episode).map { $0.kind })
                    seeded = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
    }
}
