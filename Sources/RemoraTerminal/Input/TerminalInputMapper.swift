import AppKit
import Foundation

public final class TerminalInputMapper {
    public var applicationCursorKeysEnabled: Bool = false

    public init() {}

    public func map(event: NSEvent) -> Data? {
        let upSequence = applicationCursorKeysEnabled ? "\u{1B}OA" : "\u{1B}[A"
        let downSequence = applicationCursorKeysEnabled ? "\u{1B}OB" : "\u{1B}[B"
        let rightSequence = applicationCursorKeysEnabled ? "\u{1B}OC" : "\u{1B}[C"
        let leftSequence = applicationCursorKeysEnabled ? "\u{1B}OD" : "\u{1B}[D"

        switch event.keyCode {
        case 123: // left
            return Data(leftSequence.utf8)
        case 124: // right
            return Data(rightSequence.utf8)
        case 125: // down
            return Data(downSequence.utf8)
        case 126: // up
            return Data(upSequence.utf8)
        case 51: // delete
            return Data([0x7F])
        default:
            break
        }

        if event.modifierFlags.contains(.control), let chars = event.charactersIgnoringModifiers, chars.count == 1,
           let scalar = chars.unicodeScalars.first
        {
            let value = UInt8(scalar.value) & 0x1F
            return Data([value])
        }

        guard let chars = event.characters else { return nil }
        return Data(chars.utf8)
    }
}
