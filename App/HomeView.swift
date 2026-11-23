import Core
import SwiftUI

/// The home screen: the sky, the child switcher with "+", the selected child with the status line,
/// "Nap time" or "Sleep time" with "Add a sleep from earlier", or "Wake up" with "Woke earlier? Set the time", and the tab bar.
///
/// With no children, as while the store loads, it shows only the sky, and `message` when there is one.
struct HomeView: View {
  var children: [Child] = []
  var selectedID: Child.ID?
  /// The status of the selected child.
  var status: ChildStatus?
  /// The kind of sleep a tap on the main button starts now. It gives the button's title while the child is awake.
  var startKind: SleepKind = .night
  var message: String?
  var onSelect: (Child.ID) -> Void = { _ in }
  var onAdd: () -> Void = {}
  var onEdit: (Child.ID) -> Void = { _ in }
  var onSleep: () -> Void = {}
  var onWake: () -> Void = {}
  /// "Add a sleep from earlier", or "Woke earlier? Set the time" while a sleep runs.
  var onSleepLink: () -> Void = {}
  /// A tap on the status line. `nil` when there is no sleep to open.
  var onStatusLine: (() -> Void)?
  /// A tap on the tab bar. `nil` hides the tab bar, as with no children.
  var onTab: ((AppTab) -> Void)?
  /// The gear, which opens Settings. `nil` hides it.
  var onSettings: (() -> Void)?

  /// Counts taps on the main button, for the haptic tap.
  @State private var mainButtonTaps = 0
  /// When the main button last took a tap. "Wake up" replaces "Nap time" or "Sleep time" in the same place,
  /// so a fast second tap would end the sleep it just started; such a tap is ignored.
  @State private var lastMainButtonTap = Date.distantPast

  private var selectedIndex: Int? { children.firstIndex { $0.id == selectedID } }
  private var sky: SkyPhase { status?.sky ?? .day }
  private var colors: HomeColors { .on(sky) }

  var body: some View {
    ZStack(alignment: .top) {
      ZStack {
        SkyView(phase: sky)
          .id(sky)
          .transition(.opacity)
      }
      .accessibilityElement()
      .accessibilityLabel("Sky")
      .accessibilityValue(sky.rawValue)
      .accessibilityIdentifier("sky")
      VStack(spacing: 0) {
        if !children.isEmpty {
          switcher
        }
        if let index = selectedIndex {
          selectedChild(children[index], index: index)
        }
        if let message {
          Text(message)
            .font(.baloo(20, .bold))
            .foregroundStyle(Theme.navy)
            .multilineTextAlignment(.center)
            .padding(.top, 150)
        }
        Spacer(minLength: 0)
        if let index = selectedIndex, let status {
          VStack(spacing: 14) {
            mainButton(children[index], status: status)
            sleepLink(sleeping: status.isSleeping)
          }
          .padding(.bottom, onTab == nil ? 20 : 8)
          if let onTab {
            TabBar(current: .today, sky: sky, onSelect: onTab)
          }
        }
      }
      .padding(.horizontal, 24)
    }
    .animation(.easeInOut(duration: 0.3), value: sky)
    .animation(.easeInOut(duration: 0.3), value: status?.isSleeping)
    .sensoryFeedback(.impact(weight: .light), trigger: mainButtonTaps)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("home")
  }

  private var switcher: some View {
    HStack(spacing: 10) {
      ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
        avatar(child, index: index)
      }
      Button(action: onAdd) {
        Text("+")
          .font(.baloo(26, .bold))
          .foregroundStyle(colors.add)
          .frame(width: 48, height: 48)
          .overlay(Circle().strokeBorder(colors.add, style: StrokeStyle(lineWidth: 3, dash: [7, 4])))
      }
      .accessibilityLabel("Add a child")
      Spacer(minLength: 0)
      if let onSettings {
        Button(action: onSettings) {
          Image(systemName: "gearshape")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(colors.gearInk)
            .frame(width: 48, height: 48)
            .background(Circle().fill(colors.gearFill))
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("gear")
      }
    }
  }

  private func avatar(_ child: Child, index: Int) -> some View {
    let selected = child.id == selectedID
    return ChildPicture(child: child, index: index, letterSize: 22, sky: sky)
      .frame(width: 48, height: 48)
      .overlay(Circle().strokeBorder(selected ? colors.ring : .clear, lineWidth: 3))
      .contentShape(Circle())
      // One gesture, so a touch and hold never also counts as a tap.
      .gesture(
        LongPressGesture(minimumDuration: 0.5)
          .onEnded { _ in onEdit(child.id) }
          .exclusively(before: TapGesture().onEnded { onSelect(child.id) })
      )
      .accessibilityElement()
      .accessibilityLabel(child.name)
      .accessibilityIdentifier("avatar")
      .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
      .accessibilityAction { onSelect(child.id) }
      .accessibilityAction(named: "Edit \(child.name)") { onEdit(child.id) }
  }

