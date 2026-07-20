import SwiftUI

struct TableauColumnView: View {
    let columnIndex: Int
    @ObservedObject var game: GameState

    private let cardHeight: CGFloat = 96
    private let faceUpOverlap: CGFloat = 28
    private let faceDownOverlap: CGFloat = 14

    var body: some View {
        let column = game.tableau[columnIndex]
        ZStack(alignment: .top) {
            if column.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 70, height: cardHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { game.selectPile(.tableau(columnIndex)) }
            }
            ForEach(Array(column.enumerated()), id: \.element.id) { index, card in
                CardView(card: card, isSelected: isSelected(card))
                    .offset(y: offset(for: index, in: column))
                    .onTapGesture {
                        if card.isFaceUp {
                            game.selectCard(at: .tableau(columnIndex), cardID: card.id)
                        }
                    }
                    .zIndex(Double(index))
            }
        }
        .frame(width: 70, alignment: .top)
        .frame(minHeight: cardHeight + CGFloat(max(column.count - 1, 0)) * faceUpOverlap, alignment: .top)
    }

    private func isSelected(_ card: Card) -> Bool {
        game.selection?.location == .tableau(columnIndex) && game.selection?.cardIDs.contains(card.id) == true
    }

    private func offset(for index: Int, in column: [Card]) -> CGFloat {
        var y: CGFloat = 0
        for i in 0..<index {
            y += column[i].isFaceUp ? faceUpOverlap : faceDownOverlap
        }
        return y
    }
}
