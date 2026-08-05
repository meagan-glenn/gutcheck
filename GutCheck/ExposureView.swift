import SwiftUI

/// Log a cause-side input the moment it happens: a med change, a stressful
/// event, an intake deviation. One tap each for what, who, and done.
struct ExposureSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ExposureKind?
    @State private var petID: UUID?
    @State private var wholeHousehold = false
    @State private var note = ""

    private let medKinds: [ExposureKind] = [.medStarted, .medChanged]
    private let stressKinds: [ExposureKind] = [.travelBoarding, .houseGuests, .stressfulEvent]
    private let intakeKinds: [ExposureKind] = [.foundOutside, .tableFood, .newChew]

    /// With one animal there's no "who" to ask — everything is theirs.
    private var soloPet: Pet? {
        store.data.pets.count == 1 ? store.data.pets.first : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Meds and stress change outputs too. Log it now — the lookback remembers so you don't have to.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    kindGroup(title: "Medication", kinds: medKinds)
                    kindGroup(title: "Stress & routine", kinds: stressKinds)
                    kindGroup(title: "Intake", kinds: intakeKinds)

                    if soloPet == nil {
                        SectionHeader(title: "Who?")
                        FlowLayout(spacing: 8) {
                            Chip(label: "Whole household", isSelected: wholeHousehold, tint: .accentColor) {
                                wholeHousehold = true
                                petID = nil
                            }
                            ForEach(store.data.pets) { pet in
                                Chip(label: "\(pet.avatar) \(pet.name)", isSelected: petID == pet.id, tint: .accentColor) {
                                    petID = pet.id
                                    wholeHousehold = false
                                }
                            }
                        }
                    }

                    TextField("Optional note — e.g. amoxicillin, fireworks", text: $note)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard let kind = kind else { return }
                        let target = soloPet?.id ?? (wholeHousehold ? nil : petID)
                        store.logExposure(kind: kind, petID: target, note: note)
                        dismiss()
                    } label: {
                        Text("Log it")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(kind == nil || (soloPet == nil && !wholeHousehold && petID == nil))
                }
                .padding()
            }
            .navigationTitle("Med / stress / intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func kindGroup(title: String, kinds: [ExposureKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            FlowLayout(spacing: 8) {
                ForEach(kinds) { option in
                    Chip(label: option.label, isSelected: kind == option, tint: .accentColor) {
                        kind = option
                        // Stress usually hits everyone; meds hit one animal.
                        if option.defaultsToHousehold && petID == nil {
                            wholeHousehold = true
                        }
                    }
                }
            }
        }
    }
}

/// A single exposure row, shared by lookback and episode timeline.
struct ExposureRow: View {
    @EnvironmentObject var store: AppStore
    let exposure: ExposureEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: exposure.kind.symbol)
                .foregroundColor(exposure.kind.isMedication ? Tier.concern.color : Color(red: 0.48, green: 0.35, blue: 0.72))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(exposure.kind.label + (exposure.note.isEmpty ? "" : " — \(exposure.note)"))
                    .font(.subheadline)
                Text("\(subject) · \(relativeDay(exposure.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
    }

    private var subject: String {
        if let petID = exposure.petID {
            return store.pet(petID)?.name ?? "Unknown"
        }
        return "Whole household"
    }
}
