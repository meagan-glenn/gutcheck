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
        case .chronic: return Color(red: 0.48, green: 0.35, blue: 0.72)
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
