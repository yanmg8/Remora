import AppKit
import Foundation
import RemoraCore

public struct TerminalInteractionState: Equatable, Sendable {
    public var isAlternateBufferActive: Bool
    public var isMouseReportingEnabled: Bool
    public var isApplicationCursorKeysEnabled: Bool

    public init(
        isAlternateBufferActive: Bool,
        isMouseReportingEnabled: Bool,
        isApplicationCursorKeysEnabled: Bool
    ) {
        self.isAlternateBufferActive = isAlternateBufferActive
        self.isMouseReportingEnabled = isMouseReportingEnabled
        self.isApplicationCursorKeysEnabled = isApplicationCursorKeysEnabled
    }

    public var isInteractiveTerminalMode: Bool {
        isAlternateBufferActive
    }
}

public struct TerminalShellInputSnapshot: Equatable, Sendable {
    public var logicalLineText: String
    public var cursorColumn: Int

    public init(logicalLineText: String, cursorColumn: Int) {
        self.logicalLineText = logicalLineText
        self.cursorColumn = cursorColumn
    }
}

public struct TerminalSelection: Equatable {
    // Buffer-space coordinates (absolute row across scrollback + visible lines).
    public var startRow: Int
    public var startColumn: Int
    public var endRow: Int
    public var endColumn: Int
    public var isColumnSelection: Bool

    public init(
        startRow: Int,
        startColumn: Int,
        endRow: Int,
        endColumn: Int,
        isColumnSelection: Bool = false
    ) {
        self.startRow = startRow
        self.startColumn = startColumn
        self.endRow = endRow
        self.endColumn = endColumn
        self.isColumnSelection = isColumnSelection
    }
}

public final class TerminalView: NSView, @preconcurrency NSTextInputClient {
    private struct PendingShellCursorClick {
        let targetRow: Int
        let targetColumn: Int
        let selectionAnchorRow: Int
        let selectionAnchorColumn: Int
    }

    public var onInput: (@Sendable (Data) -> Void)?
    public var onFocus: (() -> Void)?
    public var onResize: ((Int, Int) -> Void)?
    public var onOpenExternalURL: ((URL) -> Void)?
    public var onInteractionStateChange: ((TerminalInteractionState) -> Void)?
    public var onShellInputSnapshotChange: ((TerminalShellInputSnapshot?) -> Void)?
    /// Callback for terminal query responses (DSR, DA, etc) - injects response back to PTY
    public var onTerminalQueryResponse: ((Data) -> Void)? {
        didSet {
            // Wire up parser callbacks when this is set
            parser.onDSR = { [weak self] row, col in
                // Format: ESC [ row ; col R
                let response = "\u{001B}[\(row);\(col)R"
                self?.onTerminalQueryResponse?(Data(response.utf8))
            }
            parser.onDA = { [weak self] in
                // Format: ESC [ ? 1 ; 2 c (VT100 with advanced video)
                let response = "\u{001B}[?1;2c"
                self?.onTerminalQueryResponse?(Data(response.utf8))
            }
            parser.onKittyKeyboardQuery = { [weak self] flags in
                // Format: ESC [ ? <flags> u
                let response = "\u{001B}[?\(flags)u"
                self?.onTerminalQueryResponse?(Data(response.utf8))
            }
        }
    }
    public var isDisplayActive: Bool = true {
        didSet {
            guard isDisplayActive else { return }
            if !dirtyRows.isEmpty {
                needsDisplay = true
            }
        }
    }
    public var wordSeparators: CharacterSet = CharacterSet(charactersIn: " ()[]{}'\"`")
    public var scrollSensitivity: Double = 1.0
    public var fastScrollSensitivity: Double = 5.0
    public var scrollOnUserInput: Bool = true
    public var allowsKeyboardInput: Bool = true {
        didSet {
            defer {
                updateCaretBlinking()
                needsDisplay = true
            }
            guard !allowsKeyboardInput else { return }
            guard let window, window.firstResponder as AnyObject? === self else { return }
            window.makeFirstResponder(nil)
        }
    }
    public var prefersInitialFocusOnWindowAttach: Bool = true

    private let screenBuffer: ScreenBuffer
    private let parser = ANSIParser()
    private let ringBuffer = RingByteBuffer(capacity: 2 << 20)
    private let renderer = CoreTextTerminalRenderer()
    private let inputMapper = TerminalInputMapper()
    private let metrics = PerformanceMetrics()

    private var frameScheduler: FrameScheduler?
    private var dirtyRows: Set<Int> = []
    private var selection: TerminalSelection?
    private var flushSequence: UInt64 = 0
    private var accessibilityTextSnapshot = ""
    private var scrollbackOffset = 0
    private var markedText: NSAttributedString = .init(string: "")
    private var focusReportingEnabled = false
    private var bracketedPasteEnabled = false
    private var isSelectingWithMouse = false
    private var isMouseReportingDrag = false
    private var mouseReportingButtonCode: Int?
    private var pendingShellCursorClick: PendingShellCursorClick?
    private var scrollLineAccumulator: Double = 0
    private var caretBlinkTask: Task<Void, Never>?
    private var isCaretBlinkVisible = true
    private let caretBlinkClock = ContinuousClock()
    private let caretBlinkInterval: Duration = .milliseconds(550)
    private var caretBlinkSuppressedUntil: ContinuousClock.Instant?
    private var lastInteractionState = TerminalInteractionState(
        isAlternateBufferActive: false,
        isMouseReportingEnabled: false,
        isApplicationCursorKeysEnabled: false
    )

    private let flushScheduleLock = NSLock()
    nonisolated(unsafe) private var flushScheduled = false

