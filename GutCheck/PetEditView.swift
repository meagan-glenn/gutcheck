import SwiftUI

/// Edit what's going on with this animal: identity, conditions, chronic pin.
struct PetEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var pet: Pet
    @State private var conditionsText: String

    private let avatarOptions = ["🐕", "🦮", "🐶", "🐕‍🦺", "🐩", "🐺", "🐈", "🐈‍⬛"]

    init(pet: Pet) {
        _pet = State(initialValue: pet)
        _conditionsText = State(initialValue: pet.conditions.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $pet.name)
                    TextField("Breed", text: $pet.breed)
                    FlowLayout(spacing: 8) {
                        ForEach(avatarOptions, id: \.self) { option in
                            Chip(label: option, isSelected: pet.avatar == option, tint: .accentColor) {
                                pet.avatar = option
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    TextField("e.g. sensitive gut, seasonal allergies", text: $conditionsText)
                } header: {
                    Text("Conditions")
                } footer: {
                    Text("Comma-separated. Shown on vet summaries.")
                }
                Section {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit \(pet.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        pet.conditions = conditionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.updatePet(pet)
        dismiss()
    }
}
