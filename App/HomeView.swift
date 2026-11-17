import Core
import SwiftUI

/// The home screen: the sky, the child switcher with "+", the selected child with the status line,
/// and "Sleep time" or "Wake up".
///
/// With no children, as while the store loads, it shows only the sky, and `message` when there is one.
struct HomeView: View {
  var children: [Child] = []
  var selectedID: Child.ID?
  /// The status of the selected child.
  var status: ChildStatus?
  var message: String?
  var onSelect: (Child.ID) -> Void = { _ in }
  var onAdd: () -> Void = {}
  var onEdit: (Child.ID) -> Void = { _ in }
  var onSleep: () -> Void = {}
  var onWake: () -> Void = {}

  /// Counts taps on the main button, for the haptic tap.
  @State private var mainButtonTaps = 0

  private var selectedIndex: Int? { children.firstIndex { $0.id == selectedID } }
  private var sky: Sky { status?.sky ?? .day }
  private var ink: Color { sky == .night ? Theme.cream : Theme.navy }

  var body: some View {
    ZStack(alignment: .top) {
      ZStack {
        if sky == .night {
          NightSky().transition(.opacity)
        } else {
          DaySky().transition(.opacity)
        }
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
          mainButton(children[index], status: status)
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
          .foregroundStyle(ink)
          .frame(width: 48, height: 48)
          .overlay(Circle().strokeBorder(ink, style: StrokeStyle(lineWidth: 3, dash: [7, 4])))
      }
      .accessibilityLabel("Add a child")
      Spacer(minLength: 0)
    }
  }

  private func avatar(_ child: Child, index: Int) -> some View {
    let selected = child.id == selectedID
    return ChildPicture(child: child, index: index, letterSize: 22, sky: sky)
      .frame(width: 48, height: 48)
      .overlay(Circle().strokeBorder(selected ? ink : .clear, lineWidth: 3))
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
        .overlay(Circle().strokeBorder(sky == .night ? Theme.nightTab : .white, lineWidth: 6))
        .accessibilityLabel("\(child.name)'s photo")
      // Baloo's line height is taller than the gallery's 1.05, so pull the status line up.
      VStack(spacing: -6) {
        Text(status?.heading(name: child.name) ?? "\(child.name) is awake")
          .font(.baloo(40, .extraBold))
          .foregroundStyle(ink)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        if let status {
          Text(status.line)
            .font(.baloo(20, .semiBold))
            .foregroundStyle(sky == .night ? Theme.gold : Theme.navy)
            .multilineTextAlignment(.center)
        }
      }
    }
    .padding(.top, 90)
  }

  /// "Sleep time" while the child is awake, "Wake up" while a sleep runs.
  private func mainButton(_ child: Child, status: ChildStatus) -> some View {
    let sleeping = status.isSleeping
    return Button {
      mainButtonTaps += 1
      sleeping ? onWake() : onSleep()
    } label: {
      Label {
        Text(sleeping ? "Wake up" : "Sleep time")
      } icon: {
        (sleeping ? AnyShape(SunIcon()) : AnyShape(Crescent.outline))
          .stroke(style: StrokeStyle(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
      }
    }
    .buttonStyle(MainButtonStyle(sky: sky))
    .accessibilityLabel(sleeping ? "\(child.name) woke up" : "\(child.name) fell asleep")
    .accessibilityIdentifier(sleeping ? "Wake up" : "Sleep time")
    .padding(.bottom, 20)
    .transition(.opacity)
    .id(sleeping)
  }
}

/// The big main button of the home screen: navy by day, gold at night.
private struct MainButtonStyle: ButtonStyle {
  let sky: Sky

  func makeBody(configuration: Configuration) -> some View {
    let night = sky == .night
    let ink = night ? Theme.nightSkyMid : .white
    HStack(spacing: 14) {
      configuration.label.labelStyle(MainButtonLabelStyle(iconColor: night ? Theme.nightSkyMid : Theme.sun))
    }
    .font(.baloo(42, .extraBold))
    .foregroundStyle(ink)
    .frame(maxWidth: .infinity)
    .frame(height: 120)
    .background(RoundedRectangle(cornerRadius: 40).fill(night ? Theme.gold : Theme.navy))
    .background(RoundedRectangle(cornerRadius: 40).fill(night ? Theme.goldShadow : Theme.navyShadow).offset(y: 8))
    .offset(y: configuration.isPressed ? 4 : 0)
  }
}

private struct MainButtonLabelStyle: LabelStyle {
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

/// The day sky: the gradient, two clouds, the sun, and the hills, as in `design/pages/home/day.html`.
struct DaySky: View {
  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      ZStack(alignment: .topLeading) {
        LinearGradient(
          stops: [
            .init(color: Theme.daySkyTop, location: 0),
            .init(color: Theme.daySkyMid, location: 0.6),
            .init(color: Theme.daySkyLow, location: 1),
          ], startPoint: .top, endPoint: .bottom)
        Capsule().fill(Theme.cloud.opacity(0.85))
          .frame(width: 170, height: 60)
          .position(x: -40 + 85, y: 150 + 30)
        Capsule().fill(Theme.cloud.opacity(0.85))
          .frame(width: 140, height: 50)
          .position(x: width + 30 - 70, y: 250 + 25)
        Circle().fill(Theme.sun)
          .frame(width: 64, height: 64)
          .position(x: width - 40 - 32, y: 130 + 32)
        Hill(points: Hill.back).fill(Theme.dayHillBack)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
        Hill(points: Hill.front).fill(Theme.dayHillFront)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
      }
    }
    .ignoresSafeArea()
  }
}