  private func selectedChild(_ child: Child, index: Int) -> some View {
    VStack(spacing: 14) {
      ChildPicture(child: child, index: index, letterSize: 64, sky: sky)
        .frame(width: 150, height: 150)
        .overlay(Circle().strokeBorder(colors.photoBorder, lineWidth: 6))
        .accessibilityLabel("\(child.name)'s photo")
      // Baloo's line height is taller than the gallery's 1.05, so pull the status line up.
      VStack(spacing: -6) {
        Text(status?.heading(name: child.name) ?? "\(child.name) is awake")
          .font(.baloo(40, .extraBold))
          .foregroundStyle(colors.heading)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        if let status {
          statusLine(status.line)
        }
      }
    }
    .padding(.top, 90)
  }

  /// The status line. A tap opens the running sleep, or the last sleep, when there is one.
  @ViewBuilder private func statusLine(_ line: String) -> some View {
    let text = Text(line)
      .font(.baloo(20, .semiBold))
      .foregroundStyle(colors.line)
      .multilineTextAlignment(.center)
    if let onStatusLine {
      Button(action: onStatusLine) { text }
        .buttonStyle(.plain)
        .accessibilityIdentifier("status-line")
    } else {
      text.accessibilityIdentifier("status-line")
    }
  }

  /// The underlined link below the main button.
  private func sleepLink(sleeping: Bool) -> some View {
    Button(action: onSleepLink) {
      Text(sleeping ? "Woke earlier? Set the time" : "Add a sleep from earlier")
        .font(.baloo(19, .semiBold))
        .underline()
        .foregroundStyle(colors.link)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(sleeping ? "woke-earlier" : "add-sleep")
    .transition(.opacity)
    .id(sleeping)
  }

  /// "Nap time" or "Sleep time" while the child is awake, by `startKind`, and "Wake up" while a sleep runs.
  private func mainButton(_ child: Child, status: ChildStatus) -> some View {
    let sleeping = status.isSleeping
    let title = sleeping ? "Wake up" : startKind.startTitle
    return Button {
      let now = Date()
      guard now.timeIntervalSince(lastMainButtonTap) >= 0.5 else { return }
      lastMainButtonTap = now
      mainButtonTaps += 1
      sleeping ? onWake() : onSleep()
    } label: {
      Label {
        Text(title)
      } icon: {
        (sleeping ? AnyShape(SunIcon()) : AnyShape(Crescent.outline))
          .stroke(style: StrokeStyle(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
      }
    }
    .buttonStyle(MainButtonStyle(gold: colors.goldButton))
    .accessibilityLabel(sleeping ? "\(child.name) woke up" : "\(child.name) fell asleep")
    .accessibilityIdentifier(title)
    .transition(.opacity)
    .id(sleeping)
  }
}

/// The colours of the home screen on each sky, from `design/gallery.css`.
private struct HomeColors {
  let heading: Color
  let line: Color
  let link: Color
  /// The ring of the selected avatar.
  let ring: Color
  /// The "+" of the switcher.
  let add: Color
  let photoBorder: Color
  /// The round gear button: white by day, the tab colour at night.
  let gearFill: Color
  let gearInk: Color
  /// The main button is gold at night and at sunset, navy by day and at sunrise.
  let goldButton: Bool

  static func on(_ sky: SkyPhase) -> HomeColors {
    switch sky {
    case .day:
      HomeColors(
        heading: Theme.navy, line: Theme.navy, link: Theme.navy, ring: Theme.navy, add: Theme.navy,
        photoBorder: .white, gearFill: .white, gearInk: Theme.navy, goldButton: false)
    case .night:
      HomeColors(
        heading: Theme.cream, line: Theme.gold, link: Theme.gold, ring: Theme.cream, add: Theme.cream,
        photoBorder: Theme.nightTab, gearFill: Theme.nightTab, gearInk: Theme.cream, goldButton: true)
    case .sunset:
      HomeColors(
        heading: Theme.duskInk, line: Theme.duskInk, link: Theme.duskInk, ring: Theme.duskInk, add: Theme.navy,
        photoBorder: .white, gearFill: .white, gearInk: Theme.navy, goldButton: true)
    case .sunrise:
      HomeColors(
        heading: Theme.navy, line: Theme.navy, link: .white, ring: Theme.navy, add: Theme.navy,
        photoBorder: .white, gearFill: .white, gearInk: Theme.navy, goldButton: false)
    }
  }
}

/// The big main button of the home screen: navy, or gold at night and at sunset.
struct MainButtonStyle: ButtonStyle {
  let gold: Bool

  func makeBody(configuration: Configuration) -> some View {
    let ink = gold ? Theme.nightSkyMid : .white
    HStack(spacing: 14) {
      configuration.label.labelStyle(MainButtonLabelStyle(iconColor: gold ? Theme.nightSkyMid : Theme.sun))
    }
    .font(.baloo(42, .extraBold))
    .foregroundStyle(ink)
    .frame(maxWidth: .infinity)
    .frame(height: 120)
    .background(RoundedRectangle(cornerRadius: 40).fill(gold ? Theme.gold : Theme.navy))
    .background(RoundedRectangle(cornerRadius: 40).fill(gold ? Theme.goldShadow : Theme.navyShadow).offset(y: 8))
    .offset(y: configuration.isPressed ? 4 : 0)
  }
}

struct MainButtonLabelStyle: LabelStyle {
  let iconColor: Color

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 14) {
      configuration.icon
        .foregroundStyle(iconColor)
        .frame(width: 48, height: 48)
      configuration.title
    }
  }
}

/// The gallery's crescent moon, in a 24 × 24 box: an outer arc, then an inner arc back to the start.
///
/// The circles come from the SVG arcs of `design/pages/home/night.html` (the sky's moon) and
/// `design/pages/home/day.html` (the icon of "Nap time" and "Sleep time"), converted to centers and angles.
struct Crescent: Shape {
  struct Arc {
    let center: CGPoint
    let radius: CGFloat
    /// Degrees, in the box's coordinates with y down.
    let from: Double
    let to: Double
  }

