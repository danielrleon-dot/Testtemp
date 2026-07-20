import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 74
    var height: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: card.isTrump ? 2.5 : 1.5)
                )
                .shadow(radius: 1, y: 1)

            // Left accent bar stays visible even in the thin sliver of a
            // buried tableau card, so colour/trump is readable at a glance.
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6)
                .padding(.vertical, 6)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                Text(rankText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(labelColor)
                Text(subLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(labelColor.opacity(0.85))
            }
            .padding(.top, 5)
            .padding(.leading, 15)
        }
        .frame(width: width, height: height)
    }

    private var rankText: String {
        switch card.kind {
        case .colour(_, let rank): return rank.label
        case .trump(let n): return "\(n)"
        }
    }

    private var subLabel: String {
        switch card.kind {
        case .colour(let colour, _): return colour.label.uppercased()
        case .trump: return "TRUMP"
        }
    }

    private var accentColor: Color {
        guard let colour = card.colour else { return trumpColor }
        return colourColor(colour)
    }

    private var labelColor: Color {
        guard let colour = card.colour else { return trumpColor }
        return colourColor(colour)
    }

    private var borderColor: Color {
        accentColor.opacity(card.isTrump ? 0.9 : 0.6)
    }

    private var backgroundFill: Color {
        guard let colour = card.colour else { return trumpColor.opacity(0.1) }
        return colourColor(colour).opacity(0.1)
    }

    private var trumpColor: Color {
        Color(red: 0.45, green: 0.15, blue: 0.55)
    }

    private func colourColor(_ colour: Colour) -> Color {
        switch colour {
        case .red: return Color(red: 0.78, green: 0.1, blue: 0.1)
        case .blue: return Color(red: 0.1, green: 0.32, blue: 0.85)
        case .green: return Color(red: 0.1, green: 0.55, blue: 0.2)
        case .yellow: return Color(red: 0.72, green: 0.55, blue: 0.0)
        }
    }
}
