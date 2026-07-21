import Foundation

/// Persistent store of solved puzzles (see SolvedPuzzleRecord), used to
/// supervise-train SolitaireAI from known wins. A flat JSON file under
/// Application Support — simple, and plenty for what's realistically at
/// most a few thousand records.
///
/// `records` only ever holds puzzles solved under the *current*
/// `GameState.rulesVersion`. `load()` prunes anything stamped with a
/// different version the moment the database is opened, and immediately
/// rewrites the file without them — a rules change can invalidate both
/// the legality (the stored moves may not even replay) and the meaning
/// of an older solution, so there's no "stale but kept around" state:
/// once the rules change, those records are permanently gone the next
/// time the app launches and opens this file.
final class PuzzleDatabase: ObservableObject {
    @Published private(set) var records: [SolvedPuzzleRecord] = []

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
        let current = decoded.filter { $0.rulesVersion == GameState.rulesVersion }
        records = current
        if current.count != decoded.count {
            // Rules changed since this file was last written — drop the
            // now-stale records from disk instead of just hiding them, so
            // the database never silently accumulates puzzles that no
            // longer apply.
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
