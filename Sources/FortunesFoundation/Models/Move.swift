import Foundation

/// A candidate move: pick up the apparent card of `source` (or, if
/// `takeWholeRun` is true and one exists, the matching run behind it too)
/// and place it on `destination`. Produced by GameState.legalMoves() and
/// applied via GameState.performMove(_:recordForUndo:).
struct Move: Hashable {
    let source: PileLocation
    let destination: PileLocation
    let takeWholeRun: Bool
}
