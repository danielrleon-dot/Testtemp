import SwiftUI

struct DraggedStackView: View {
    let cards: [Card]

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                CardView(card: card)
                    .offset(y: CGFloat(index) * 34)
            }
        }
        .shadow(radius: 8, y: 4)
        .allowsHitTesting(false)
    }
}
