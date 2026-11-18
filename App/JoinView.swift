import Core
import SwiftUI

/// The join screens on the day sky: "Joining the family…" right after the partner opens the invite, then
/// "You joined the family" with "Start" (`design/pages/family/joining.html`, `design/pages/family/joined.html`).
struct JoinView: View {
  let screen: JoinScreen
  /// The children of the shared store, in the order they were added.
  let children: [Child]
  /// The spinner turns. Test mode keeps it still, so the UI tests see an idle app and the same screenshot.
  var animates = true
  var onStart: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var spins = false

  var body: some View {
    ZStack(alignment: .top) {
      SkyView(phase: .day)
        .accessibilityHidden(true)
      VStack(spacing: 0) {
        VStack(spacing: 6) {
          picture
            .padding(.bottom, 8)
          Text(screen.title)
            .balooLine(40, .extraBold, lineHeight: 42)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
          Text(text)
            .font(.baloo(20, .semiBold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.navy)
        .padding(.top, 90)
        Spacer(minLength: 0)
        if screen == .joined {
          Button("Start", action: onStart)
            .buttonStyle(MainButtonStyle(gold: false))
            .accessibilityIdentifier("start")
            .padding(.bottom, 20)
        }
      }
      .padding(.horizontal, 24)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(screen == .joining ? "joining" : "joined")
  }

  private var text: String {
    switch screen {
    case .joining: JoinScreen.joiningText
    case .joined: JoinedText.text(names: children.map(\.name))
    }
  }

  @ViewBuilder private var picture: some View {
    switch screen {
    case .joining:
      Circle()
        .stroke(.white, lineWidth: 12)
        .overlay(
          Circle()
            .trim(from: 0, to: 0.25)
            .stroke(Theme.navy, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
            .rotationEffect(.degrees(spins ? 225 : -135))
        )
        .padding(6)
        .frame(width: 120, height: 120)
        .onAppear {
          guard animates, !reduceMotion else { return }
          withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spins = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Joining")
        .accessibilityAddTraits(.updatesFrequently)
    case .joined:
      ChildPicture(child: children.first, index: 0, letterSize: 64)
        .frame(width: 150, height: 150)
        .overlay(Circle().strokeBorder(.white, lineWidth: 6))
        .accessibilityLabel("\(children.first?.name ?? "")'s photo")
    }
  }
}
