import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 68
    var height: CGFloat = 92

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: card.isTrump ? 2 : 1.5)
                )
                .shadow(radius: 1, y: 1)

            VStack(spacing: 2) {
                Text(card.shortLabel)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                if card.isTrump {
                    Text("TRUMP")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(1)
                }
            }
            .foregroundColor(textColor)
        }
        .frame(width: width, height: height)
    }

    private var textColor: Color {
        guard let colour = card.colour else { return .black }
        return colourColor(colour)
    }

    private var borderColor: Color {
        if card.isTrump { return .black.opacity(0.75) }
        guard let colour = card.colour else { return .black.opacity(0.4) }
        return colourColor(colour).opacity(0.6)
    }

    private func colourColor(_ colour: Colour) -> Color {
        switch colour {
        case .red: return Color(red: 0.72, green: 0.12, blue: 0.12)
        case .blue: return Color(red: 0.12, green: 0.28, blue: 0.75)
        case .green: return Color(red: 0.13, green: 0.5, blue: 0.22)
        case .yellow: return Color(red: 0.75, green: 0.58, blue: 0.05)
        }
    }
}
