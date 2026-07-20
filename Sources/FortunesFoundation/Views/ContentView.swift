import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameState()

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                header
                foundationRow
                tableauRow
                Spacer()
            }
            .padding(.top, 16)

            if let dragging = game.dragging, let point = game.dragPoint {
                DraggedStackView(cards: dragging.cards)
                    .position(point)
            }
        }
        .coordinateSpace(name: "board")
        .onPreferenceChange(TargetFramePreferenceKey.self) { game.targetFrames = $0 }
        .frame(minWidth: 1180, minHeight: 720)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.09, blue: 0.07), Color(red: 0.02, green: 0.03, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("All 70 cards are home!", isPresented: $game.isWon) {
            Button("New Game") { game.newGame() }
        }
    }

    private var header: some View {
        HStack {
            Text("Solitaire")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Text("Moves: \(game.moveCount)")
                .foregroundColor(.white.opacity(0.7))
            Button("New Game") { game.newGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
    }

    private var foundationRow: some View {
        HStack(spacing: 14) {
            ReserveView(game: game)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 100)

            TrumpFoundationView(title: "Trumps ↑ from 0", pile: game.bottomTrump, location: .bottomTrump)
            TrumpFoundationView(title: "Trumps ↓ from 21", pile: game.topTrump, location: .topTrump)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 100)

            ForEach(Colour.allCases) { colour in
                ColourFoundationView(colour: colour, pile: game.colourFoundations[colour] ?? [])
            }
        }
        .padding(.horizontal, 24)
    }

    private var tableauRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<GameState.columnCount, id: \.self) { col in
                TableauColumnView(columnIndex: col, game: game)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
}
