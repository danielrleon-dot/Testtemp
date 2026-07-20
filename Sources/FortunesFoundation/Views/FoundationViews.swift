import SwiftUI

struct TrumpFoundationView: View {
    let title: String
    let pile: [Card]
    let location: PileLocation

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 74, height: 100)
                if let top = pile.last {
                    CardView(card: top)
                } else {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .frame(width: 64)
                }
            }
            .reportFrame(location)
            Text("\(pile.count)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct ColourFoundationView: View {
    let colour: Colour
    let pile: [Card]

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 74, height: 100)
                if let top = pile.last {
                    CardView(card: top)
                } else {
                    Text(colour.label)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .reportFrame(.colourFoundation(colour))
            Text("\(pile.count)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
