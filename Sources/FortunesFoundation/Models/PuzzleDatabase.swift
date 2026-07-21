import Foundation

/// Persistent store of solved puzzles (see SolvedPuzzleRecord), used to
/// supervise-train SolitaireAI from known wins. A flat JSON file under
/// Application Support — simple, and plenty for what's realistically at
/// most a few thousand records.
final class PuzzleDatabase: ObservableObject {
    @Published private(set) var records: [SolvedPuzzleRecord] = []

    /// Records solved under the ruleset currently in effect
    /// (`GameState.rulesVersion`) — the only ones safe to train the AI
    /// from or trust as a "known win." A record stamped with a different
    /// version predates a rules change: its stored moves might not even
    /// be legal anymore (the solver replays them via `performMove`, which
    /// would simply fail partway through), and even if they happen to
    /// still replay cleanly, they no longer describe how the game is
    /// actually played, so training on them would teach the AI a game
    /// that no longer exists.
    var validRecords: [SolvedPuzzleRecord] {
        records.filter { $0.rulesVersion == GameState.rulesVersion }
    }

    /// Records kept on disk (nothing is ever deleted by a rules change)
    /// but excluded from `validRecords` because they predate the current
    /// rules — surfaced in the UI so a rules change doesn't silently make
    /// old puzzle-solving effort vanish without explanation.
    var staleRecordCount: Int {
        records.count - validRecords.count
    }

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Solitaire", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("SolvedPuzzles.json")
        load()
    }

    func add(_ record: SolvedPuzzleRecord) {
        records.append(record)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SolvedPuzzleRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
