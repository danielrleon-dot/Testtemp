import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameState()
    @StateObject private var ai = SolitaireAI()
    @State private var seedInput: String = ""

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                header
                aiPanel
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
        VStack(spacing: 8) {
            HStack {
                Text("Solitaire")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                seedControls
                Button("New Game") { game.newGame() }
                    .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                Text("Moves: \(game.moveCount)")
                    .foregroundColor(.white.opacity(0.7))

                historyButton(title: "Undo", systemImage: "arrow.uturn.backward", color: .orange, enabled: game.canUndo) {
                    game.undo()
                }
                historyButton(title: "Redo", systemImage: "arrow.uturn.forward", color: .teal, enabled: game.canRedo) {
                    game.redo()
                }

                Spacer()
                Toggle("Drag whole column", isOn: $game.moveWholeColumn)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 24)
    }

    private var seedControls: some View {
        HStack(spacing: 6) {
            Text("Seed:")
                .foregroundColor(.white.opacity(0.6))
            // Text(verbatim:) avoids SwiftUI's automatic locale grouping
            // (e.g. "1,234") that a numeric string interpolation would
            // apply — the seed needs to stay copy-pasteable as plain digits.
            Text(verbatim: String(game.currentSeed))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)

            TextField("Replay a seed", text: $seedInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            Button("Play Seed") {
                guard let value = parsedSeed else { return }
                game.newGame(seed: value)
            }
            .disabled(parsedSeed == nil)
        }
    }

    /// Tolerates commas/spaces (e.g. pasted straight from the seed display,
    /// or from a locale that groups digits) in addition to plain digits.
    private var parsedSeed: UInt64? {
        let cleaned = seedInput.filter { $0.isNumber }
        return cleaned.isEmpty ? nil : UInt64(cleaned)
    }

    /// Explicitly-coloured button (rather than the system's adaptive
    /// bordered style) so it stays clearly visible against the dark
    /// background regardless of the system's light/dark appearance.
    private func historyButton(
        title: String,
        systemImage: String,
        color: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(enabled ? color : Color.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var aiPanel: some View {
        HStack(spacing: 12) {
            Text("AI:")
                .foregroundColor(.white.opacity(0.6))
            Text(aiSummary)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))

            Button {
                ai.train(episodes: 200)
            } label: {
                HStack(spacing: 6) {
                    if ai.isTraining {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(ai.isTraining ? "Training…" : "Train 200 games")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ai.isTraining ? Color.gray.opacity(0.35) : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(ai.isTraining)

            historyButton(title: "AI Move", systemImage: "sparkles", color: .purple, enabled: !ai.isTraining && !game.isWon) {
                if let move = ai.suggestMove(for: game) {
                    game.performMove(move, recordForUndo: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var aiSummary: String {
        let lifetime = "\(ai.totalEpisodesTrained) lifetime"
        guard ai.gamesPlayed > 0 else {
            return ai.totalEpisodesTrained > 0 ? "untrained this session · \(lifetime)" : "untrained"
        }
        let winPercent = Int((Double(ai.gamesWon) / Double(ai.gamesPlayed) * 100).rounded())
        return "\(ai.gamesWon)/\(ai.gamesPlayed) won this session (\(winPercent)%) · \(lifetime)"
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
