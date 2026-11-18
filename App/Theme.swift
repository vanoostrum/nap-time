import Core
import SwiftUI
import UIKit

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
  var sky = SkyPhase.day

  var body: some View {
    ZStack {
      Circle().fill(Theme.avatarColor(at: index, sky: sky))
      if let photo = child?.photo, let image = UIImage(data: photo) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Text(child?.initial ?? "")
          .font(.baloo(letterSize, .extraBold))
          .foregroundStyle(sky == .night ? Theme.cream : Theme.navy)
      }
    }
    .clipShape(Circle())
  }
}
