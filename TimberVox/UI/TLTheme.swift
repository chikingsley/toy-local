import SwiftUI

extension Color {
  init(lightHex: UInt32, darkHex: UInt32) {
    self.init(
      nsColor: NSColor(name: nil) { appearance in
        let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkHex : lightHex
        return NSColor(
          red: CGFloat((hex >> 16) & 0xFF) / 255,
          green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255,
          alpha: 1
        )
      }
    )
  }

  init(hex: UInt32) {
    self.init(lightHex: hex, darkHex: hex)
  }
}

enum Shadcn {
  static let neutral50: UInt32 = 0xFAFAFA
  static let neutral100: UInt32 = 0xF5F5F5
  static let neutral200: UInt32 = 0xE5E5E5
  static let neutral300: UInt32 = 0xD4D4D4
  static let neutral400: UInt32 = 0xA3A3A3
  static let neutral500: UInt32 = 0x737373
  static let neutral600: UInt32 = 0x525252
  static let neutral700: UInt32 = 0x404040
  static let neutral800: UInt32 = 0x262626
  static let neutral900: UInt32 = 0x171717
  static let neutral950: UInt32 = 0x0A0A0A
  static let blue500: UInt32 = 0x3B82F6
  static let blue600: UInt32 = 0x2563EB
  static let green400: UInt32 = 0x4ADE80
  static let green500: UInt32 = 0x22C55E
  static let red500: UInt32 = 0xEF4444
  static let orange400: UInt32 = 0xFB923C
  static let orange500: UInt32 = 0xF97316
  static let violet500: UInt32 = 0x8B5CF6
}

enum TLTheme {
  static let sidebarWidth: CGFloat = 210
  static let railWidth: CGFloat = 56
  static let trafficLightClearance: CGFloat = 72
  static let headerHeight: CGFloat = 48
  static let cardRadius: CGFloat = 10
  static let chipRadius: CGFloat = 4
  static let fieldRadius: CGFloat = 7

  static let windowBackground = Color(lightHex: Shadcn.neutral100, darkHex: Shadcn.neutral900)
  static let cardSurface = Color(lightHex: Shadcn.neutral50, darkHex: Shadcn.neutral800)
  static let chipSurface = Color(lightHex: Shadcn.neutral200, darkHex: Shadcn.neutral700)
  static let fieldSurface = Color(lightHex: Shadcn.neutral200, darkHex: Shadcn.neutral700)
  static let hairline = Color(lightHex: Shadcn.neutral200, darkHex: Shadcn.neutral700)
  static let selectionFill = Color(lightHex: Shadcn.neutral50, darkHex: Shadcn.neutral700)
  static let hoverFill = Color(lightHex: Shadcn.neutral200, darkHex: Shadcn.neutral800)
  static let borderStroke = Color(lightHex: Shadcn.neutral200, darkHex: Shadcn.neutral700)
  static let popoverSurface = Color(lightHex: Shadcn.neutral50, darkHex: Shadcn.neutral800)
  static let tooltipSurface = Color(lightHex: Shadcn.neutral50, darkHex: Shadcn.neutral950)
  static let accentBlue = Color(hex: Shadcn.blue500)
  static let accentGreen = Color(hex: Shadcn.green400)
  static let destructive = Color(hex: Shadcn.red500)
}