/// The night sky: the gradient, the stars, the moon, and the night hills, as in `design/pages/home/night.html`.
struct NightSky: View {
  /// The stars of the gallery page: x, y, size, rotation in degrees, and whether it is a big one.
  private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, big: Bool)] = [
    (30, 140, 18, -20, true), (90, 215, 10, 3, false), (165, 118, 14, -14, false), (250, 190, 22, 9, true),
    (318, 262, 12, -8, false), (56, 330, 24, 15, true), (205, 300, 9, -2, false), (300, 160, 11, -19, false),
    (24, 404, 13, 4, false), (300, 470, 20, -13, true), (20, 470, 11, 10, false), (350, 440, 15, -7, false),
    (150, 490, 8, 16, false), (230, 250, 7, -1, false),
  ]

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      ZStack(alignment: .topLeading) {
        LinearGradient(
          stops: [
            .init(color: Theme.nightSkyTop, location: 0),
            .init(color: Theme.nightSkyMid, location: 0.55),
            .init(color: Theme.nightSkyLow, location: 0.8),
            .init(color: Theme.nightSkyLow, location: 1),
          ], startPoint: .top, endPoint: .bottom)
        ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
          Star()
            .fill(Theme.star)
            .stroke(Theme.star, style: StrokeStyle(lineWidth: 1.5 * star.size / 24, lineJoin: .round))
            .frame(width: star.size, height: star.size)
            .rotationEffect(.degrees(star.rotation))
            .opacity(star.big ? 0.9 : 0.6)
            .position(x: star.x + star.size / 2, y: star.y + star.size / 2)
        }
        Crescent.filled.fill(Theme.moon)
          .frame(width: 84, height: 84)
          .position(x: width - 30 - 42, y: 120 + 42)
        Hill(points: Hill.back).fill(Theme.nightHillBack)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
        Hill(points: Hill.front).fill(Theme.nightHillFront)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
      }
    }
    .ignoresSafeArea()
  }
}

/// The gallery's crescent moon, in a 24 × 24 box: an outer arc, then an inner arc back to the start.
///
/// The circles come from the SVG arcs of `design/pages/home/night.html` (the sky's moon) and
/// `design/pages/home/day.html` (the "Sleep time" icon), converted to centers and angles.
private struct Crescent: Shape {
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

/// The five-pointed star of the gallery, in a 24 × 24 box.
private struct Star: Shape {
  // M12 2.5 l2.9 6 6.6.8 -4.9 4.6 1.3 6.6 L12 17.2 l-5.9 3.3 1.3-6.6 -4.9-4.6 6.6-.8z
  private static let points: [CGPoint] = [
    CGPoint(x: 12, y: 2.5), CGPoint(x: 14.9, y: 8.5), CGPoint(x: 21.5, y: 9.3), CGPoint(x: 16.6, y: 13.9),
    CGPoint(x: 17.9, y: 20.5), CGPoint(x: 12, y: 17.2), CGPoint(x: 6.1, y: 20.5), CGPoint(x: 7.4, y: 13.9),
    CGPoint(x: 2.5, y: 9.3), CGPoint(x: 9.1, y: 8.5),
  ]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let scale = rect.width / 24
    path.addLines(Self.points.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
    path.closeSubpath()
    return path
  }
}

/// A hill from the gallery's SVG, drawn in a 390 × 324 box that is stretched to the frame.
private struct Hill: Shape {
  /// The start point, then one cubic curve and one smooth curve, as (control 1, control 2, end).
  let points: [CGPoint]

  // M0 70 C 80 20, 170 30, 240 55 S 360 40, 390 30. S mirrors the last control point: (310, 80).
  static let back = [
    CGPoint(x: 0, y: 70), CGPoint(x: 80, y: 20), CGPoint(x: 170, y: 30), CGPoint(x: 240, y: 55),
    CGPoint(x: 310, y: 80), CGPoint(x: 360, y: 40), CGPoint(x: 390, y: 30),
  ]
  // M0 120 C 90 60, 200 70, 290 95 S 370 110, 390 100. The mirrored control point is (380, 120).
  static let front = [
    CGPoint(x: 0, y: 120), CGPoint(x: 90, y: 60), CGPoint(x: 200, y: 70), CGPoint(x: 290, y: 95),
    CGPoint(x: 380, y: 120), CGPoint(x: 370, y: 110), CGPoint(x: 390, y: 100),
  ]

  func path(in rect: CGRect) -> Path {
    let scaleX = rect.width / 390
    let scaleY = rect.height / 324
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * scaleX, y: rect.minY + p.y * scaleY) }
    var path = Path()
    path.move(to: point(points[0]))
    path.addCurve(to: point(points[3]), control1: point(points[1]), control2: point(points[2]))
    path.addCurve(to: point(points[6]), control1: point(points[4]), control2: point(points[5]))
    path.addLine(to: point(CGPoint(x: 390, y: 324)))
    path.addLine(to: point(CGPoint(x: 0, y: 324)))
    path.closeSubpath()
    return path
  }
}

#Preview {
  HomeView(children: [], message: nil)
}
