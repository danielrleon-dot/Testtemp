import Foundation

enum MajorArcana: Int, CaseIterable, Identifiable, Codable, Hashable {
    case fool = 0, magician, highPriestess, empress, emperor, hierophant, lovers, chariot,
         strength, hermit, wheelOfFortune, justice, hangedMan, death, temperance, devil,
         tower, star, moon, sun, judgement, world

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .fool: return "The Fool"
        case .magician: return "The Magician"
        case .highPriestess: return "The High Priestess"
        case .empress: return "The Empress"
        case .emperor: return "The Emperor"
        case .hierophant: return "The Hierophant"
        case .lovers: return "The Lovers"
        case .chariot: return "The Chariot"
        case .strength: return "Strength"
        case .hermit: return "The Hermit"
        case .wheelOfFortune: return "Wheel of Fortune"
        case .justice: return "Justice"
        case .hangedMan: return "The Hanged Man"
        case .death: return "Death"
        case .temperance: return "Temperance"
        case .devil: return "The Devil"
        case .tower: return "The Tower"
        case .star: return "The Star"
        case .moon: return "The Moon"
        case .sun: return "The Sun"
        case .judgement: return "Judgement"
        case .world: return "The World"
        }
    }
}
