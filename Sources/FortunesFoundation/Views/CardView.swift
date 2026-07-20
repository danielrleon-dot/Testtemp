import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 74
    var height: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Opaque white base, then a translucent colour wash on top of it —
            // both layered here so the card is fully opaque and never shows
            // whatever is behind it in the rest of the app.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).fill(backgroundFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: card.isTrump ? 2.5 : 1.5)
                )
                .shadow(radius: 1, y: 1)

            // Large, faint watermark symbol — only visible on a fully-exposed
            // card (buried tableau cards are covered before this shows).
            Text(symbolText)
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(accentColor.opacity(0.16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 6)
                .padding(.bottom, 2)

            // Left accent bar stays visible even in the thin sliver of a
            // buried tableau card, so colour/trump is readable at a glance.
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6)
                .padding(.vertical, 6)
                .padding(.leading, 4)

            Text(rankText)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(labelColor)
                .padding(.top, 5)
                .padding(.leading, 15)

            // Suit symbol on the right edge, in the same top sliver that
            // stays visible when another card overlaps this one from below.
            Text(symbolText)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(labelColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
        .frame(width: width, height: height)
    }

    private var rankText: String {
        switch card.kind {
        case .colour(_, let rank): return rank.label
        case .trump(let n): return "\(n)"
        }
    }

    /// Suit symbol for colour cards; a star stands in for trumps, which have no colour.
    private var symbolText: String {
        guard let colour = card.colour else { return "★" }
        return colour.symbol
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
