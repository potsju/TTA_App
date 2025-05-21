import Foundation

extension Character {
    var isSpecialCharacter: Bool {
        return !isLetter && !isNumber
    }
} 