import SwiftUI

enum NotchTheme {
    static let panelTint = Color(red: 0.035, green: 0.045, blue: 0.065).opacity(0.48)
    static let raised = Color.white.opacity(0.095)
    static let text = Color.white.opacity(0.96)
    static let secondary = Color.white.opacity(0.62)
    static let separator = Color.white.opacity(0.13)
    static let glassEdge = Color.white.opacity(0.20)
    static let glassHighlight = Color.white.opacity(0.08)
    static let telegram = Color(red: 0.18, green: 0.64, blue: 0.94)

    static func accent(_ accent: ChatAccent) -> Color {
        switch accent {
        case .cyan: Color(red: 0.18, green: 0.64, blue: 0.94)
        case .coral: Color(red: 0.96, green: 0.43, blue: 0.35)
        case .violet: Color(red: 0.60, green: 0.48, blue: 0.94)
        case .mint: Color(red: 0.25, green: 0.76, blue: 0.62)
        case .amber: Color(red: 0.94, green: 0.67, blue: 0.27)
        }
    }
}

