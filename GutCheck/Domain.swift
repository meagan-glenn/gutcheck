import Foundation

// MARK: - Core enums

enum Species: String, Codable, CaseIterable {
    case dog = "Dog"
    case cat = "Cat"
}

enum PetMode: String, Codable {
    case baseline
    case watch

    var label: String {
        switch self {
        case .baseline: return "Baseline"
        case .watch: return "Watch"
        }
    }
}

/// Four-tier triage ladder (W11). Ordered by severity.
enum Tier: Int, Codable, Comparable, CaseIterable {
    case normal = 0
    case monitor = 1
    case concern = 2
    case urgent = 3

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .monitor: return "Monitor"
        case .concern: return "Concern"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - The 4Cs

/// C1 — Consistency. Owner-facing five-point scale over a stored 1–7 vet value.
/// `hard` is real but demoted behind a "more" control in the UI.
enum ConsistencyChoice: String, Codable, CaseIterable, Identifiable {
    case logs
    case littleSoft
    case softServe
    case diarrhea
    case liquid
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logs: return "Logs"
        case .littleSoft: return "A little soft"
        case .softServe: return "Soft serve"
        case .diarrhea: return "Diarrhea"
        case .liquid: return "Liquid"
        case .hard: return "Hard"
        }
    }

    /// Stored veterinary 1–7 value underneath the owner label.
    var vetScore: Int {
        switch self {
        case .hard: return 1
        case .logs: return 2
        case .littleSoft: return 4
        case .softServe: return 5
        case .diarrhea: return 6
        case .liquid: return 7
        }
    }

    /// Base tier before the liquid-frequency escalation rule.
    var tier: Tier {
        switch self {
        case .logs: return .normal
        case .littleSoft, .softServe, .hard: return .monitor
        case .diarrhea: return .concern
        case .liquid: return .concern // escalates to .urgent at 3+ in 24h
        }
    }

    /// Primary chips shown up front; `hard` lives behind "more".
    static var primary: [ConsistencyChoice] { [.logs, .littleSoft, .softServe, .diarrhea, .liquid] }
}

/// C2 — Color.
enum StoolColor: String, Codable, CaseIterable, Identifiable {
    case brown
    case green
    case yellowOrange
    case greyGreasy
    case redStreaks
    case whiteChalky
    case blackTarry
    case pinkPurple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brown: return "Brown"
        case .green: return "Green"
        case .yellowOrange: return "Yellow / orange"
        case .greyGreasy: return "Grey / greasy"
        case .redStreaks: return "Red streaks"
        case .whiteChalky: return "White / chalky"
        case .blackTarry: return "Black / tarry"
        case .pinkPurple: return "Pink / purple"
        }
    }

    var tier: Tier {
        switch self {
        case .brown: return .normal
        case .green, .whiteChalky: return .monitor
        case .yellowOrange, .greyGreasy, .redStreaks: return .concern
        case .blackTarry, .pinkPurple: return .urgent
        }
    }

    /// Common values one tap away; rare ones behind "more".
    static var primary: [StoolColor] { [.brown, .green, .yellowOrange, .redStreaks] }
    static var secondary: [StoolColor] { [.greyGreasy, .whiteChalky, .blackTarry, .pinkPurple] }
}

/// C3 — Coating.
enum Coating: String, Codable, CaseIterable, Identifiable {
    case none
    case mucus
    case greasy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .mucus: return "Mucus / jelly"
        case .greasy: return "Greasy sheen"
        }
    }

    var tier: Tier {
        switch self {
        case .none: return .normal
        case .mucus, .greasy: return .concern
        }
    }
}

/// C4 — Contents.
enum Contents: String, Codable, CaseIterable, Identifiable {
    case none
    case riceSpecks
    case grass
    case hair
    case foreignMaterial
    case blood

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .riceSpecks: return "Rice-like specks"
        case .grass: return "Grass"
        case .hair: return "Hair"
        case .foreignMaterial: return "Foreign material"
        case .blood: return "Visible blood"
        }
    }

    var tier: Tier {
        switch self {
        case .none: return .normal
        case .riceSpecks, .grass, .hair: return .monitor
        case .foreignMaterial, .blood: return .concern
        }
    }
}

