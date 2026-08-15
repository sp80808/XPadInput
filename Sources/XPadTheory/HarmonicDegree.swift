import Foundation
import XPadCore

public enum RomanNumeral: String, Codable, Sendable {
    case I = "I"
    case ii = "ii"
    case iii = "iii"
    case IV = "IV"
    case V = "V"
    case vi = "vi"
    case viiDim = "vii°"
    
    // Minor scale degrees
    case i = "i"
    case iiDim = "ii°"
    case III = "III"
    case iv = "iv"
    case v = "v"
    case VI = "VI"
    case VII = "VII"
    
    // Chromatic / Borrowed / Secondary
    case bII = "♭II (Neapolitan)"
    case bIII = "♭III"
    case IVMaj7 = "IVmaj7"
    case bVI = "♭VI"
    case bVII = "♭VII"
    case VofV = "V/V"
    case Vofvi = "V/vi"
    case VofIV = "V/IV"
    case subV = "subV7"
}

public struct HarmonicDegree: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(romanNumeral.rawValue)_\(chord.symbol)" }
    public let romanNumeral: RomanNumeral
    public let chord: Chord
    public let harmonicFunction: String // "Tonic", "Subdominant", "Dominant", "Modal Interchange"
    public let description: String
    
    public init(
        romanNumeral: RomanNumeral,
        chord: Chord,
        harmonicFunction: String,
        description: String
    ) {
        self.romanNumeral = romanNumeral
        self.chord = chord
        self.harmonicFunction = harmonicFunction
        self.description = description
    }
}
