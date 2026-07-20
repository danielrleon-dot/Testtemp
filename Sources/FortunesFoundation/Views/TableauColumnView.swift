import SwiftUI

struct TableauColumnView: View {
    let columnIndex: Int
    @ObservedObject var game: GameState

    private let cardHeight: CGFloat = 92
    private let overlap: CGFloat = 26

    var body: some View {
        let column = game.tableau[columnIndex]
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: 68, height: cardHeight)

            ForEach(Array(column.enumerated()), id: \.element.id) { index, card in
                let isApparent = index == column.count - 1
                CardView(card: card)
                    .offset(y: CGFloat(index) * overlap)
                    .zIndex(Double(index))
                    .gesture(dragGesture, including: isApparent ? .all : .none)
            }
        }
        .frame(width: 68, alignment: .top)
        .frame(minHeight: cardHeight + CGFloat(max(column.count - 1, 0)) * overlap, alignment: .top)
        .reportFrame(.tableau(columnIndex))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("board"))
            .onChanged { value in
                if game.dragging == nil {
                    game.beginDrag(from: .tableau(columnIndex))
                }
                game.dragPoint = value.location
            }
            .onEnded { value in
                game.endDrag(at: value.location)
            }
    }
}
