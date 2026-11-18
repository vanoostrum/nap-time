import Core
import CoreText
import SwiftUI
import XCTest

/// Renders the sleep timer's views with `ImageRenderer`, because a UI test cannot open a Live Activity or the
/// Dynamic Island (ADR 0003). The views get a plain "Awake" button: `EndSleepIntent` is not in this target.
enum SleepTimerRender {
  /// The width of the card on the gallery pages: the 393-point screen less 14 points on each side.
  static let cardWidth: CGFloat = 365

  /// The face of the seed's running sleep, for its child, paused at `pauseTime`, in Amsterdam as in test mode.
  static func face(seed: Seed, pauseTime: String) throws -> SleepTimerFace {
    let sleep = try XCTUnwrap(seed.sleeps.first { $0.end == nil }, "The seed has no running sleep")
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return SleepTimerFace(
      name: seed.children[sleep.childIndex].name, avatarColorIndex: sleep.childIndex, start: sleep.start,
      kind: sleep.kind, timeZone: TestEnvironment.standard.timeZone,
      pauseTime: try XCTUnwrap(formatter.date(from: pauseTime)))
  }

  /// The Lock Screen card, as iOS shows it: rounded, on the Lock Screen.
  @MainActor static func card(_ face: SleepTimerFace) -> some View {
    SleepTimerCard(face) { Button("Awake") {} }
      .clipShape(RoundedRectangle(cornerRadius: 26))
      .frame(width: cardWidth)
      .padding(14)
      .background(lockScreen)
  }

  /// The compact, the minimal, and the expanded Dynamic Island, in the black shapes that iOS draws around them.
  @MainActor static func island(_ face: SleepTimerFace) -> some View {
    VStack(alignment: .leading, spacing: 28) {
      HStack {
        SleepTimerIcon(kind: face.kind)
        Spacer()
        SleepTimerIslandTimer(face: face)
      }
      .padding(.horizontal, 14)
      .frame(width: 250, height: 40)
      .background(Capsule().fill(.black))

      HStack(spacing: 8) {
        SleepTimerIcon(kind: face.kind)
          .frame(width: 40, height: 40)
          .background(Circle().fill(.black))
        Capsule().fill(.black).frame(width: 160, height: 40)
      }

      SleepTimerExpanded(face) { Button("Awake") {} }
        .padding(.top, 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(RoundedRectangle(cornerRadius: 44).fill(.black))
    }
    .frame(width: cardWidth)
    .padding(14)
    .background(lockScreen)
  }

  /// Saves the view as `<entry point>.png`, at 3x, as `AppDriver.attachScreenshot` does for a screen.
  @MainActor static func attach(_ view: some View, as entryPoint: String, to testCase: XCTestCase) throws {
    registerBaloo()
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = 3
    let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer gave no image")
    let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
    attachment.name = "\(entryPoint).png"
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
  }

  /// The Lock Screen behind the card, from `.lock` in `design/gallery.css`.
  private static var lockScreen: LinearGradient {
    LinearGradient(colors: [Color(hex: 0x1B2348), Color(hex: 0x3B3F6B)], startPoint: .top, endPoint: .bottom)
  }

  /// `ImageRenderer` runs in the test runner, which has no `UIAppFonts`, so register Baloo 2 from this bundle.
  @MainActor private static var isBalooRegistered = false

  @MainActor private static func registerBaloo() {
    guard !isBalooRegistered else { return }
    isBalooRegistered = true
    let bundle = Bundle(for: EntryPointTests.self)
    for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