    public init(rows: Int = 30, columns: Int = 120) {
        self.screenBuffer = ScreenBuffer(rows: rows, columns: columns)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.isOpaque = true
        configureAccessibility()
        setupScheduler()
        scheduleWelcomeText()
        updateAccessibilitySnapshot()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    public override func isAccessibilityElement() -> Bool {
        true
    }

    public override func accessibilityRole() -> NSAccessibility.Role? {
        .textArea
    }

    public override func accessibilityLabel() -> String? {
        "Terminal"
    }

    public override func accessibilityIdentifier() -> String {
        "terminal-view"
    }

    public override func accessibilityValue() -> Any? {
        accessibilityTextSnapshot
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateCaretBlinking()
        guard prefersInitialFocusOnWindowAttach else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    public override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        guard accepted else { return false }
        resetCaretBlink()
        updateCaretBlinking()
        needsDisplay = true
        onFocus?()
        if focusReportingEnabled {
            onInput?(Data("\u{001B}[I".utf8))
        }
        return true
    }

    public override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        guard accepted else { return false }
        updateCaretBlinking()
        needsDisplay = true
        if focusReportingEnabled {
            onInput?(Data("\u{001B}[O".utf8))
        }
        return true
    }

    deinit {
        frameScheduler?.stop()
        caretBlinkTask?.cancel()
    }

    public func feed(data: Data) {
        _ = ringBuffer.write(data)
        scheduleImmediateFlush()
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        screenBuffer.setViewportOffset(scrollbackOffset)
        renderer.draw(screen: screenBuffer, in: context, bounds: bounds, dirtyRows: [])
        if shouldDrawCaret {
            drawCursor(in: context)
        }
        drawSelection(in: context)
        updateAccessibilitySnapshot()

        dirtyRows.removeAll(keepingCapacity: true)
    }

    public override func keyDown(with event: NSEvent) {
        guard allowsKeyboardInput else { return }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            resetCaretBlink()
            copy(nil)
            return
        }

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "v" {
            resetCaretBlink()
            paste(nil)
            return
        }

        if let input = directTerminalControlInput(for: event) {
            registerCaretMovement()
            discardMarkedText()
            scrollToBottomOnUserInputIfNeeded()
            onInput?(input)
            return
        }

        if let legacyControl = inputMapper.mapLegacyControl(event: event) {
            resetCaretBlink()
            scrollToBottomOnUserInputIfNeeded()
            onInput?(legacyControl)
            return
        }

        if let input = inputMapper.mapKittyKeyDown(event: event) {
            resetCaretBlink()
            scrollToBottomOnUserInputIfNeeded()
            onInput?(input)
            return
        }

        if shouldSendRawControlInput(event) {
            resetCaretBlink()
            guard let input = inputMapper.map(event: event) else {
                super.keyDown(with: event)
                return
            }
            scrollToBottomOnUserInputIfNeeded()
            onInput?(input)
            return
        }