  let outer: Arc
  let inner: Arc

  // M20.5 14.2 A8.5 8.5 0 1 1 9.8 3.5 a6.6 6.6 0 0 0 10.7 10.7z
  static let filled = Crescent(
    outer: Arc(center: CGPoint(x: 12.411, y: 11.589), radius: 8.5, from: 17.89, to: 252.11),
    inner: Arc(center: CGPoint(x: 15.15, y: 8.85), radius: 7.566, from: -135, to: -315))
  // M21 12.8 A9 9 0 1 1 11.2 3 a7 7 0 0 0 9.8 9.8z
  static let outline = Crescent(
    outer: Arc(center: CGPoint(x: 12.039, y: 11.961), radius: 9, from: 5.35, to: 264.65),
    inner: Arc(center: CGPoint(x: 16.8, y: 7.2), radius: 7, from: -143.13, to: -306.87))

  func path(in rect: CGRect) -> Path {
    let scale = rect.width / 24
    func points(_ arc: Arc) -> [CGPoint] {
      let steps = 48
      return (0...steps).map { step in
        let angle = (arc.from + (arc.to - arc.from) * Double(step) / Double(steps)) * .pi / 180
        return CGPoint(
          x: rect.minX + (arc.center.x + arc.radius * cos(angle)) * scale,
          y: rect.minY + (arc.center.y + arc.radius * sin(angle)) * scale)
      }
    }
    var path = Path()
    path.addLines(points(outer) + points(inner))
    path.closeSubpath()
    return path
  }
}

/// The gallery's sun icon for "Wake up", in a 24 × 24 box: a circle and eight rays.
private struct SunIcon: Shape {
  // M12 2v2 M12 20v2 M4.9 4.9l1.4 1.4 M17.7 17.7l1.4 1.4 M2 12h2 M20 12h2 M4.9 19.1l1.4-1.4 M17.7 6.3l1.4-1.4
  private static let rays: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 12, y: 2), CGPoint(x: 12, y: 4)), (CGPoint(x: 12, y: 20), CGPoint(x: 12, y: 22)),
    (CGPoint(x: 4.9, y: 4.9), CGPoint(x: 6.3, y: 6.3)), (CGPoint(x: 17.7, y: 17.7), CGPoint(x: 19.1, y: 19.1)),
    (CGPoint(x: 2, y: 12), CGPoint(x: 4, y: 12)), (CGPoint(x: 20, y: 12), CGPoint(x: 22, y: 12)),
    (CGPoint(x: 4.9, y: 19.1), CGPoint(x: 6.3, y: 17.7)), (CGPoint(x: 17.7, y: 6.3), CGPoint(x: 19.1, y: 4.9)),
  ]

  func path(in rect: CGRect) -> Path {
    let scale = rect.width / 24
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * scale, y: rect.minY + p.y * scale) }
    var path = Path()
    path.addEllipse(in: CGRect(x: rect.minX + 8 * scale, y: rect.minY + 8 * scale, width: 8 * scale, height: 8 * scale))
    for (start, end) in Self.rays {
      path.move(to: point(start))
      path.addLine(to: point(end))
    }
    return path
  }
}

#Preview {
  HomeView(children: [], message: nil)
}
