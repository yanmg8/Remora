import Foundation

public struct TerminalLine: Equatable, Sendable {
    public private(set) var cells: [TerminalCell]

    public init(columns: Int, attributes: TerminalAttributes = .default) {
        self.cells = Array(repeating: TerminalCell(character: " ", attributes: attributes), count: max(1, columns))
    }

    public mutating func resize(columns: Int, fill attributes: TerminalAttributes = .default) {
        let target = max(1, columns)
        if cells.count == target { return }

        if cells.count < target {
            cells.append(contentsOf: Array(repeating: TerminalCell(character: " ", attributes: attributes), count: target - cells.count))
        } else {
            cells.removeLast(cells.count - target)
        }
    }

    public subscript(_ index: Int) -> TerminalCell {
        get { cells[index] }
        set { cells[index] = newValue }
    }

    public var count: Int { cells.count }
}
