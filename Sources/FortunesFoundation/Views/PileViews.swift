import SwiftUI

struct FoundationsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Suit.allCases) { suit in
                FoundationSlot(topCard: game.minorFoundations[suit]?.last, placeholderLabel: suit.symbol)
                    .contentShape(Rectangle())
                    .onTapGesture { game.selectPile(.foundationMinor(suit)) }
            }
            FoundationSlot(topCard: game.majorFoundation.last, placeholderLabel: "☾")
                .contentShape(Rectangle())
                .onTapGesture { game.selectPile(.foundationMajor) }
        }
    }
}

private struct FoundationSlot: View {
    let topCard: Card?
    let placeholderLabel: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: 70, height: 96)
            if let topCard {
                CardView(card: topCard)
            } else {
                Text(placeholderLabel)
                    .foregroundColor(.white.opacity(0.4))
                    .font(.title2)
            }
        }
    }
}

struct StockWasteView: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(game.stock.isEmpty ? Color.clear : Color(red: 0.20, green: 0.11, blue: 0.32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 70, height: 96)
                if game.stock.isEmpty {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("\(game.stock.count)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { game.drawFromStock() }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 70, height: 96)
                if let topWaste = game.waste.last {
                    CardView(card: topWaste, isSelected: isWasteSelected)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let top = game.waste.last {
                    game.selectCard(at: .waste, cardID: top.id)
                }
            }
        }
    }

    private var isWasteSelected: Bool {
        game.selection?.location == .waste
    }
}
