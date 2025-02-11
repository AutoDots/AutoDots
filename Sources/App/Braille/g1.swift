import Foundation
public func input (_ message: String) -> String {
	print(message)
	return String(readLine()!)
}
// MARK: - Braille Conversion Functions

// Mapping of lowercase letters to uncontracted Braille
let uncontractedBrailleMapping: [Character: String] = [
    "a": "⠁", "b": "⠃", "c": "⠉", "d": "⠙", "e": "⠑",
    "f": "⠋", "g": "⠛", "h": "⠓", "i": "⠊", "j": "⠚",
    "k": "⠅", "l": "⠇", "m": "⠍", "n": "⠝", "o": "⠕",
    "p": "⠏", "q": "⠟", "r": "⠗", "s": "⠎", "t": "⠞",
    "u": "⠥", "v": "⠧", "w": "⠺", "x": "⠭", "y": "⠽", "z": "⠵",
    " ": " " // Include space
]

// Mapping of numbers and symbols to uncontracted Braille
let numberSymbolBrailleMapping: [Character: String] = [
    "1": "⠁", "2": "⠃", "3": "⠉", "4": "⠙", "5": "⠑",
    "6": "⠋", "7": "⠛", "8": "⠓", "9": "⠊", "0": "⠚",
    "+": "⠐⠖", "−": "⠐⠤", "÷": "⠐⠌", "×": "⠐⠦",
    "'": "⠄", ",": "⠂", ".": "⠲", ";": "⠆", "-": "⠤", "/": "⠸⠌", "\\": "⠸⠡", "|": "⠸⠳", "(": "⠐⠣", ")": "⠐⠜", "[": "⠨⠣", "]": "⠨⠜", "{": "⠸⠣", "}": "⠸⠜", "?": "⠦", "\"": "⠴", ":": "⠒", "!": "⠖", "=": "⠐⠶", "%": "⠨⠴"
]

// Create a combined mapping for text-to-braille
let combinedTextToBrailleMapping = uncontractedBrailleMapping.merging(numberSymbolBrailleMapping) { (current, _) in current }

// MARK: - Text to Uncontracted Braille

func textToUncontractedBraille(_ text: String) -> String {
    var result = ""
    var inMathMode = false

    for char in text {
        let lowercaseChar = Character(String(char).lowercased())
        if let braille = combinedTextToBrailleMapping[lowercaseChar] {
            if "1234567890".contains(char) {
                if !inMathMode {
                    result += "⠼"
                    inMathMode = true
                }
               result += braille
            } else {
                inMathMode = false
                if char.isUppercase {
                    result += "⠠\(braille)"
                } else {
                    result += braille
                }
            }
        } else {
            inMathMode = false
            result += String(char)
        }
    }
    return result
}
