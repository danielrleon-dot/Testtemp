import SwiftUI

struct ReserveView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 68, height: 92)
                if let card = game.reserve {
                    CardView(card: card)
                        .gesture(dragGesture)
                } else {
                    Text("Reserve")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .reportFrame(.reserve)
            Text(" ")
                .font(.caption2)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("board"))
            .onChanged { value in
                if game.dragging == nil {
                    game.beginDrag(from: .reserve)
                }
                game.dragPoint = value.location
            }
            .onEnded { value in
                game.endDrag(at: value.location)
            }
    }
}
