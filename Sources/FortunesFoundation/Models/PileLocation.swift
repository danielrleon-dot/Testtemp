import Foundation

enum PileLocation: Hashable {
    case tableau(Int)
    case reserve
    case bottomTrump
    case topTrump
    case colourFoundation(Colour)
}