/// One captured stool observation across all four axes.
struct StoolReading: Codable, Equatable {
    var consistency: ConsistencyChoice
    var color: StoolColor
    var coating: Coating
    var contents: Contents

    static var normal: StoolReading {
        StoolReading(consistency: .logs, color: .brown, coating: .none, contents: .none)
    }
}

/// Triage across all four axes, with the liquid-frequency escalation
/// (score 7 three or more times in 24h → urgent).
func triageTier(for reading: StoolReading, liquidCountLast24h: Int) -> Tier {
    var tier = max(reading.consistency.tier,
                   max(reading.color.tier,
                       max(reading.coating.tier, reading.contents.tier)))
    if reading.consistency == .liquid && liquidCountLast24h >= 3 {
        tier = .urgent
    }
    return tier
}

// MARK: - Interventions & protocols

enum InterventionKind: String, Codable, CaseIterable, Identifiable {
    case fasted
    case blandDiet
    case pumpkin
    case probiotic
    case removedItem
    case startedMed
    case calledVet
    case vetVisit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fasted: return "Fasted"
        case .blandDiet: return "Bland diet"
        case .pumpkin: return "Pumpkin / fiber"
        case .probiotic: return "Probiotic"
        case .removedItem: return "Removed an item"
        case .startedMed: return "Started a med"
        case .calledVet: return "Called the vet"
        case .vetVisit: return "Vet visit"
        }
    }

    var symbol: String {
        switch self {
        case .fasted: return "clock"
        case .blandDiet: return "fork.knife"
        case .pumpkin: return "leaf"
        case .probiotic: return "pills"
        case .removedItem: return "minus.circle"
        case .startedMed: return "cross.vial"
        case .calledVet: return "phone"
        case .vetVisit: return "stethoscope"
        }
    }
}

// MARK: - Exposures

/// A cause-side input known at the moment it happens — meds and stress, plus
/// intake deviations. Sibling of cross-feeding: logged in the moment, surfaced
/// by the lookback, correlated by the insight engine.
enum ExposureKind: String, Codable, CaseIterable, Identifiable {
    case medStarted
    case medChanged
    case travelBoarding
    case houseGuests
    case stressfulEvent
    case foundOutside
    case tableFood
    case newChew

    var id: String { rawValue }

    var label: String {
        switch self {
        case .medStarted: return "Started a med"
        case .medChanged: return "Med change"
        case .travelBoarding: return "Travel / boarding"
        case .houseGuests: return "House guests"
        case .stressfulEvent: return "Stressful event"
        case .foundOutside: return "Found something outside"
        case .tableFood: return "Table food"
        case .newChew: return "New chew"
        }
    }

    var symbol: String {
        switch self {
        case .medStarted, .medChanged: return "pills.fill"
        case .travelBoarding: return "suitcase.fill"
        case .houseGuests: return "person.2.fill"
        case .stressfulEvent: return "cloud.bolt.fill"
        case .foundOutside: return "leaf.fill"
        case .tableFood: return "fork.knife"
        case .newChew: return "circle.grid.cross.fill"
        }
    }

    var isMedication: Bool {
        self == .medStarted || self == .medChanged
    }

    /// Stress-type exposures usually hit the whole household; meds hit one animal.
    var defaultsToHousehold: Bool {
        switch self {
        case .travelBoarding, .houseGuests, .stressfulEvent: return true
        default: return false
        }
    }
}

struct ExposureEvent: Identifiable, Codable {
    var id: UUID
    var petID: UUID? // nil = the whole household
    var kind: ExposureKind
    var note: String
    var date: Date

    init(id: UUID = UUID(), petID: UUID?, kind: ExposureKind, note: String = "", date: Date) {
        self.id = id
        self.petID = petID
        self.kind = kind
        self.note = note
        self.date = date
    }

    func applies(to pet: UUID) -> Bool {
        petID == nil || petID == pet
    }
}

