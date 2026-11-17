import Core
import SwiftUI
import UIKit

/// The colours and fonts of style B "Storybook", from `design/gallery.css`.
enum Theme {
  static let daySkyTop = Color(hex: 0x6FBEFF)
  static let daySkyMid = Color(hex: 0xBFE3FF)
  static let daySkyLow = Color(hex: 0xE4F4FF)
  static let cloud = Color.white
  static let sun = Color(hex: 0xFFD23F)
  static let dayHillBack = Color(hex: 0x86D27E)
  static let dayHillFront = Color(hex: 0x4DAE5B)
  static let navy = Color(hex: 0x13355C)
  static let navyShadow = Color(hex: 0x0A1F38)
  static let avatarColors = [Color(hex: 0xFF9F68), Color(hex: 0x9FE3C6)]
  static let tooLittle = Color(hex: 0xC8402A)
  static let tooLittleShadow = Color(hex: 0x8A2A1B)
  static let handle = Color(hex: 0xC9D6E4)
  static let handleShadow = Color(hex: 0xA9B8C9)
  static let scrim = Color(red: 10 / 255, green: 25 / 255, blue: 50 / 255).opacity(0.45)

  /// The colour of a child's avatar: the colours alternate in the order of the children.
  static func avatarColor(at index: Int) -> Color { avatarColors[index % avatarColors.count] }
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

/// The big pill button: navy, or red for a destructive action, grey when disabled.
struct PrimaryButtonStyle: ButtonStyle {
  var destructive = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    let fill = isEnabled ? (destructive ? Theme.tooLittle : Theme.navy) : Theme.handle
    let shadow = isEnabled ? (destructive ? Theme.tooLittleShadow : Theme.navyShadow) : Theme.handleShadow
    configuration.label
      .font(.baloo(26, .extraBold))
      .foregroundStyle(.white)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 72)
      .background(Capsule().fill(fill))
      .background(Capsule().fill(shadow).offset(y: 6))
      .offset(y: configuration.isPressed ? 3 : 0)
  }
}

/// A child's picture: the photo, or the first letter of the name on the child's colour.
struct ChildPicture: View {
  let child: Child?
  let index: Int
  let letterSize: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Theme.avatarColor(at: index))
      if let photo = child?.photo, let image = UIImage(data: photo) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Text(child?.initial ?? "")
          .font(.baloo(letterSize, .extraBold))
          .foregroundStyle(Theme.navy)
      }
    }
    .clipShape(Circle())
  }
}
