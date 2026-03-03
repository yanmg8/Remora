import Foundation

public final class ANSIParser {
    // Terminal modes
    public var mouseReportingEnabled: Bool = false
    public var bracketedPasteEnabled: Bool = false

    // Callbacks for terminal queries
    public var onDSR: ((_ row: Int, _ col: Int) -> Void)?
    public var onDA: (() -> Void)?
    public var onCUU: (() -> Void)?  // Cursor up
    public var onCUD: (() -> Void)?  // Cursor down
    public var onCUF: (() -> Void)?  // Cursor forward
    public var onCUB: (() -> Void)?  // Cursor back
    
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
        case UInt8(ascii: "n"):
            // DSR - Device Status Report (CSI 6n)
            // Reports cursor position as ESC[row;colR
            if paramsString.isEmpty || paramsString == "5" {
                // DSR 5 = Status report (OK)
                // Not typically used, but we handle it
            } else if paramsString == "6" {
                // DSR 6 = Cursor position report
                // Callback will handle sending response
                onDSR?(screen.cursorRow + 1, screen.cursorColumn + 1)
            }
        case UInt8(ascii: "c"):
            // DA - Device Attributes (CSI c)
            // Response: ESC[?1;2c (VT100 with advanced video option)
            if paramsString.isEmpty || paramsString == "0" {
                onDA?()
            }
        case UInt8(ascii: "s"):
            // SCP - Save Cursor Position (alternative to ESC 7)
            screen.saveCursor()
            onCUU?()  // Notify (same as ESC 7)
        case UInt8(ascii: "u"):
            // RCP - Restore Cursor Position (alternative to ESC 8)
            screen.restoreCursor()
            onCUD?()  // Notify (same as ESC 8)
        default:
            // Unknown CSI sequence - swallow (do nothing, don't output garbage)
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
