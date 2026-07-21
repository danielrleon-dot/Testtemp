import Foundation

enum PileLocation: Hashable, Codable {
    case tableau(Int)
    case reserve
    case bottomTrump
    case topTrump
    case colourFoundation(Colour)
}
