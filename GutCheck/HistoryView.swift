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
                            SectionHeader(title: "\(pet.name)\(pet.isArchived ? " (archived)" : "") — \(episodes.count) episode\(episodes.count == 1 ? "" : "s")")
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
            let tried = store.interventions(in: episode)
            if !tried.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tried) { intervention in
                        Label(intervention.kind.label, systemImage: intervention.kind.symbol)
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
