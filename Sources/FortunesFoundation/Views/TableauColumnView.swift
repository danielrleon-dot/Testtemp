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
                CardView(card: card)
                    .offset(y: CGFloat(index) * overlap)
                    .zIndex(Double(index))
                    .gesture(dragGesture(for: card.id))
            }
        }
        .frame(width: cardWidth, alignment: .top)
        .frame(minHeight: cardHeight + CGFloat(max(column.count - 1, 0)) * overlap, alignment: .top)
        .reportFrame(.tableau(columnIndex))
    }

    /// Every card in the column gets a gesture — beginDrag decides whether
    /// grabbing this particular card is even a valid pickup (see RULES.md:
    /// only the apparent card or the top of a matching run can be dragged).
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
