import AppKit
import Foundation

public final class GlyphCache {
    private struct Key: Hashable {
        var character: Character
        var fontName: String
        var fontSize: CGFloat
        var bold: Bool
        var underline: Bool
    }

    private var storage: [Key: NSAttributedString] = [:]

    public init() {}

    public func attributedGlyph(
        for cell: TerminalCell,
        font: NSFont,
        foreground: NSColor,
        background: NSColor
    ) -> NSAttributedString {
        let key = Key(
            character: cell.character,
            fontName: font.fontName,
            fontSize: font.pointSize,
            bold: cell.attributes.bold,
            underline: cell.attributes.underline
        )

        if let cached = storage[key] {
            return cached
        }

        let resolvedFont: NSFont = {
            guard cell.attributes.bold else { return font }
            return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: resolvedFont,
            .foregroundColor: foreground,
            .backgroundColor: background,
            .kern: 0,
            .ligature: 0,
            .underlineStyle: cell.attributes.underline ? NSUnderlineStyle.single.rawValue : 0,
        ]
        let value = NSAttributedString(string: String(cell.character), attributes: attrs)
        storage[key] = value
        return value
    }

    public func clear() {
        storage.removeAll(keepingCapacity: true)
    }
}
