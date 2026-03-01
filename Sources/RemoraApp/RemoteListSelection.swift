import AppKit
import Foundation

struct RemoteListSelectionResult: Equatable {
    var selectedPaths: Set<String>
    var anchorPath: String?
}

enum RemoteListSelection {
    static func applyClick(
        currentSelection: Set<String>,
        anchorPath: String?,
        orderedPaths: [String],
        clickedPath: String,
        modifiers: NSEvent.ModifierFlags
    ) -> RemoteListSelectionResult {
        let usesCommand = modifiers.contains(.command)
        let usesShift = modifiers.contains(.shift)

        if usesShift {
            guard let anchorPath,
                  let anchorIndex = orderedPaths.firstIndex(of: anchorPath),
                  let clickedIndex = orderedPaths.firstIndex(of: clickedPath)
            else {
                return RemoteListSelectionResult(
                    selectedPaths: [clickedPath],
                    anchorPath: clickedPath
                )
            }

            let lower = min(anchorIndex, clickedIndex)
            let upper = max(anchorIndex, clickedIndex)
            let rangeSelection = Set(orderedPaths[lower...upper])
            return RemoteListSelectionResult(
                selectedPaths: rangeSelection,
                anchorPath: anchorPath
            )
        }

        if usesCommand {
            var updated = currentSelection
            if updated.contains(clickedPath) {
                updated.remove(clickedPath)
            } else {
                updated.insert(clickedPath)
            }
            return RemoteListSelectionResult(
                selectedPaths: updated,
                anchorPath: clickedPath
            )
        }

        return RemoteListSelectionResult(
            selectedPaths: [clickedPath],
            anchorPath: clickedPath
        )
    }
}
