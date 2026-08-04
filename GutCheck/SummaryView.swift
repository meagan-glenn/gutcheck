import SwiftUI

/// W8 — the vet summary. One tap from the pet screen, built for the moment
/// you're standing in the exam room. Headline first, detail behind it,
/// questions phrased as questions — never conclusions.
struct SummarySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let petID: UUID

    private let windowDays = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headlineCard

                    if let episode = store.activeEpisode(for: petID) {
                        currentEpisodeCard(episode)
                    }

                    let episodes = episodesInWindow
                    if !episodes.isEmpty {
                        SectionHeader(title: "Episodes")
                        ForEach(episodes) { episode in
                            EpisodeCard(episode: episode)
                        }
                    }

                    let triggers = suspectedTriggers
                    if !triggers.isEmpty {
                        SectionHeader(title: "Preceded episodes by ≤72h")
                        ForEach(triggers, id: \.self) { trigger in
                            Label(trigger, systemImage: "questionmark.circle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        }
                    }

                    let flags = flagLog
                    if !flags.isEmpty {
                        SectionHeader(title: "Flag log")
                        ForEach(flags) { event in
                            OutputRow(event: event)
                        }
                    }

                    SectionHeader(title: "Questions for the vet")
                    ForEach(vetQuestions, id: \.self) { question in
                        Label(question, systemImage: "text.bubble")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                    }

                    Text("Owner-logged observations, not a clinical record. Nothing here is a diagnosis.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Vet summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: summaryText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private var headlineCard: some View {
        let pet = store.pet(petID)
        let outputs = outputsInWindow
        let normals = outputs.filter { $0.tier == .normal }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(pet?.name ?? ""), last \(windowDays) days")
                .font(.title3.weight(.bold))
            Text("\(episodesInWindow.count) episode\(episodesInWindow.count == 1 ? "" : "s") · \(normals) of \(outputs.count) logged stools normal")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let pet = pet, !pet.conditions.isEmpty {
                Text("Known conditions: \(pet.conditions.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.10)))
    }

    private func currentEpisodeCard(_ episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Open episode · Day \(episode.durationDays)", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Tier.monitor.color)
            Text(episode.note)
                .font(.subheadline)
            let used = store.interventions(in: episode)
            if !used.isEmpty {
                Text("Tried so far: " + used.map { $0.kind.label.lowercased() }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Tier.monitor.color.opacity(0.10)))
    }

    // MARK: Computations

    private var windowStart: Date {
        Date().addingTimeInterval(-Double(windowDays) * 24 * 3600)
    }

    private var outputsInWindow: [OutputEvent] {
        store.data.events.filter { $0.petID == petID && $0.date >= windowStart }
    }

    private var episodesInWindow: [Episode] {
        store.data.episodes
            .filter { $0.petID == petID && ($0.end ?? Date()) >= windowStart }
            .sorted { $0.start > $1.start }
    }

    private var flagLog: [OutputEvent] {
        outputsInWindow.filter { $0.tier >= .concern }.sorted { $0.date > $1.date }
    }

    /// Anything logged within 72h before an episode opened — exposures,
    /// cross-feeding, new household items. Association only.
    private var suspectedTriggers: [String] {
        var lines: [String] = []
        for episode in episodesInWindow {
            let preWindow = episode.start.addingTimeInterval(-72 * 3600)
            for exposure in store.data.exposures
            where exposure.applies(to: petID) && exposure.date >= preWindow && exposure.date <= episode.start {
                let note = exposure.note.isEmpty ? "" : " (\(exposure.note))"
                lines.append("\(exposure.kind.label)\(note), \(hoursBetween(exposure.date, episode.start))h before onset")
            }
            for feed in store.data.crossFeeds
            where feed.eaterID == petID && feed.date >= preWindow && feed.date <= episode.start {
                lines.append("Ate \(store.pet(feed.foodOwnerID)?.name ?? "another pet")'s food, \(hoursBetween(feed.date, episode.start))h before onset")
            }
            for item in store.data.items
            where item.firstIntroduced >= preWindow && item.firstIntroduced <= episode.start {
                lines.append("New item in the house: \(item.name)")
            }
        }
        return Array(Set(lines)).sorted()
    }

    private var vetQuestions: [String] {
        var questions: [String] = []
        for episode in episodesInWindow {
            if let med = store.medExposureBefore(episode) {
                let name = med.note.isEmpty ? "a recent med change" : med.note
                questions.append("Symptoms began ~\(hoursBetween(med.date, episode.start))h after \(name) — could they be related?")
            }
        }
        if !suspectedTriggers.isEmpty {
            questions.append("Do any of the items or events preceding episodes warrant an elimination trial?")
        }
        if questions.isEmpty {
            questions.append("Anything in this pattern that warrants tests or a diet change?")
        }
        return Array(Set(questions)).sorted()
    }

    /// Plain-text rendering for share / print / paste into a portal message.
    private var summaryText: String {
        let pet = store.pet(petID)
        let outputs = outputsInWindow
        let normals = outputs.filter { $0.tier == .normal }.count
        var lines: [String] = []
        lines.append("GUT CHECK — \(pet?.name ?? "") (\(pet?.breed ?? "")), last \(windowDays) days")
        lines.append("\(episodesInWindow.count) episode(s) · \(normals) of \(outputs.count) logged stools normal")
        if let pet = pet, !pet.conditions.isEmpty {
            lines.append("Known conditions: \(pet.conditions.joined(separator: ", "))")
        }
        lines.append("")
        for episode in episodesInWindow {
            let status = episode.isActive ? "OPEN, day \(episode.durationDays)" : "resolved in \(episode.durationDays) days"
            lines.append("• \(shortDate(episode.start)) — \(episode.note) (\(status))")
            let tried = store.interventions(in: episode)
            if !tried.isEmpty {
                lines.append("  Tried: \(tried.map { $0.kind.label.lowercased() }.joined(separator: ", "))")
            }
        }
        if !suspectedTriggers.isEmpty {
            lines.append("")
            lines.append("Preceded episodes by ≤72h:")
            for trigger in suspectedTriggers { lines.append("• \(trigger)") }
        }
        if !flagLog.isEmpty {
            lines.append("")
            lines.append("Flag log:")
            for event in flagLog {
                lines.append("• \(shortDateTime(event.date)) — \(event.reading.consistency.label) (vet score \(event.reading.consistency.vetScore)), \(event.reading.color.label), tier \(event.tier.label)")
            }
        }
        lines.append("")
        lines.append("Questions:")
        for question in vetQuestions { lines.append("• \(question)") }
        lines.append("")
        lines.append("Owner-logged observations via Gut Check. Not a diagnosis.")
        return lines.joined(separator: "\n")
    }
}
