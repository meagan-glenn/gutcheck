import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(store.data.pets) { pet in
                        let episodes = store.data.episodes
                            .filter { $0.petID == pet.id }
                            .sorted { $0.start > $1.start }
                        if !episodes.isEmpty {
                            SectionHeader(title: "\(pet.name) — \(episodes.count) episode\(episodes.count == 1 ? "" : "s")")
                            ForEach(episodes) { episode in
                                EpisodeCard(episode: episode)
                            }
                        }
                    }
                    if store.data.episodes.isEmpty {
                        Text("No episodes yet. That's a good thing.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Episodes")
        }
    }
}

struct EpisodeCard: View {
    @EnvironmentObject var store: AppStore
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(episode.isActive ? "Active · Day \(episode.durationDays)" : "\(shortDate(episode.start)) · \(episode.durationDays) days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if episode.isActive {
                    TierBadge(tier: .monitor)
                } else {
                    Text("Resolved")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Tier.normal.color.opacity(0.15)))
                        .foregroundColor(Tier.normal.color)
                }
            }
            Text(episode.note)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let kinds = episode.protocolKinds, !kinds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(kinds) { kind in
                        Label(kind.label, systemImage: kind.symbol)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}

struct InsightsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Patterns across episodes and across animals. Always association, never diagnosis — counter-evidence shown when it exists.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    let insights = store.insights
                    if insights.isEmpty {
                        Text("Not enough episodes yet. Insights need at least a few to be honest.")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }
                    ForEach(insights) { insight in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: insight.isCrossPet ? "pawprint.fill" : "lightbulb.fill")
                                    .foregroundColor(insight.isCrossPet ? Color(red: 0.48, green: 0.35, blue: 0.72) : Tier.monitor.color)
                                Text(insight.title)
                                    .font(.subheadline.weight(.bold))
                            }
                            Text(insight.detail)
                                .font(.subheadline)
                            if let counter = insight.counterEvidence, !counter.isEmpty {
                                Text("Counter-evidence: \(counter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if insight.isCrossPet {
                                Text("Cross-pet signal — only visible with the whole household tracked")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(Color(red: 0.48, green: 0.35, blue: 0.72))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}
