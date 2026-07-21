import Foundation

/// Append-only, on-disk history of training runs (see TrainingLogEntry) —
/// a flat JSON file under Application Support, same location as
/// PuzzleDatabase's file. Purely diagnostic: nothing in the app reads it
/// back at runtime. It exists so the weights' evolution and the self-play
/// win rate can be reviewed together after the fact — export the file and
/// hand it to an outside reviewer (human or AI) rather than only ever
/// being able to see the evaluator's current weights in isolation.
///
/// Only ever touched from SolitaireAI's serial `trainingQueue`, which
/// already guarantees training runs (and therefore log appends) never
/// overlap — no locking needed here.
final class TrainingLog {
    private let fileURL: URL
    private var entries: [TrainingLogEntry]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Solitaire", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("TrainingLog.json")
        entries = Self.load(from: fileURL)
    }

    func append(_ entry: TrainingLogEntry) {
        entries.append(entry)
        guard let data = try? Self.makeEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [TrainingLogEntry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? makeDecoder().decode([TrainingLogEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
