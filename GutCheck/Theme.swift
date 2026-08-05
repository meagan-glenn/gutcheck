import SwiftUI

extension Tier {
    var color: Color {
        switch self {
        case .normal: return Color(red: 0.22, green: 0.62, blue: 0.41)
        case .monitor: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .concern: return Color(red: 0.87, green: 0.44, blue: 0.15)
        case .urgent: return Color(red: 0.78, green: 0.16, blue: 0.16)
        }
    }
}

extension PetMode {
    var badgeColor: Color {
        switch self {
        case .baseline: return Color.secondary.opacity(0.5)
        case .watch: return Tier.monitor.color
        }
    }
}

/// Circular profile photo when the pet has one, emoji avatar otherwise.
struct PetAvatar: View {
    @EnvironmentObject var store: AppStore
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        if let filename = pet.photoFilename,
           let image = UIImage(contentsOfFile: store.photoURL(filename).path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(pet.avatar)
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)
        }
    }
}

/// A selectable capture chip. Ordinal, sober — no emoji on the clinical scale.
struct Chip: View {
    let label: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? tint.opacity(0.18) : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule().stroke(isSelected ? tint : Color.clear, lineWidth: 1.5)
                )
                .foregroundColor(isSelected ? tint : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TierBadge: View {
    let tier: Tier

    var body: some View {
        Text(tier.label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tier.color.opacity(0.15)))
            .foregroundColor(tier.color)
    }
}

/// Note field shaped like the chips it lives among.
struct PillTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
