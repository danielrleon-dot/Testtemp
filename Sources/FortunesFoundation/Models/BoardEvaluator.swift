import Foundation

/// A linear value function over BoardFeatures, trained via TD(0) self-play:
/// predicts how promising a state is (higher = closer to winning). No
/// neural network on purpose — this is simple enough to train fast on a
/// laptop CPU with no ML framework dependency, and easy to reason about.
struct BoardEvaluator: Codable {
    var weights: [Double]

    /// Hard bound on any single weight — a defensive backstop against
    /// runaway divergence in the TD update. Semi-gradient bootstrapping
    /// with function approximation isn't guaranteed to converge, and in
    /// practice (see BoardFeatures' doc comment) it diverged to ~1e189
    /// over real training. Every target value this evaluator is ever
    /// trained toward is bounded to roughly ±50 (see SolitaireAI), so a
    /// generous multiple of that is enough headroom for legitimate
    /// learning while still making runaway growth impossible.
    private static let weightBound = 200.0

    init(weights: [Double]? = nil) {
        self.weights = weights ?? Array(repeating: 0, count: BoardFeatures.count)
    }

    func value(for features: [Double]) -> Double {
        zip(weights, features).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// One TD(0) step: nudges weights to reduce the gap between this
    /// state's predicted value and `targetValue` (reward + discounted
    /// value of whatever state followed it).
    mutating func update(features: [Double], targetValue: Double, learningRate: Double) {
        let error = targetValue - value(for: features)
        for i in weights.indices {
            let updated = weights[i] + learningRate * error * features[i]
            weights[i] = min(Self.weightBound, max(-Self.weightBound, updated))
        }
    }
}

extension BoardEvaluator {
    private static let defaultsKey = "SolitaireAI.evaluatorWeights"

    /// Loads previously-trained weights, if any exist and still match the
    /// current feature shape (a mismatch means BoardFeatures changed since
    /// they were saved — starting fresh is safer than a silently-wrong dot
    /// product against the wrong-length weight vector).
    static func loadFromDisk() -> BoardEvaluator? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let weights = try? JSONDecoder().decode([Double].self, from: data),
              weights.count == BoardFeatures.count else {
            return nil
        }
        return BoardEvaluator(weights: weights)
    }

    func saveToDisk() {
        guard let data = try? JSONEncoder().encode(weights) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
