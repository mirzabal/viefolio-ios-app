import SwiftUI
import UIKit

// MARK: - Viefolio palette (matches viefolio.com)
// #013e37 brand · #fdfbf3 cream · #ffefb3 butter

extension ShapeStyle where Self == Color {
    /// #013e37 — primary brand green.
    static var brand: Color { Color(hex: 0x013E37) }
    /// #ffefb3 — warm highlight.
    static var butter: Color { Color(hex: 0xFFEFB3) }
    /// Mid-tone green for text and gradients where #013e37 is too heavy.
    static var brandSoft: Color { Color(light: 0x2E7D6F, dark: 0x6FBFAF) }

    /// Page background: cream in light, deep green in dark.
    static var canvas: Color { Color(light: 0xFDFBF3, dark: 0x01201C) }
    /// Cards / rows on top of `canvas`.
    static var surface: Color { Color(light: 0xFFFFFF, dark: 0x022F2A) }
    /// Subtle fills (chips, tracks, placeholders).
    static var subtle: Color { Color(light: 0xF1EEE1, dark: 0x0A3A33) }
    /// Hairlines.
    static var hairline: Color { Color(light: 0xE3DECB, dark: 0x0F4640) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Color(hex: dark))
            : UIColor(Color(hex: light)) })
    }
}

extension View {
    /// Cream page background behind a List/Form/ScrollView.
    func viefolioBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.canvas)
    }
}
