import Foundation
import Combine

struct AppData: Codable {
    var pets: [Pet] = []
    var items: [Item] = []
    var events: [OutputEvent] = []
    var interventions: [Intervention] = []
    var crossFeeds: [CrossFeed] = []
    var episodes: [Episode] = []
    var exposures: [ExposureEvent] = []

    init() {}

    // Tolerant decoding so adding fields never wipes an existing on-device file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pets = try container.decodeIfPresent([Pet].self, forKey: .pets) ?? []
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        events = try container.decodeIfPresent([OutputEvent].self, forKey: .events) ?? []
        interventions = try container.decodeIfPresent([Intervention].self, forKey: .interventions) ?? []
        crossFeeds = try container.decodeIfPresent([CrossFeed].self, forKey: .crossFeeds) ?? []
        episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
        exposures = try container.decodeIfPresent([ExposureEvent].self, forKey: .exposures) ?? []
    }
}

struct LogResult {
    var tier: Tier
    var suggestWatch: Bool
    var suggestResolution: Bool
}

final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { save() }
    }

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("gutcheck.json")
    }()

    init() {
        if let loaded = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: loaded) {
            data = decoded
        } else {
            data = AppStore.seed()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: fileURL)
        }
    }

    func resetToSeed() {
        data = AppStore.seed()
    }

    // MARK: - Lookups

    func pet(_ id: UUID) -> Pet? {
        data.pets.first { $0.id == id }
    }

    func activeEpisode(for petID: UUID) -> Episode? {
        data.episodes.first { $0.petID == petID && $0.isActive }
    }

    func events(in episode: Episode) -> [OutputEvent] {
        data.events
            .filter { $0.petID == episode.petID && $0.date >= episode.start && (episode.end == nil || $0.date <= episode.end!) }
            .sorted { $0.date > $1.date }
    }

    func interventions(in episode: Episode) -> [Intervention] {
        data.interventions
            .filter { $0.episodeID == episode.id }
            .sorted { $0.date > $1.date }
    }

    func resolvedEpisodes(for petID: UUID) -> [Episode] {
        data.episodes
            .filter { $0.petID == petID && !$0.isActive }
            .sorted { $0.start > $1.start }
    }

    /// The most recent captured protocol for this pet — powers replay (W5).
    func lastProtocol(for petID: UUID) -> Episode? {
        resolvedEpisodes(for: petID).first { ($0.protocolKinds ?? []).isEmpty == false }
    }

    func resolutionProgress(for episode: Episode) -> Int {
        consecutiveNormals(events: events(in: episode).sorted { $0.date < $1.date })
    }

    // MARK: - Mutations

    // MARK: - Photos

    private var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func savePhoto(_ imageData: Data) -> String {
        let filename = UUID().uuidString + ".jpg"
        try? imageData.write(to: photosDirectory.appendingPathComponent(filename))
        return filename
    }

    func photoURL(_ filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    func logOutput(petID: UUID, reading: StoolReading, note: String, photoFilename: String? = nil, date: Date = Date()) -> LogResult {
        let dayAgo = date.addingTimeInterval(-24 * 3600)
        let liquidCount = data.events.filter {
            $0.petID == petID && $0.date >= dayAgo && $0.reading.consistency == .liquid
        }.count + (reading.consistency == .liquid ? 1 : 0)

        let tier = triageTier(for: reading, liquidCountLast24h: liquidCount)
        let event = OutputEvent(petID: petID, date: date, reading: reading, tier: tier, note: note, photoFilename: photoFilename)
        data.events.append(event)

        let active = activeEpisode(for: petID)
        let suggestWatch = tier > .normal && active == nil
        var suggestResolution = false
        if let episode = active, tier == .normal {
            suggestResolution = resolutionProgress(for: episode) >= 3
        }
        return LogResult(tier: tier, suggestWatch: suggestWatch, suggestResolution: suggestResolution)
    }

    @discardableResult
    func startEpisode(petID: UUID, note: String) -> Episode {
        let episode = Episode(petID: petID, start: Date(), note: note)
        data.episodes.append(episode)
        if let index = data.pets.firstIndex(where: { $0.id == petID }), !data.pets[index].isChronic {
            data.pets[index].mode = .watch
        }
        return episode
    }

    func resolveEpisode(_ episode: Episode, protocolKinds: [InterventionKind]) {
        guard let index = data.episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        data.episodes[index].end = Date()
        data.episodes[index].protocolKinds = protocolKinds
        if let petIndex = data.pets.firstIndex(where: { $0.id == episode.petID }), !data.pets[petIndex].isChronic {
            data.pets[petIndex].mode = .baseline
        }
    }

    func addIntervention(kind: InterventionKind, petID: UUID) {
        let episodeID = activeEpisode(for: petID)?.id
        data.interventions.append(Intervention(petID: petID, episodeID: episodeID, kind: kind, date: Date()))
    }

    /// One-tap protocol replay: log every intervention from a prior episode's protocol.
    func replayProtocol(from previous: Episode, petID: UUID) {
        for kind in previous.protocolKinds ?? [] {
            addIntervention(kind: kind, petID: petID)
        }
    }

    func logCrossFeed(eaterID: UUID, foodOwnerID: UUID, amount: String) {
        data.crossFeeds.append(CrossFeed(eaterID: eaterID, foodOwnerID: foodOwnerID, amount: amount, date: Date()))
    }

    @discardableResult
    func logExposure(kind: ExposureKind, petID: UUID?, note: String = "", date: Date = Date()) -> ExposureEvent {
        let exposure = ExposureEvent(petID: petID, kind: kind, note: note, date: date)
        data.exposures.append(exposure)
        return exposure
    }

    func removeExposure(id: UUID) {
        data.exposures.removeAll { $0.id == id }
    }

    func exposures(in episode: Episode) -> [ExposureEvent] {
        let windowStart = episode.start.addingTimeInterval(-72 * 3600)
        let windowEnd = episode.end ?? Date()
        return data.exposures
            .filter { $0.applies(to: episode.petID) && $0.date >= windowStart && $0.date <= windowEnd }
            .sorted { $0.date > $1.date }
    }

    /// A medication exposure in the 72h before this episode opened — used to
    /// frame the episode as possibly expected noise, without diagnosing.
    func medExposureBefore(_ episode: Episode) -> ExposureEvent? {
        data.exposures.first { exposure in
            exposure.kind.isMedication &&
            exposure.applies(to: episode.petID) &&
            episode.start.timeIntervalSince(exposure.date) >= 0 &&
            episode.start.timeIntervalSince(exposure.date) <= 72 * 3600
        }
    }

    func updatePet(_ pet: Pet) {
        if let index = data.pets.firstIndex(where: { $0.id == pet.id }) {
            data.pets[index] = pet
        }
    }

    // MARK: - Unified timeline

    enum TimelineEntry: Identifiable {
        case output(OutputEvent)
        case intervention(Intervention)
        case exposure(ExposureEvent)
        case crossFeed(CrossFeed)

        var id: UUID {
            switch self {
            case .output(let e): return e.id
            case .intervention(let e): return e.id
            case .exposure(let e): return e.id
            case .crossFeed(let e): return e.id
            }
        }

        var date: Date {
            switch self {
            case .output(let e): return e.date
            case .intervention(let e): return e.date
            case .exposure(let e): return e.date
            case .crossFeed(let e): return e.date
            }
        }
    }

    func timeline(for petID: UUID, since: Date) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        entries += data.events.filter { $0.petID == petID && $0.date >= since }.map { .output($0) }
        entries += data.interventions.filter { $0.petID == petID && $0.date >= since }.map { .intervention($0) }
        entries += data.exposures.filter { $0.applies(to: petID) && $0.date >= since }.map { .exposure($0) }
        entries += data.crossFeeds.filter { $0.eaterID == petID && $0.date >= since }.map { .crossFeed($0) }
        return entries.sorted { $0.date > $1.date }
    }

    // MARK: - Lookback (W4)

    struct Lookback {
        var newItems: [Item]
        var crossFeeds: [CrossFeed]
        var interventions: [Intervention]
        var outputs: [OutputEvent]
        var exposures: [ExposureEvent]
    }

    func lookback(petID: UUID, hours: Double = 48) -> Lookback {
        let cutoff = Date().addingTimeInterval(-hours * 3600)
        let newItemCutoff = Date().addingTimeInterval(-14 * 24 * 3600)
        // Meds and stress stay relevant longer than a meal does.
        let exposureCutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let relevantItems = data.items.filter { item in
            guard item.firstIntroduced >= newItemCutoff else { return false }
            switch item.scope {
            case .household: return true
            case .pet(let owner): return owner == petID
            }
        }
        let feeds = data.crossFeeds.filter { $0.date >= cutoff && ($0.eaterID == petID || $0.foodOwnerID == petID) }
        let meds = data.interventions.filter { $0.petID == petID && $0.date >= cutoff }
        let outs = data.events.filter { $0.petID == petID && $0.date >= cutoff }.sorted { $0.date > $1.date }
        let exposed = data.exposures
            .filter { $0.applies(to: petID) && $0.date >= exposureCutoff }
            .sorted { $0.date > $1.date }
        return Lookback(newItems: relevantItems, crossFeeds: feeds, interventions: meds, outputs: outs, exposures: exposed)
    }

    // MARK: - Insights (W7, honest rules)

    struct Insight: Identifiable {
        var id = UUID()
        var title: String
        var detail: String
        var counterEvidence: String?
        var isCrossPet: Bool
    }

    var insights: [Insight] {
        var results: [Insight] = []

        // New household items introduced within 48h before an episode start.
        for item in data.items {
            guard case .household = item.scope else { continue }
            let linked = data.episodes.filter { episode in
                let gap = episode.start.timeIntervalSince(item.firstIntroduced)
                return gap >= 0 && gap <= 48 * 3600
            }
            if !linked.isEmpty {
                let names = linked.compactMap { pet($0.petID)?.name }.joined(separator: ", ")
                results.append(Insight(
                    title: "\(item.name) introduced \(relativeDay(item.firstIntroduced))",
                    detail: "\(linked.count) episode\(linked.count == 1 ? "" : "s") (\(names)) began within 48h of it entering the house. Association, not diagnosis.",
                    counterEvidence: nil,
                    isCrossPet: Set(linked.map { $0.petID }).count > 1
                ))
            }
        }

        // Cross-feeding preceding an episode by <=48h.
        for feed in data.crossFeeds {
            let linked = data.episodes.filter { episode in
                episode.petID == feed.eaterID &&
                episode.start.timeIntervalSince(feed.date) >= 0 &&
                episode.start.timeIntervalSince(feed.date) <= 48 * 3600
            }
            if let episode = linked.first,
               let eater = pet(feed.eaterID), let owner = pet(feed.foodOwnerID) {
                results.append(Insight(
                    title: "\(eater.name) ate \(owner.name)'s food before this episode",
                    detail: "\(eater.name) got into \(owner.name)'s food \(relativeDay(feed.date)) — \(hoursBetween(feed.date, episode.start))h before the episode opened. If this repeats, the fix may be feeding in separate rooms.",
                    counterEvidence: nil,
                    isCrossPet: true
                ))
            }
        }

        // Exposures (meds, stress) preceding an episode by <=72h.
        for exposure in data.exposures {
            let linked = data.episodes.filter { episode in
                exposure.applies(to: episode.petID) &&
                episode.start.timeIntervalSince(exposure.date) >= 0 &&
                episode.start.timeIntervalSince(exposure.date) <= 72 * 3600
            }
            if let episode = linked.first, let petRecord = pet(episode.petID) {
                let noteSuffix = exposure.note.isEmpty ? "" : " (\(exposure.note))"
                let medLine = exposure.kind.isMedication
                    ? " Loose stool after a med change is common — worth telling the vet, not a diagnosis."
                    : " Association, not diagnosis."
                results.append(Insight(
                    title: "\(exposure.kind.label) before \(petRecord.name)'s episode",
                    detail: "\(exposure.kind.label)\(noteSuffix) was logged \(hoursBetween(exposure.date, episode.start))h before the episode opened." + medLine,
                    counterEvidence: nil,
                    isCrossPet: exposure.petID == nil && Set(linked.map { $0.petID }).count > 1
                ))
            }
        }

        // Protocol narrowing across resolutions (W6).
        for petRecord in data.pets {
            let resolved = resolvedEpisodes(for: petRecord.id).filter { ($0.protocolKinds ?? []).isEmpty == false }
            guard resolved.count >= 2 else { continue }
            var counts: [InterventionKind: Int] = [:]
            for episode in resolved {
                for kind in Set(episode.protocolKinds ?? []) {
                    counts[kind, default: 0] += 1
                }
            }
            if let (topKind, topCount) = counts.max(by: { $0.value < $1.value }), topCount == resolved.count {
                results.append(Insight(
                    title: "\(topKind.label) appears in all \(resolved.count) of \(petRecord.name)'s resolutions",
                    detail: "Still association — but the intersection is tightening across episodes.",
                    counterEvidence: counts
                        .filter { $0.value < resolved.count }
                        .map { "\($0.key.label) appears in \($0.value) of \(resolved.count)" }
                        .joined(separator: " · "),
                    isCrossPet: false
                ))
            }
        }

        return results
    }

    // MARK: - Seed data

    static func seed() -> AppData {
        let now = Date()
        func daysAgo(_ d: Double) -> Date { now.addingTimeInterval(-d * 24 * 3600) }
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

        let navi = Pet(name: "Navi", species: .dog, breed: "Cattle dog mix", avatar: "🐕",
                       conditions: ["Sensitive gut"], mode: .chronic, isChronic: true)
        let albus = Pet(name: "Albus", species: .dog, breed: "Golden retriever", avatar: "🦮")
        let arya = Pet(name: "Arya", species: .dog, breed: "Border collie", avatar: "🐶")

        var seeded = AppData()
        seeded.pets = [navi, albus, arya]

        seeded.items = [
            Item(name: "Hill's i/d", scope: .pet(navi.id), kind: "food", firstIntroduced: daysAgo(220)),
            Item(name: "Puppy kibble", scope: .pet(albus.id), kind: "food", firstIntroduced: daysAgo(90)),
            Item(name: "Salmon kibble", scope: .pet(arya.id), kind: "food", firstIntroduced: daysAgo(300)),
            Item(name: "Bully sticks", scope: .household, kind: "chew", firstIntroduced: daysAgo(200)),
            Item(name: "Yak cheese chew", scope: .household, kind: "chew", firstIntroduced: daysAgo(2.2)),
        ]

        // A resolved past episode for Navi, with a captured protocol → powers replay.
        let pastEpisode = Episode(petID: navi.id, start: daysAgo(61), end: daysAgo(57),
                                  note: "Soft stool after park weekend",
                                  protocolKinds: [.fasted, .blandDiet, .removedItem])
        var oldReading = StoolReading.normal
        oldReading.consistency = .softServe
        seeded.events.append(OutputEvent(petID: navi.id, date: daysAgo(61),
                                         reading: oldReading, tier: .monitor))
        seeded.events.append(OutputEvent(petID: navi.id, date: daysAgo(59),
                                         reading: .normal, tier: .normal))
        seeded.events.append(OutputEvent(petID: navi.id, date: daysAgo(58),
                                         reading: .normal, tier: .normal))
        seeded.events.append(OutputEvent(petID: navi.id, date: daysAgo(57.2),
                                         reading: .normal, tier: .normal))
        seeded.interventions = [
            Intervention(petID: navi.id, episodeID: pastEpisode.id, kind: .fasted, date: daysAgo(61)),
            Intervention(petID: navi.id, episodeID: pastEpisode.id, kind: .blandDiet, date: daysAgo(60)),
            Intervention(petID: navi.id, episodeID: pastEpisode.id, kind: .removedItem, date: daysAgo(60)),
        ]

        // Cross-feeding two days ago: Navi got into Albus's puppy kibble.
        seeded.crossFeeds = [
            CrossFeed(eaterID: navi.id, foodOwnerID: albus.id, amount: "half the bowl", date: daysAgo(2)),
        ]

        // Navi started a new supplement 2.5 days ago — ~34h before the episode.
        seeded.exposures = [
            ExposureEvent(petID: navi.id, kind: .medStarted, note: "joint supplement", date: daysAgo(2.5)),
        ]

        // Active episode: opened yesterday.
        let active = Episode(petID: navi.id, start: daysAgo(1.1), note: "Soft serve since yesterday morning")
        var reading1 = StoolReading.normal
        reading1.consistency = .softServe
        seeded.events.append(OutputEvent(petID: navi.id, date: daysAgo(1.1), reading: reading1, tier: .monitor))
        var reading2 = StoolReading.normal
        reading2.consistency = .littleSoft
        seeded.events.append(OutputEvent(petID: navi.id, date: hoursAgo(5), reading: reading2, tier: .monitor))

        seeded.episodes = [pastEpisode, active]
        return seeded
    }
}

// MARK: - Date helpers

func relativeDay(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

func hoursBetween(_ a: Date, _ b: Date) -> Int {
    Int(abs(b.timeIntervalSince(a)) / 3600)
}

func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

func shortDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
