import AppKit
import CoreText
import Foundation

public final class CoreTextTerminalRenderer {
    public var font: NSFont {
        didSet {
            recalculateMetrics()
            glyphCache.clear()
        }
    }

    public private(set) var cellWidth: CGFloat = 8
    public private(set) var lineHeight: CGFloat = 16
    public var horizontalInset: CGFloat = 10

    private let glyphCache = GlyphCache()

    public init(font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)) {
        self.font = font
        recalculateMetrics()
    }

    public func draw(
        screen: ScreenBuffer,
        in context: CGContext,
        bounds: CGRect,
        dirtyRows: Set<Int>
    ) {
        let validRows = Set(screen.validRowRange())
        let rows = dirtyRows.isEmpty ? validRows : dirtyRows.intersection(validRows)
        if dirtyRows.isEmpty {
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)
        }
        for row in rows.sorted() {
            drawRow(row, screen: screen, context: context, bounds: bounds)
        }
    }

    public func color(for terminalColor: TerminalColor, isBackground: Bool) -> NSColor {
        switch terminalColor {
        case .default:
            return isBackground ? NSColor.black : NSColor(calibratedWhite: 0.9, alpha: 1)
        case .indexed(let idx):
            return palette[Int(idx) % palette.count]
        }
    }

    private func drawRow(_ row: Int, screen: ScreenBuffer, context: CGContext, bounds: CGRect) {
        guard screen.validRowRange().contains(row) else { return }
        let line = screen.line(at: row)
        let rowY = bounds.height - CGFloat(row + 1) * lineHeight
        let baselineY = rowY + 2

        for col in 0 ..< line.count {
            let cell = line[col]
            let x = horizontalInset + CGFloat(col) * cellWidth
            let fg = color(for: cell.attributes.foreground, isBackground: false)
            let bg = color(for: cell.attributes.background, isBackground: true)

            context.setFillColor(bg.cgColor)
            context.fill(CGRect(x: x, y: rowY, width: cellWidth, height: lineHeight))

            if cell.character == " " {
                continue
            }

            let glyph = glyphCache.attributedGlyph(
                for: cell,
                font: font,
                foreground: fg,
                background: bg
            )
            glyph.draw(at: CGPoint(x: x, y: baselineY))
        }
    }

    private func recalculateMetrics() {
        let sample = "W" as NSString
        let size = sample.size(withAttributes: [.font: font])
        cellWidth = ceil(size.width)
        lineHeight = ceil(size.height + 2)
    }

    private let palette: [NSColor] = [
        .black,
        .systemRed,
        .systemGreen,
        .systemYellow,
        .systemBlue,
        .systemPurple,
        .systemTeal,
        .white,
    ]
}
