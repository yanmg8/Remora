import Foundation

public enum TerminalColor: Equatable, Hashable, Sendable {
    case `default`
    case indexed(UInt8)
    case trueColor(UInt8, UInt8, UInt8)
}

public struct TerminalAttributes: Equatable, Hashable, Sendable {
    public var foreground: TerminalColor
    public var background: TerminalColor
    public var bold: Bool
    public var underline: Bool

    public init(
        foreground: TerminalColor = .default,
        background: TerminalColor = .default,
        bold: Bool = false,
        underline: Bool = false
    ) {
        self.foreground = foreground
        self.background = background
        self.bold = bold
        self.underline = underline
    }

    public static let `default` = TerminalAttributes()
}
