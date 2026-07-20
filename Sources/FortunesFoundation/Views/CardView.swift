import SwiftUI

struct CardView: View {
    let card: Card
    var isSelected: Bool = false
    var width: CGFloat = 70
    var height: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(card.isFaceUp ? Color(white: 0.98) : backColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.yellow : Color.black.opacity(0.4), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(radius: 1, y: 1)

            if card.isFaceUp {
                VStack(spacing: 4) {
                    Text(card.shortLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if card.isMajor {
                        Text(card.displayLabel)
                            .font(.system(size: 9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .foregroundColor(textColor)
                .padding(4)
            } else {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: width, height: height)
    }

    private var backColor: Color {
        Color(red: 0.20, green: 0.11, blue: 0.32)
    }

    private var textColor: Color {
        guard card.isFaceUp else { return .white }
        if card.isMajor { return Color(red: 0.45, green: 0.1, blue: 0.5) }
        switch card.suitColor {
        case .crimson: return Color(red: 0.7, green: 0.1, blue: 0.15)
        case .indigo: return Color(red: 0.1, green: 0.15, blue: 0.55)
        case .none: return .black
        }
    }
}
