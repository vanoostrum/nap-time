import Core
import SwiftUI
import UIKit

// Shared by the app, the widget extension, and `NapTimeUITests`, so the sleep timer looks the same in all three.

/// The colours and fonts of style B "Storybook", from `design/gallery.css`.
enum Theme {
  static let daySkyTop = Color(hex: 0x6FBEFF)
  static let daySkyMid = Color(hex: 0xBFE3FF)
  static let daySkyLow = Color(hex: 0xE4F4FF)
  static let cloud = Color.white
  static let sun = Color(hex: 0xFFD23F)
  static let dayHillBack = Color(hex: 0x86D27E)
  static let dayHillFront = Color(hex: 0x4DAE5B)
  static let nightSkyTop = Color(hex: 0x070B24)
  static let nightSkyMid = Color(hex: 0x121A3A)
  static let nightSkyLow = Color(hex: 0x24305E)
  static let star = Color(hex: 0xF2E3B8)
  static let duskSun = Color(hex: 0xFF8A3D)
  static let dawnSun = Color(hex: 0xFFB14E)
  /// The text of the sunset sky.
  static let duskInk = Color(hex: 0xFFF6E6)
  static let moon = Color(hex: 0xE9C77B)
  static let nightHillBack = Color(hex: 0x22405A)
  static let nightHillFront = Color(hex: 0x183248)
  static let cream = Color(hex: 0xE9DFC8)
  static let gold = Color(hex: 0xF2C879)
  static let goldShadow = Color(hex: 0x9C7A36)
  static let nightTab = Color(hex: 0x2A3360)
  static let avatarNightColors = [Color(hex: 0x6E4A3A), Color(hex: 0x2E5248)]
  static let navy = Color(hex: 0x13355C)
  static let navyShadow = Color(hex: 0x0A1F38)
  static let avatarColors = [Color(hex: 0xFF9F68), Color(hex: 0x9FE3C6)]
  static let inRange = Color(hex: 0x1E7F5C)
  static let tooLittle = Color(hex: 0xC8402A)
  static let tooMuch = Color(hex: 0x6A4BD8)
  static let rangeBand = Color(hex: 0xD6F3E6)
  static let soFar = Color(hex: 0xA9C7E8)
  /// The pale blue of a timeline track and a sleep on the day sheet.
  static let track = Color(hex: 0xEAF5FF)
  static let nap = Color(hex: 0xFF9F68)
  static let tooLittleShadow = Color(hex: 0x8A2A1B)
  static let handle = Color(hex: 0xC9D6E4)
  static let handleShadow = Color(hex: 0xA9B8C9)
  /// The text of the "Only on this phone" tag in Settings.
  static let tagInk = Color(hex: 0x5A6F88)
  static let scrim = Color(red: 10 / 255, green: 25 / 255, blue: 50 / 255).opacity(0.45)

  /// The colour of a child's avatar: the colours alternate in the order of the children.
  static func avatarColor(at index: Int, sky: SkyPhase = .day) -> Color {
    let colors = sky == .night ? avatarNightColors : avatarColors
    return colors[index % colors.count]
  }
}

/// The static weights of Baloo 2 that the app bundles, made from `design/fonts/baloo2-latin.woff2`.
enum Baloo: String {
  case semiBold = "Baloo2-SemiBold"
  case bold = "Baloo2-Bold"
  case extraBold = "Baloo2-ExtraBold"
}

extension Font {
  static func baloo(_ size: CGFloat, _ weight: Baloo = .semiBold) -> Font {
    .custom(weight.rawValue, size: size)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

extension View {
  /// Sets Baloo 2 and trims its extra leading, so one line at the default text size is as tall as CSS
  /// `line-height` makes it in the gallery. Baloo 2's own line height is much taller, so without this the cards
  /// and the day sheet grow taller than their gallery pages. Only the empty space above and below the glyphs
  /// is trimmed, by a fixed amount: long text still wraps, and larger Dynamic Type sizes still grow.
  func balooLine(_ size: CGFloat, _ weight: Baloo = .semiBold, lineHeight: CGFloat) -> some View {
    let natural = UIFont(name: weight.rawValue, size: size)?.lineHeight ?? lineHeight
    return font(.baloo(size, weight)).padding(.vertical, min(0, (lineHeight - natural) / 2))
  }
}
