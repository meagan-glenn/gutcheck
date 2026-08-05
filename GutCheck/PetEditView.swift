import SwiftUI
import PhotosUI

/// Edit what's going on with this animal: identity, photo, conditions.
struct PetEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var pet: Pet
    @State private var conditionsText: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showBreedPicker = false
    @State private var hasBirthday: Bool
    @State private var birthdate: Date
    @State private var showArchiveConfirm = false

    init(pet: Pet) {
        _pet = State(initialValue: pet)
        _conditionsText = State(initialValue: pet.conditions.joined(separator: ", "))
        _hasBirthday = State(initialValue: pet.birthdate != nil)
        _birthdate = State(initialValue: pet.birthdate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 8) {
                            if let photoData, let image = UIImage(data: photoData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } else {
                                PetAvatar(pet: pet, size: 96)
                            }
                            Label(pet.photoFilename == nil && photoData == nil ? "Add a photo" : "Change photo",
                                  systemImage: "camera.fill")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .onChange(of: photoItem) { newItem in
                    Task {
                        photoData = try? await newItem?.loadTransferable(type: Data.self)
                    }
                }
                Section("Basics") {
                    TextField("Name", text: $pet.name)
                    Button {
                        showBreedPicker = true
                    } label: {
                        HStack {
                            Text("Breed")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(pet.breed.isEmpty ? "Choose" : pet.breed)
                                .foregroundColor(pet.breed.isEmpty ? .secondary : .accentColor)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    BirthdayRow(hasBirthday: $hasBirthday, birthdate: $birthdate)
                    if pet.photoFilename == nil && photoData == nil {
                        FlowLayout(spacing: 8) {
                            ForEach(pet.species.avatarOptions, id: \.self) { option in
                                Chip(label: option, isSelected: pet.avatar == option, tint: .accentColor) {
                                    pet.avatar = option
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                Section {
                    Button(role: .destructive) {
                        showArchiveConfirm = true
                    } label: {
                        Text("Remove from household")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Every log and episode is kept. Restore any time from the home screen.")
                }
            }
            .navigationTitle("Edit \(pet.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showBreedPicker) {
                BreedPicker(species: pet.species, selection: $pet.breed)
            }
            .confirmationDialog("Remove \(pet.name) from the household?", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
                Button("Remove, keep the history", role: .destructive) {
                    store.archivePet(pet.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Any open episode is closed. Nothing is deleted.")
            }
        }
    }

    private func save() {
        pet.conditions = conditionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let photoData {
            pet.photoFilename = store.savePhoto(photoData)
        }
        pet.birthdate = hasBirthday ? birthdate : nil
        store.updatePet(pet)
        dismiss()
    }
}
