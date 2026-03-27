import Foundation

enum ByteSizeFormatter {
    private static let unitThreshold = 1024.0
    private static let units = ["KB", "MB", "GB", "TB", "PB", "EB"]

    static func format(_ bytes: Int64) -> String {
        let safeBytes = max(bytes, 0)
        if safeBytes < Int64(unitThreshold) {
            return "\(safeBytes)B"
        }

        var value = Double(safeBytes)
        var unitIndex = -1
        while value >= unitThreshold, unitIndex + 1 < units.count {
            value /= unitThreshold
            unitIndex += 1
        }

        let displayed = roundedString(value)
        return "\(displayed)\(units[max(unitIndex, 0)])"
    }

    static func formatRate(_ bytesPerSecond: Int64) -> String {
        "\(format(bytesPerSecond))/s"
    }

    private static func roundedString(_ value: Double) -> String {
        let roundedToSingleDecimal = (value * 10).rounded() / 10
        if abs(roundedToSingleDecimal.rounded() - roundedToSingleDecimal) < 0.000_1 {
            return String(format: "%.0f", roundedToSingleDecimal)
        }
        return String(format: "%.1f", roundedToSingleDecimal)
    }
}
