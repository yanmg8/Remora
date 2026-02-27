import AppKit
import Foundation

public final class TerminalInputMapper {
    public init() {}

    public func map(event: NSEvent) -> Data? {
        switch event.keyCode {
        case 123: // left
            return Data("\u{1B}[D".utf8)
        case 124: // right
            return Data("\u{1B}[C".utf8)
        case 125: // down
            return Data("\u{1B}[B".utf8)
        case 126: // up
            return Data("\u{1B}[A".utf8)
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
