import Foundation

public final class ANSIParser {
    // Terminal modes
    public var mouseReportingEnabled: Bool = false
    public var bracketedPasteEnabled: Bool = false
    
    private enum State {
        case ground
        case escape
        case csi([UInt8])
        case osc
        case oscEscape
    }

    private var state: State = .ground

    public init() {}

    public func parse(_ data: Data, into screen: ScreenBuffer) {
        for byte in data {
            step(byte: byte, screen: screen)
        }
    }

    private func step(byte: UInt8, screen: ScreenBuffer) {
        switch state {
        case .ground:
            handleGround(byte: byte, screen: screen)
        case .escape:
            if byte == UInt8(ascii: "[") {
                state = .csi([])
            } else if byte == UInt8(ascii: "]") {
                state = .osc
            } else if byte == UInt8(ascii: "7") {
                // DECSC - Save Cursor
                screen.saveCursor()
                state = .ground
            } else if byte == UInt8(ascii: "8") {
                // DECRC - Restore Cursor
                screen.restoreCursor()
                state = .ground
            } else {
                state = .ground
            }
        case .csi(var bytes):
            if (0x40 ... 0x7E).contains(byte) {
                executeCSI(finalByte: byte, paramsBytes: bytes, screen: screen)
                state = .ground
            } else {
                bytes.append(byte)
                state = .csi(bytes)
            }
        case .osc:
            if byte == 0x07 {
                state = .ground
            } else if byte == 0x1B {
                state = .oscEscape
            }
        case .oscEscape:
            if byte == UInt8(ascii: "\\") {
                state = .ground
            } else if byte != 0x1B {
                state = .osc
            }
        }
    }

    private func handleGround(byte: UInt8, screen: ScreenBuffer) {
        switch byte {
        case 0x1B:
            state = .escape
        case 0x0A:
            screen.lineFeed()
        case 0x0D:
            screen.carriageReturn()
        case 0x08:
            screen.backspace()
        case 0x09:
            screen.horizontalTab()
        case 0x20 ... 0x7E:
            if let scalar = UnicodeScalar(Int(byte)) {
                screen.put(character: Character(scalar))
            }
        default:
            break
        }
    }

    private func executeCSI(finalByte: UInt8, paramsBytes: [UInt8], screen: ScreenBuffer) {
        let paramsString = String(decoding: paramsBytes, as: UTF8.self)
        let params = parseParams(paramsString)

        switch finalByte {
        case UInt8(ascii: "m"):
            screen.applySGR(parameters: params)
        case UInt8(ascii: "H"), UInt8(ascii: "f"):
            let row = (params.first ?? 1) - 1
            let col = (params.dropFirst().first ?? 1) - 1
            screen.moveCursor(row: row, column: col)
case UInt8(ascii: "J"):
            screen.clearScreen(mode: params.first ?? 0)
            if params.first == 2 {
                screen.clearScreen()
            }
        case UInt8(ascii: "K"):
            screen.clearLine(mode: params.first ?? 0)
        case UInt8(ascii: "A"):
            screen.moveCursor(deltaRow: -(params.first ?? 1))
        case UInt8(ascii: "B"):
            screen.moveCursor(deltaRow: params.first ?? 1)
        case UInt8(ascii: "C"):
            screen.moveCursor(deltaColumn: params.first ?? 1)
        case UInt8(ascii: "D"):
            screen.moveCursor(deltaColumn: -(params.first ?? 1))
        case UInt8(ascii: "h"):
            // Private mode set (DECSET)
            handlePrivateModeSet(paramsString: paramsString, screen: screen)
        case UInt8(ascii: "l"):
            // Private mode reset (DECRST)
            handlePrivateModeReset(paramsString: paramsString, screen: screen)
        default:
            break
        }
    }
    
    // MARK: - Private Mode Handlers
    
    private func handlePrivateModeSet(paramsString: String, screen: ScreenBuffer) {
        // Handle ?XXXXh sequences
        if paramsString.hasPrefix("?") {
            let modeStr = String(paramsString.dropFirst())
            
            switch modeStr {
            case "1049":
                // Enter alternate screen buffer
                screen.enterAlternateBuffer()
            case "1048":
                // Save cursor (handled by ESC 7)
                screen.saveCursor()
            case "1000", "1002", "1003":
                // Mouse tracking modes
                mouseReportingEnabled = true
            case "2004":
                // Bracketed paste
                bracketedPasteEnabled = true
            default:
                break
            }
        }
    }
    
    private func handlePrivateModeReset(paramsString: String, screen: ScreenBuffer) {
        // Handle ?XXXXl sequences
        if paramsString.hasPrefix("?") {
            let modeStr = String(paramsString.dropFirst())
            
            switch modeStr {
            case "1049":
                // Leave alternate screen buffer
                screen.leaveAlternateBuffer()
            case "1048":
                // Restore cursor (handled by ESC 8)
                screen.restoreCursor()
            case "1000", "1002", "1003":
                // Disable mouse tracking
                mouseReportingEnabled = false
            case "2004":
                // Disable bracketed paste
                bracketedPasteEnabled = false
            default:
                break
            }
        }
    }

    private func parseParams(_ raw: String) -> [Int] {
        if raw.isEmpty { return [] }
        return raw.split(separator: ";").map { Int($0) ?? 0 }
    }
}
