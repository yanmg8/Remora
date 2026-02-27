import Foundation

public struct TerminalCell: Equatable, Hashable, Sendable {
    public var character: Character
    public var attributes: TerminalAttributes

    public init(character: Character = " ", attributes: TerminalAttributes = .default) {
        self.character = character
        self.attributes = attributes
    }
}