// MARK: - Records

struct Pet: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var species: Species
    var breed: String
    var avatar: String // emoji avatar (avatars only — never on the clinical scale)
    var conditions: [String]
    var mode: PetMode
    var photoFilename: String? // profile photo in Documents/photos; emoji fallback when nil
    var birthdate: Date?

    init(id: UUID = UUID(), name: String, species: Species, breed: String, avatar: String,
         conditions: [String] = [], mode: PetMode = .baseline, photoFilename: String? = nil,
         birthdate: Date? = nil) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.avatar = avatar
        self.conditions = conditions
        self.mode = mode
        self.photoFilename = photoFilename
        self.birthdate = birthdate
    }

    /// "8 mo" / "4 yrs" — age is what the vet actually asks for.
    var ageLabel: String? {
        guard let birthdate else { return nil }
        let months = max(0, Calendar.current.dateComponents([.month], from: birthdate, to: Date()).month ?? 0)
        if months < 12 { return "\(months) mo" }
        let years = months / 12
        return "\(years) yr\(years == 1 ? "" : "s")"
    }
}

enum ItemScope: Codable, Equatable {
    case household
    case pet(UUID)
}

struct Item: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var scope: ItemScope
    var kind: String // food, treat, chew, med, supplement, water
    var firstIntroduced: Date

    init(id: UUID = UUID(), name: String, scope: ItemScope, kind: String, firstIntroduced: Date) {
        self.id = id
        self.name = name
        self.scope = scope
        self.kind = kind
        self.firstIntroduced = firstIntroduced
    }
}

struct OutputEvent: Identifiable, Codable {
    var id: UUID
    var petID: UUID
    var date: Date
    var reading: StoolReading
    var tier: Tier // computed at log time, with 24h context
    var note: String
    var photoFilename: String? // stored in Documents; nil when no photo attached

    init(id: UUID = UUID(), petID: UUID, date: Date, reading: StoolReading, tier: Tier, note: String = "", photoFilename: String? = nil) {
        self.id = id
        self.petID = petID
        self.date = date
        self.reading = reading
        self.tier = tier
        self.note = note
        self.photoFilename = photoFilename
    }
}

struct Intervention: Identifiable, Codable {
    var id: UUID
    var petID: UUID
    var episodeID: UUID?
    var kind: InterventionKind
    var date: Date

    init(id: UUID = UUID(), petID: UUID, episodeID: UUID?, kind: InterventionKind, date: Date) {
        self.id = id
        self.petID = petID
        self.episodeID = episodeID
        self.kind = kind
        self.date = date
    }
}

struct CrossFeed: Identifiable, Codable {
    var id: UUID
    var eaterID: UUID
    var foodOwnerID: UUID
    var amount: String // "a few bites", "the whole bowl"
    var date: Date

    init(id: UUID = UUID(), eaterID: UUID, foodOwnerID: UUID, amount: String, date: Date) {
        self.id = id
        self.eaterID = eaterID
        self.foodOwnerID = foodOwnerID
        self.amount = amount
        self.date = date
    }
}

struct Episode: Identifiable, Codable {
    var id: UUID
    var petID: UUID
    var start: Date
    var end: Date?
    var note: String // "what's wrong"

    var isActive: Bool { end == nil }

    var durationDays: Int {
        let endDate = end ?? Date()
        return max(1, Calendar.current.dateComponents([.day], from: start, to: endDate).day.map { $0 + 1 } ?? 1)
    }

    init(id: UUID = UUID(), petID: UUID, start: Date, end: Date? = nil, note: String) {
        self.id = id
        self.petID = petID
        self.start = start
        self.end = end
        self.note = note
    }
}

/// Number of trailing consecutive normal-tier outputs — resolution fires at 3.
func consecutiveNormals(events: [OutputEvent]) -> Int {
    let sorted = events.sorted { $0.date < $1.date }
    var count = 0
    for event in sorted.reversed() {
        if event.tier == .normal {
            count += 1
        } else {
            break
        }
    }
    return count
}