        resetCaretBlink()
        scrollToBottomOnUserInputIfNeeded()
        interpretKeyEvents([event])
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard allowsKeyboardInput else { return false }
        guard let input = keyEquivalentTerminalInput(for: event) else {
            return super.performKeyEquivalent(with: event)
        }
        registerCaretMovement()
        discardMarkedText()
        scrollToBottomOnUserInputIfNeeded()
        onInput?(input)
        return true
    }

    public override func keyUp(with event: NSEvent) {
        guard allowsKeyboardInput else { return }
        if let input = inputMapper.mapKeyUp(event: event) {
            onInput?(input)
            return
        }
        super.keyUp(with: event)
    }

    public func paste(_ sender: Any?) {
        resetCaretBlink()
        scrollToBottomOnUserInputIfNeeded()
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        if bracketedPasteEnabled {
            let wrapped = "\u{001B}[200~" + value + "\u{001B}[201~"
            onInput?(Data(wrapped.utf8))
            return
        }
        onInput?(Data(value.utf8))
    }

    @objc
    public func copy(_ sender: Any?) {
        screenBuffer.setViewportOffset(scrollbackOffset)
        guard let selectedText = selectedText(), !selectedText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)
    }

    public override func mouseDown(with event: NSEvent) {
        onFocus?()
        if allowsKeyboardInput {
            window?.makeFirstResponder(self)
        }
        discardMarkedText()

        screenBuffer.setViewportOffset(scrollbackOffset)
        let point = convert(event.locationInWindow, from: nil)
        let selectionLocation = bufferCellLocation(from: point)
        if event.modifierFlags.contains(.command), openHyperlink(atBufferRow: selectionLocation.row, column: selectionLocation.column) {
            isSelectingWithMouse = false
            return
        }
        if shouldRouteMouseEventToPTY(event) {
            sendMouseButtonEvent(buttonCode: 0, event: event, isRelease: false)
            isMouseReportingDrag = true
            mouseReportingButtonCode = 0
            isSelectingWithMouse = false
            selection = nil
            needsDisplay = true
            return
        }
        let isColumnSelection = event.modifierFlags.contains(.option)

        if event.clickCount >= 3 {
            selectLogicalLine(atBufferRow: selectionLocation.row)
            isSelectingWithMouse = false
            pendingShellCursorClick = nil
            needsDisplay = true
            return
        }

        if event.clickCount == 2 {
            selectWord(atBufferRow: selectionLocation.row, column: selectionLocation.column)
            isSelectingWithMouse = false
            pendingShellCursorClick = nil
            needsDisplay = true
            return
        }

        let shellLocation = bufferCaretStopLocation(from: point)
        if allowsKeyboardInput, shouldHandleShellCursorClick(event: event, location: shellLocation) {
            pendingShellCursorClick = PendingShellCursorClick(
                targetRow: shellLocation.row,
                targetColumn: shellLocation.column,
                selectionAnchorRow: selectionLocation.row,
                selectionAnchorColumn: selectionLocation.column
            )
            isSelectingWithMouse = false
            return
        }

        selection = TerminalSelection(
            startRow: selectionLocation.row,
            startColumn: selectionLocation.column,
            endRow: selectionLocation.row,
            endColumn: selectionLocation.column,
            isColumnSelection: isColumnSelection
        )
        isSelectingWithMouse = true
        needsDisplay = true
    }

    public override func scrollWheel(with event: NSEvent) {
        if shouldRouteMouseEventToPTY(event) {
            sendMouseWheelEvent(event)
            return
        }

        let sensitivity = event.modifierFlags.contains(.option) ? fastScrollSensitivity : scrollSensitivity
        let baseDelta = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY) / 8.0
            : Double(event.deltaY)
        let scaledDelta = baseDelta * max(0.1, sensitivity)
        guard scaledDelta != 0 else { return }

        scrollLineAccumulator += scaledDelta
        let step = Int(abs(scrollLineAccumulator))
        guard step > 0 else { return }

        let maxOffset = screenBuffer.maxViewportOffset()
        if scrollLineAccumulator > 0 {
            scrollbackOffset = min(maxOffset, scrollbackOffset + step)
            scrollLineAccumulator -= Double(step)
        } else {
            scrollbackOffset = max(0, scrollbackOffset - step)
            scrollLineAccumulator += Double(step)
        }
        screenBuffer.setViewportOffset(scrollbackOffset)
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        if isMouseReportingDrag {
            let baseCode = mouseReportingButtonCode ?? 0
            sendMouseButtonEvent(buttonCode: baseCode + 32, event: event, isRelease: false)
            return
        }

        if let pendingClick = pendingShellCursorClick {
            screenBuffer.setViewportOffset(scrollbackOffset)
            let point = convert(event.locationInWindow, from: nil)
            let location = bufferCellLocation(from: point)
            selection = TerminalSelection(
                startRow: pendingClick.selectionAnchorRow,
                startColumn: pendingClick.selectionAnchorColumn,
                endRow: location.row,
                endColumn: location.column,
                isColumnSelection: event.modifierFlags.contains(.option)
            )
            pendingShellCursorClick = nil
            isSelectingWithMouse = true
            needsDisplay = true
            return
        }

        guard isSelectingWithMouse, var current = selection else { return }
        screenBuffer.setViewportOffset(scrollbackOffset)
        let point = convert(event.locationInWindow, from: nil)
        let location = bufferCellLocation(from: point)
        current.endRow = location.row
        current.endColumn = location.column
        selection = current
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        if isMouseReportingDrag {
            sendMouseButtonEvent(buttonCode: 3, event: event, isRelease: true)
            isMouseReportingDrag = false
            mouseReportingButtonCode = nil
            return
        }

        if let pendingClick = pendingShellCursorClick {
            pendingShellCursorClick = nil
            if let input = shellCursorRepositionInput(
                targetBufferRow: pendingClick.targetRow,
                targetColumn: pendingClick.targetColumn
            ) {
                registerCaretMovement()
                scrollToBottomOnUserInputIfNeeded()
                onInput?(input)
                selection = nil
                needsDisplay = true
                return
            }
        }

        super.mouseUp(with: event)
        isSelectingWithMouse = false
    }

    public override func rightMouseDown(with event: NSEvent) {
        if shouldRouteMouseEventToPTY(event) {
            sendMouseButtonEvent(buttonCode: 2, event: event, isRelease: false)
            isMouseReportingDrag = true
            mouseReportingButtonCode = 2
            return
        }
        onFocus?()
        if allowsKeyboardInput {
            window?.makeFirstResponder(self)
        }
        discardMarkedText()
        screenBuffer.setViewportOffset(scrollbackOffset)
        let point = convert(event.locationInWindow, from: nil)
        let location = bufferCellLocation(from: point)
        selectWord(atBufferRow: location.row, column: location.column)
        isSelectingWithMouse = false
        needsDisplay = true
    }

    public override func rightMouseUp(with event: NSEvent) {
        if isMouseReportingDrag, mouseReportingButtonCode == 2 {
            sendMouseButtonEvent(buttonCode: 3, event: event, isRelease: true)
            isMouseReportingDrag = false
            mouseReportingButtonCode = nil
            return
        }
        super.rightMouseUp(with: event)
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        resizeBufferToBounds()
    }

    private func setupScheduler() {
        frameScheduler = FrameScheduler(frameIntervalMS: 16) { [weak self] in
            guard let self else { return }
            guard self.markFlushScheduled() else { return }
            DispatchQueue.main.async {
                defer {
                    self.clearFlushScheduled()
                }
                self.flushFrame()
            }
        }
        frameScheduler?.start()
    }

    private func scheduleImmediateFlush() {
        guard markFlushScheduled() else { return }
        DispatchQueue.main.async {
            defer {
                self.clearFlushScheduled()
            }
            self.flushFrame()
        }
    }

    private func scheduleWelcomeText() {
        let banner = "\u{001B}[32mRemora TerminalView ready\u{001B}[0m\r\n"
        feed(data: Data(banner.utf8))
    }

    private func flushFrame() {
        let start = ContinuousClock.now
        let chunk = ringBuffer.read(maxBytes: 64 * 1024)
        guard !chunk.isEmpty else { return }

        let cursorBeforeParse = (row: screenBuffer.cursorRow, column: screenBuffer.cursorColumn)
        parser.parse(chunk, into: screenBuffer)
        inputMapper.applicationCursorKeysEnabled = parser.applicationCursorKeysEnabled
        inputMapper.kittyKeyboardFlags = parser.kittyKeyboardFlags
        focusReportingEnabled = parser.focusReportingEnabled
        bracketedPasteEnabled = parser.bracketedPasteEnabled
        publishInteractionStateIfNeeded()
        let maxOffset = screenBuffer.maxViewportOffset()
        if scrollbackOffset > maxOffset {
            scrollbackOffset = maxOffset
        }
        screenBuffer.setViewportOffset(scrollbackOffset)
        let changedRows = screenBuffer.consumeDirtyRows()
        if !changedRows.isEmpty {
            dirtyRows.formUnion(changedRows)
            updateAccessibilitySnapshot()
        }
        let cursorAfterParse = (row: screenBuffer.cursorRow, column: screenBuffer.cursorColumn)
        if cursorBeforeParse != cursorAfterParse {
            registerCaretMovement()
        }
        onShellInputSnapshotChange?(shellInputSnapshot())

        let elapsed = start.duration(to: .now)
        flushSequence += 1
        let milliseconds = Self.durationToMilliseconds(elapsed)

        Task {
            await metrics.record(
                PerformanceSample(
                    frameDurationMS: milliseconds,
                    inputLatencyMS: 0,
                    bytesPerSecond: Double(chunk.count) * 60
                )
            )

            if flushSequence % 120 == 0 {
                await metrics.logSummary()
            }
        }

        if isDisplayActive, !dirtyRows.isEmpty, !screenBuffer.isSynchronizedUpdate {
            needsDisplay = true
        }
    }

    private func resizeBufferToBounds() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        flushPendingInputBeforeResize()

        let drawableWidth = max(bounds.width - renderer.horizontalInset * 2, renderer.cellWidth)
        let columns = max(Int(drawableWidth / renderer.cellWidth), 1)
        let rows = max(Int(bounds.height / renderer.lineHeight), 1)
        guard columns != screenBuffer.columns || rows != screenBuffer.rows else { return }
        screenBuffer.resize(rows: rows, columns: columns)
        let maxOffset = screenBuffer.maxViewportOffset()
        if scrollbackOffset > maxOffset {
            scrollbackOffset = maxOffset
        }
        screenBuffer.setViewportOffset(scrollbackOffset)
        onResize?(columns, rows)
        sanitizeDirtyRows()
        clampSelectionIfNeeded()
        dirtyRows.formUnion(screenBuffer.consumeDirtyRows())
        updateAccessibilitySnapshot()
        needsDisplay = true
    }

    private func flushPendingInputBeforeResize() {
        let pending = ringBuffer.drainAll()
        guard !pending.isEmpty else { return }

        let cursorBeforeParse = (row: screenBuffer.cursorRow, column: screenBuffer.cursorColumn)
        parser.parse(pending, into: screenBuffer)
        inputMapper.applicationCursorKeysEnabled = parser.applicationCursorKeysEnabled
        inputMapper.kittyKeyboardFlags = parser.kittyKeyboardFlags
        focusReportingEnabled = parser.focusReportingEnabled
        bracketedPasteEnabled = parser.bracketedPasteEnabled
        publishInteractionStateIfNeeded()
        dirtyRows.formUnion(screenBuffer.consumeDirtyRows())
        let cursorAfterParse = (row: screenBuffer.cursorRow, column: screenBuffer.cursorColumn)
        if cursorBeforeParse != cursorAfterParse {
            registerCaretMovement()
        }
    }

    private func drawCursor(in context: CGContext) {
        let cursorRect = caretRect()
        context.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        context.fill(cursorRect)
    }

    private func drawSelection(in context: CGContext) {
        guard let selection else { return }
        guard screenBuffer.rows > 0, screenBuffer.columns > 0 else { return }
        screenBuffer.setViewportOffset(scrollbackOffset)
        let ordered = orderedSelection(selection)
        let totalLineCount = screenBuffer.totalBufferLineCount()
        guard totalLineCount > 0 else { return }

        let minRow = min(max(0, ordered.startRow), totalLineCount - 1)
        let maxRow = min(max(0, ordered.endRow), totalLineCount - 1)
        guard minRow <= maxRow else { return }

        let viewportStart = screenBuffer.viewportStartBufferRow()
        let viewportEnd = viewportStart + screenBuffer.rows - 1
        let visibleStart = max(minRow, viewportStart)
        let visibleEnd = min(maxRow, viewportEnd)
        guard visibleStart <= visibleEnd else { return }

        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.25).cgColor)
        for bufferRow in visibleStart ... visibleEnd {
            let row = bufferRow - viewportStart
            let rowStartCol: Int
            let rowEndCol: Int
            if ordered.isColumnSelection {
                rowStartCol = ordered.startColumn
                rowEndCol = ordered.endColumn
            } else {
                rowStartCol = (bufferRow == minRow) ? ordered.startColumn : 0
                rowEndCol = (bufferRow == maxRow) ? ordered.endColumn : screenBuffer.columns - 1
            }
            let clampedMinCol = max(0, min(rowStartCol, screenBuffer.columns - 1))
            let clampedMaxCol = max(0, min(rowEndCol, screenBuffer.columns - 1))
            guard clampedMinCol <= clampedMaxCol else { continue }

            let rect = CGRect(
                x: renderer.horizontalInset + CGFloat(clampedMinCol) * renderer.cellWidth,
                y: bounds.height - CGFloat(row + 1) * renderer.lineHeight,
                width: CGFloat(clampedMaxCol - clampedMinCol + 1) * renderer.cellWidth,
                height: renderer.lineHeight
            )
            context.fill(rect)
        }
    }

    private func viewportCellLocation(from point: CGPoint) -> (row: Int, column: Int) {
        let contentX = max(point.x - renderer.horizontalInset, 0)
        let col = max(Int(contentX / renderer.cellWidth), 0)
        let row = max(Int((bounds.height - point.y) / renderer.lineHeight), 0)
        return (min(row, screenBuffer.rows - 1), min(col, screenBuffer.columns - 1))
    }

    private func viewportCaretStopLocation(from point: CGPoint) -> (row: Int, column: Int) {
        let contentX = max(point.x - renderer.horizontalInset, 0)
        let rawColumn = contentX / renderer.cellWidth
        let floorColumn = Int(rawColumn.rounded(.down))
        let columnOffset = rawColumn - CGFloat(floorColumn)
        let caretColumn = floorColumn + (columnOffset >= 0.5 ? 1 : 0)
        let row = max(Int((bounds.height - point.y) / renderer.lineHeight), 0)
        return (min(row, screenBuffer.rows - 1), min(max(0, caretColumn), screenBuffer.columns - 1))
    }

    private func bufferCellLocation(from point: CGPoint) -> (row: Int, column: Int) {
        let viewportLocation = viewportCellLocation(from: point)
        let bufferRow = screenBuffer.bufferRow(forViewportRow: viewportLocation.row)
        let normalizedColumn = normalizedColumn(atBufferRow: bufferRow, column: viewportLocation.column)
        return (bufferRow, normalizedColumn)
    }

    private func bufferCaretStopLocation(from point: CGPoint) -> (row: Int, column: Int) {
        let viewportLocation = viewportCaretStopLocation(from: point)
        let bufferRow = screenBuffer.bufferRow(forViewportRow: viewportLocation.row)
        let normalizedColumn = normalizedCaretStopColumn(atBufferRow: bufferRow, column: viewportLocation.column)
        return (bufferRow, normalizedColumn)
    }

    private func normalizedColumn(atBufferRow row: Int, column: Int) -> Int {
        let line = screenBuffer.line(atBufferRow: row)
        guard line.count > 0 else { return 0 }

        var normalized = min(max(0, column), line.count - 1)
        while normalized > 0, line[normalized].displayWidth == 0 {
            normalized -= 1
        }
        return normalized
    }

    private func normalizedCaretStopColumn(atBufferRow row: Int, column: Int) -> Int {
        let line = screenBuffer.line(atBufferRow: row)
        guard line.count > 0 else { return 0 }

        let clamped = min(max(0, column), line.count - 1)
        if line[clamped].displayWidth == 0 {
            return min(clamped + 1, line.count - 1)
        }
        return clamped
    }

    private func orderedSelection(_ selection: TerminalSelection) -> TerminalSelection {
        if selection.startRow < selection.endRow {
            return selection
        }
        if selection.startRow > selection.endRow {
            return TerminalSelection(
                startRow: selection.endRow,
                startColumn: selection.endColumn,
                endRow: selection.startRow,
                endColumn: selection.startColumn,
                isColumnSelection: selection.isColumnSelection
            )
        }
        if selection.startColumn <= selection.endColumn {
            return selection
        }
        return TerminalSelection(
            startRow: selection.endRow,
            startColumn: selection.endColumn,
            endRow: selection.startRow,
            endColumn: selection.startColumn,
            isColumnSelection: selection.isColumnSelection
        )
    }

    private enum WordClass {
        case whitespace
        case word
        case symbol
    }

    private func selectWord(atBufferRow row: Int, column: Int) {
        let line = screenBuffer.line(atBufferRow: row)
        guard line.count > 0 else { return }

        let seedColumn = normalizedColumn(atBufferRow: row, column: column)
        let seedClass = wordClass(in: line, at: seedColumn)
        var start = seedColumn
        var end = seedColumn

        while start > 0, wordClass(in: line, at: start - 1) == seedClass {
            start -= 1
        }
        while end + 1 < line.count, wordClass(in: line, at: end + 1) == seedClass {
            end += 1
        }

        selection = TerminalSelection(
            startRow: row,
            startColumn: start,
            endRow: row,
            endColumn: end,
            isColumnSelection: false
        )
    }

    private func selectLogicalLine(atBufferRow row: Int) {
        let logicalRange = screenBuffer.wrappedLogicalLineRange(containingBufferRow: row)
        selection = TerminalSelection(
            startRow: logicalRange.lowerBound,
            startColumn: 0,
            endRow: logicalRange.upperBound,
            endColumn: max(0, screenBuffer.columns - 1),
            isColumnSelection: false
        )
    }

    private func wordClass(in line: TerminalLine, at column: Int) -> WordClass {
        guard column >= 0, column < line.count else { return .whitespace }

        var targetColumn = column
        while targetColumn > 0, line[targetColumn].displayWidth == 0 {
            targetColumn -= 1
        }

        let character = line[targetColumn].character
        if character.isWhitespace {
            return .whitespace
        }
        return isWordCharacter(character) ? .word : .symbol
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return false
            }
            if wordSeparators.contains(scalar) {
                return false
            }
        }
        return true
    }

    private static func durationToMilliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private var shouldDrawCaret: Bool {
        guard screenBuffer.isCursorVisible else { return false }
        guard scrollbackOffset == 0 else { return false }
        guard allowsKeyboardInput else { return false }
        guard isCaretBlinkVisible else { return false }
        return window?.firstResponder as AnyObject? === self
    }

    private func caretRect() -> CGRect {
        let rowY = bounds.height - CGFloat(screenBuffer.cursorRow + 1) * renderer.lineHeight
        let textHeight = min(renderer.contentHeightForCaret, renderer.lineHeight - 2)
        let verticalPadding = max(0, renderer.lineHeight - textHeight)
        let width = min(renderer.cellWidth, max(2, round(renderer.cellWidth * 0.18)))
        let caretY = min(
            rowY + verticalPadding,
            rowY + floor(verticalPadding * 0.5) + 2
        )
        return CGRect(
            x: renderer.horizontalInset + CGFloat(screenBuffer.cursorColumn) * renderer.cellWidth,
            y: caretY,
            width: width,
            height: textHeight
        )
    }

    private func updateCaretBlinking() {
        guard window?.firstResponder as AnyObject? === self, allowsKeyboardInput else {
            caretBlinkTask?.cancel()
            caretBlinkTask = nil
            isCaretBlinkVisible = true
            caretBlinkSuppressedUntil = nil
            return
        }
        guard caretBlinkTask == nil else { return }

        caretBlinkTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: self.caretBlinkInterval)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.processCaretBlinkTick(now: self.caretBlinkClock.now, requireFocusedResponder: true)
                }
            }
        }
    }

    private func resetCaretBlink() {
        isCaretBlinkVisible = true
        caretBlinkSuppressedUntil = nil
        updateCaretBlinking()
        needsDisplay = true
    }

    private func registerCaretMovement() {
        isCaretBlinkVisible = true
        caretBlinkSuppressedUntil = caretBlinkClock.now.advanced(by: caretBlinkInterval)
        updateCaretBlinking()
        needsDisplay = true
    }

    private func processCaretBlinkTick(
        now: ContinuousClock.Instant,
        requireFocusedResponder: Bool
    ) {
        if requireFocusedResponder {
            guard window?.firstResponder as AnyObject? === self, allowsKeyboardInput else { return }
        }
        if let suppressedUntil = caretBlinkSuppressedUntil {
            if now < suppressedUntil {
                isCaretBlinkVisible = true
                needsDisplay = true
                return
            }
            caretBlinkSuppressedUntil = nil
        }
        isCaretBlinkVisible.toggle()
        needsDisplay = true
    }

    private func sanitizeDirtyRows() {
        let validRows = Set(screenBuffer.validRowRange())
        dirtyRows = dirtyRows.intersection(validRows)
    }

    private func clampSelectionIfNeeded() {
        guard var selection else { return }
        guard screenBuffer.columns > 0 else {
            self.selection = nil
            return
        }

        let totalLineCount = screenBuffer.totalBufferLineCount()
        guard totalLineCount > 0 else {
            self.selection = nil
            return
        }

        let maxRow = totalLineCount - 1
        let maxCol = screenBuffer.columns - 1

        selection.startRow = min(max(selection.startRow, 0), maxRow)
        selection.endRow = min(max(selection.endRow, 0), maxRow)
        selection.startColumn = min(max(selection.startColumn, 0), maxCol)
        selection.endColumn = min(max(selection.endColumn, 0), maxCol)
        self.selection = selection
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.textArea)
        setAccessibilityLabel("Terminal")
        setAccessibilityIdentifier("terminal-view")
        setAccessibilityHelp("")
    }

    private func updateAccessibilitySnapshot() {
        let startRow = max(0, screenBuffer.rows - 20)
        var rows: [String] = []
        rows.reserveCapacity(screenBuffer.rows - startRow)

        for row in startRow ..< screenBuffer.rows {
            let line = screenBuffer.line(at: row)
            var text = String(line.cells.filter { $0.displayWidth != 0 }.map(\.character))
            while text.last == " " {
                text.removeLast()
            }
            if !text.isEmpty {
                rows.append(text)
            }
        }

        let snapshot = rows.joined(separator: "\n")
        guard snapshot != accessibilityTextSnapshot else { return }

        accessibilityTextSnapshot = snapshot
        setAccessibilityHelp(snapshot)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    private func selectedText() -> String? {
        guard let selection else { return nil }
        guard screenBuffer.columns > 0 else { return nil }
        let totalLineCount = screenBuffer.totalBufferLineCount()
        guard totalLineCount > 0 else { return nil }

        let ordered = orderedSelection(selection)
        let minRow = min(max(ordered.startRow, 0), totalLineCount - 1)
        let maxRow = min(max(ordered.endRow, 0), totalLineCount - 1)
        guard minRow <= maxRow else { return nil }

        if ordered.isColumnSelection {
            var rows: [String] = []
            rows.reserveCapacity(maxRow - minRow + 1)
            for row in minRow ... maxRow {
                let line = screenBuffer.line(atBufferRow: row)
                guard line.count > 0 else { continue }
                let clampedStartCol = min(max(ordered.startColumn, 0), line.count - 1)
                let clampedEndCol = min(max(ordered.endColumn, 0), line.count - 1)
                guard clampedStartCol <= clampedEndCol else { continue }
                let characters = (clampedStartCol ... clampedEndCol)
                    .compactMap { line[$0].displayWidth == 0 ? nil : line[$0].character }
                rows.append(String(characters))
            }
            return rows.joined(separator: "\n")
        }

        var output = ""
        for row in minRow ... maxRow {
            let line = screenBuffer.line(atBufferRow: row)
            guard line.count > 0 else { continue }

            let startCol = row == minRow ? ordered.startColumn : 0
            let endCol = row == maxRow ? ordered.endColumn : (line.count - 1)
            let clampedStartCol = min(max(0, startCol), line.count - 1)
            let clampedEndCol = min(max(0, endCol), line.count - 1)
            guard clampedStartCol <= clampedEndCol else { continue }

            let characters = (clampedStartCol ... clampedEndCol)
                .compactMap { line[$0].displayWidth == 0 ? nil : line[$0].character }
            var rowText = String(characters)
            while rowText.last == " ", !screenBuffer.isBufferLineWrapped(row + 1) {
                rowText.removeLast()
            }
            output.append(rowText)
            if row < maxRow, !screenBuffer.isBufferLineWrapped(row + 1) {
                output.append("\n")
            }
        }

        return output
    }

    public func shellInputSnapshot() -> TerminalShellInputSnapshot? {
        guard scrollbackOffset == 0 else { return nil }
        guard !screenBuffer.isAlternateBuffer else { return nil }

        screenBuffer.setViewportOffset(scrollbackOffset)
        let currentBufferRow = screenBuffer.viewportStartBufferRow() + screenBuffer.cursorRow
        let logicalRange = screenBuffer.wrappedLogicalLineRange(containingBufferRow: currentBufferRow)

        var renderedText = ""
        for row in logicalRange {
            let line = screenBuffer.line(atBufferRow: row)
            let rowText = String(
                line.cells.compactMap { cell in
                    cell.displayWidth == 0 ? nil : cell.character
                }
            )
            renderedText.append(rowText)
        }

        let cursorColumn = (currentBufferRow - logicalRange.lowerBound) * screenBuffer.columns + screenBuffer.cursorColumn
        let trimmedLength = max(cursorColumn, renderedText.lastIndex(where: { $0 != " " }).map {
            renderedText.distance(from: renderedText.startIndex, to: renderedText.index(after: $0))
        } ?? 0)
        let logicalLineText = String(renderedText.prefix(trimmedLength))
        return TerminalShellInputSnapshot(
            logicalLineText: logicalLineText,
            cursorColumn: min(cursorColumn, logicalLineText.count)
        )
    }

    private func scrollToBottom() {
        guard scrollbackOffset != 0 else { return }
        scrollbackOffset = 0
        scrollLineAccumulator = 0
        screenBuffer.setViewportOffset(0)
        needsDisplay = true
    }

    private func scrollToBottomOnUserInputIfNeeded() {
        guard scrollOnUserInput else { return }
        scrollToBottom()
    }

    private func isShellLineNavigationShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        return event.keyCode == 123 || event.keyCode == 124
    }

    private func shouldHandleDirectTerminalControlKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 51, 115, 116, 117, 119, 121, 123, 124, 125, 126:
            return true
        default:
            return isShellLineNavigationShortcut(event)
        }
    }

    private func directTerminalControlInput(for event: NSEvent) -> Data? {
        guard shouldHandleDirectTerminalControlKey(event) else { return nil }
        return inputMapper.map(event: event)
    }

    private func keyEquivalentTerminalInput(for event: NSEvent) -> Data? {
        guard event.type == .keyDown else { return nil }
        guard isShellLineNavigationShortcut(event) else { return nil }
        return inputMapper.map(event: event)
    }

    private func shouldHandleShellCursorClick(
        event: NSEvent,
        location: (row: Int, column: Int)
    ) -> Bool {
        guard event.clickCount == 1 else { return false }
        guard !event.modifierFlags.contains(.option) else { return false }
        guard !shouldRouteMouseEventToPTY(event) else { return false }
        return shellCursorRepositionInput(targetBufferRow: location.row, targetColumn: location.column) != nil
    }

    private func shellCursorRepositionInput(targetBufferRow: Int, targetColumn: Int) -> Data? {
        guard scrollbackOffset == 0 else { return nil }
        guard !parser.mouseReportingEnabled else { return nil }
        guard !screenBuffer.isAlternateBuffer else { return nil }

        screenBuffer.setViewportOffset(scrollbackOffset)
        let currentBufferRow = screenBuffer.viewportStartBufferRow() + screenBuffer.cursorRow
        let logicalRange = screenBuffer.wrappedLogicalLineRange(containingBufferRow: currentBufferRow)
        guard logicalRange.contains(targetBufferRow) else { return nil }

        let normalizedTargetColumn = normalizedColumn(atBufferRow: targetBufferRow, column: targetColumn)
        let currentLogicalColumn = (currentBufferRow - logicalRange.lowerBound) * screenBuffer.columns + screenBuffer.cursorColumn
        let targetLogicalColumn = (targetBufferRow - logicalRange.lowerBound) * screenBuffer.columns + normalizedTargetColumn
        let delta = targetLogicalColumn - currentLogicalColumn
        guard delta != 0 else { return nil }

        let direction: NSDirectionalRectEdge = delta > 0 ? .trailing : .leading
        guard let unit = inputMapper.cursorMoveSequence(direction: direction) else { return nil }

        var payload = Data(capacity: unit.count * abs(delta))
        for _ in 0 ..< abs(delta) {
            payload.append(unit)
        }
        return payload
    }

    private func shouldRouteMouseEventToPTY(_ event: NSEvent) -> Bool {
        parser.mouseReportingEnabled && !event.modifierFlags.contains(.option)
    }

    private func sendMouseWheelEvent(_ event: NSEvent) {
        let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
        guard deltaY != 0 else { return }
        let steps = max(Int(abs(deltaY) / 8), 1)
        let code = deltaY > 0 ? 64 : 65
        for _ in 0 ..< steps {
            sendMouseButtonEvent(buttonCode: code, event: event, isRelease: false)
        }
    }

    private func sendMouseButtonEvent(buttonCode: Int, event: NSEvent, isRelease: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let location = viewportCellLocation(from: point)
        guard let payload = mouseReportPayload(
            buttonCode: buttonCode,
            row: location.row,
            column: location.column,
            isRelease: isRelease,
            useSGR: parser.sgrMouseModeEnabled
        ) else { return }
        onInput?(payload)
    }

    func mouseReportPayload(
        buttonCode: Int,
        row: Int,
        column: Int,
        isRelease: Bool,
        useSGR: Bool
    ) -> Data? {
        let clampedRow = min(max(0, row), max(0, screenBuffer.rows - 1))
        let clampedCol = min(max(0, column), max(0, screenBuffer.columns - 1))
        let oneBasedRow = clampedRow + 1
        let oneBasedCol = clampedCol + 1

        if useSGR {
            let final = isRelease ? "m" : "M"
            let sequence = "\u{001B}[<\(buttonCode);\(oneBasedCol);\(oneBasedRow)\(final)"
            return Data(sequence.utf8)
        }

        let cb = buttonCode + 32
        let cx = oneBasedCol + 32
        let cy = oneBasedRow + 32
        guard cb <= 255, cx <= 255, cy <= 255 else { return nil }
        return Data([0x1B, 0x5B, 0x4D, UInt8(cb), UInt8(cx), UInt8(cy)])
    }

    private func openHyperlink(atBufferRow row: Int, column: Int) -> Bool {
        let line = screenBuffer.line(atBufferRow: row)
        guard line.count > 0 else { return false }

        let normalized = normalizedColumn(atBufferRow: row, column: column)
        guard normalized < line.count else { return false }
        let hyperlink = line[normalized].hyperlink
            ?? ((line[normalized].displayWidth == 0 && normalized > 0) ? line[normalized - 1].hyperlink : nil)
        guard let hyperlink else { return false }
        guard let safeURL = safeExternalURL(from: hyperlink) else { return false }

        if let onOpenExternalURL {
            onOpenExternalURL(safeURL)
        } else {
            NSWorkspace.shared.open(safeURL)
        }
        return true
    }

    func safeExternalURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              Self.allowedExternalURLSchemes.contains(scheme),
              let url = components.url else {
            return nil
        }
        return url
    }

    private static let allowedExternalURLSchemes: Set<String> = ["http", "https", "mailto", "ssh", "ftp", "sftp"]

    nonisolated private func markFlushScheduled() -> Bool {
        flushScheduleLock.lock()
        defer { flushScheduleLock.unlock() }
        if flushScheduled {
            return false
        }
        flushScheduled = true
        return true
    }

    nonisolated private func clearFlushScheduled() {
        flushScheduleLock.lock()
        flushScheduled = false
        flushScheduleLock.unlock()
    }

    private func shouldSendRawControlInput(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if modifiers.contains(.command) {
            return false
        }
        return modifiers.contains(.control)
    }

    private func sendInputString(_ value: String) {
        guard !value.isEmpty else { return }
        resetCaretBlink()
        onInput?(Data(value.utf8))
    }

    private func plainString(from value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        return String(describing: value)
    }

    private func discardMarkedText() {
        guard hasMarkedText() || inputContext != nil else { return }
        markedText = NSAttributedString(string: "")
        inputContext?.discardMarkedText()
        inputContext?.invalidateCharacterCoordinates()
    }

    private func publishInteractionStateIfNeeded() {
        let state = TerminalInteractionState(
            isAlternateBufferActive: screenBuffer.isAlternateBuffer,
            isMouseReportingEnabled: parser.mouseReportingEnabled,
            isApplicationCursorKeysEnabled: parser.applicationCursorKeysEnabled
        )
        guard state != lastInteractionState else { return }
        lastInteractionState = state
        onInteractionStateChange?(state)
    }

    // MARK: - NSTextInputClient

    public func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    public func markedRange() -> NSRange {
        hasMarkedText() ? NSRange(location: 0, length: markedText.length) : NSRange(location: NSNotFound, length: 0)
    }

    public func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        resetCaretBlink()
        if let attributed = string as? NSAttributedString {
            markedText = attributed
        } else if let plain = string as? String {
            markedText = NSAttributedString(string: plain)
        } else {
            markedText = NSAttributedString(string: String(describing: string))
        }
    }

    public func unmarkText() {
        markedText = NSAttributedString(string: "")
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    public func insertText(_ string: Any, replacementRange: NSRange) {
        markedText = NSAttributedString(string: "")
        resetCaretBlink()
        scrollToBottomOnUserInputIfNeeded()
        sendInputString(plainString(from: string))
    }

    public override func insertText(_ insertString: Any) {
        insertText(insertString, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    public override func doCommand(by selector: Selector) {
        if let input = inputMapper.map(command: selector) {
            registerCaretMovement()
            scrollToBottomOnUserInputIfNeeded()
            onInput?(input)
            return
        }
        super.doCommand(by: selector)
    }

    public func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        let rectInWindow = convert(caretRect(), to: nil)
        guard let window else { return .zero }
        return window.convertToScreen(rectInWindow)
    }

    func flushPendingOutputForTesting() {
        flushPendingInputBeforeResize()
    }

    func cursorBufferPositionForTesting() -> (row: Int, column: Int) {
        screenBuffer.setViewportOffset(scrollbackOffset)
        return (
            screenBuffer.viewportStartBufferRow() + screenBuffer.cursorRow,
            screenBuffer.cursorColumn
        )
    }

    func shellCursorRepositionInputForTesting(targetBufferRow: Int, targetColumn: Int) -> Data? {
        shellCursorRepositionInput(targetBufferRow: targetBufferRow, targetColumn: targetColumn)
    }

    func isCaretBlinkVisibleForTesting() -> Bool {
        isCaretBlinkVisible
    }

    func registerCaretMovementForTesting() {
        isCaretBlinkVisible = true
        caretBlinkSuppressedUntil = caretBlinkClock.now.advanced(by: caretBlinkInterval)
    }

    func advanceCaretBlinkForTesting() {
        isCaretBlinkVisible.toggle()
    }

    func processCaretBlinkTickRelativeToSuppressionDeadlineForTesting(_ offset: Duration) {
        guard let suppressedUntil = caretBlinkSuppressedUntil else {
            fatalError("Expected active caret blink suppression window")
        }
        processCaretBlinkTick(
            now: suppressedUntil.advanced(by: offset),
            requireFocusedResponder: false
        )
    }

    func pointForBufferCellForTesting(row: Int, column: Int) -> CGPoint {
        screenBuffer.setViewportOffset(scrollbackOffset)
        let viewportRow = row - screenBuffer.viewportStartBufferRow()
        return CGPoint(
            x: renderer.horizontalInset + (CGFloat(column) + 0.5) * renderer.cellWidth,
            y: bounds.height - (CGFloat(viewportRow) + 0.5) * renderer.lineHeight
        )
    }
}
