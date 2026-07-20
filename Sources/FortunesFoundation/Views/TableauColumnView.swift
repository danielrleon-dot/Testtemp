import SwiftUI

struct TableauColumnView: View {
    let columnIndex: Int
    @ObservedObject var game: GameState

    private let cardWidth: CGFloat = 74
    private let cardHeight: CGFloat = 100
    private let overlap: CGFloat = 34

    var body: some View {
        let column = game.tableau[columnIndex]
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: cardWidth, height: cardHeight)

            ForEach(Array(column.enumerated()), id: \.element.id) { index, card in
                let isApparent = index == column.count - 1
                CardView(card: card)
                    .offset(y: CGFloat(index) * overlap)
                    .zIndex(Double(index))
                    .gesture(dragGesture(for: card.id), including: isApparent ? .all : .none)
            }
        }
        .frame(width: cardWidth, alignment: .top)
        .frame(minHeight: cardHeight + CGFloat(max(column.count - 1, 0)) * overlap, alignment: .top)
        .reportFrame(.tableau(columnIndex))
    }

    /// Only the apparent (bottom) card is ever a valid drag handle — see
    /// RULES.md: whether the rest of a matching run follows is decided by
    /// where this single card gets dropped, not by which card you grab.
    private func dragGesture(for cardID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("board"))
            .onChanged { value in
                if game.dragging == nil {
                    game.beginDrag(from: .tableau(columnIndex), cardID: cardID)
                }
                game.dragPoint = value.location
            }
            .onEnded { value in
                game.endDrag(at: value.location)
            }
    }
}
