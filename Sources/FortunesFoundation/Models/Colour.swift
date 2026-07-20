import Foundation

enum Colour: String, CaseIterable, Identifiable, Codable, Hashable {
    case red, blue, green, yellow

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var shortCode: String {
        switch self {
        case .red: return "R"
        case .blue: return "B"
        case .green: return "G"
        case .yellow: return "Y"
        }
    }
}
