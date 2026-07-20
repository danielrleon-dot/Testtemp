import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameState()

    var body: some View {
        VStack(spacing: 20) {
            header

            HStack(alignment: .top, spacing: 24) {
                StockWasteView(game: game)
                Spacer()
                FoundationsView(game: game)
            }
            .padding(.horizontal, 24)

            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<8, id: \.self) { col in
                    TableauColumnView(columnIndex: col, game: game)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 16)
        .frame(minWidth: 920, minHeight: 680)
        .background(
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.05, blue: 0.16), Color(red: 0.03, green: 0.02, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("You cleared the fortune!", isPresented: $game.isWon) {
            Button("New Game") { game.newGame() }
        }
    }

    private var header: some View {
        HStack {
            Text("Fortune's Foundation")
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
}

#Preview {
    ContentView()
}
