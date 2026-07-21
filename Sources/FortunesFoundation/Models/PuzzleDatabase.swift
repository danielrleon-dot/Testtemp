import Foundation

/// Persistent store of solved puzzles (see SolvedPuzzleRecord), used to
/// supervise-train SolitaireAI from known wins. A flat JSON file under
/// Application Support — simple, and plenty for what's realistically at
/// most a few thousand records.
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
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
