import Core
import SwiftUI

/// The home screen by day: the sky, the child switcher with "+", and the selected child.
///
/// With no children, as while the store loads, it shows only the sky, and `message` when there is one.
struct HomeView: View {
  var children: [Child] = []
  var selectedID: Child.ID?
  var message: String?
  var onSelect: (Child.ID) -> Void = { _ in }
  var onAdd: () -> Void = {}
  var onEdit: (Child.ID) -> Void = { _ in }

  private var selectedIndex: Int? { children.firstIndex { $0.id == selectedID } }

  var body: some View {
    ZStack(alignment: .top) {
      DaySky()
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
      }
      .padding(.horizontal, 24)
    }
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
          .foregroundStyle(Theme.navy)
          .frame(width: 48, height: 48)
          .overlay(Circle().strokeBorder(Theme.navy, style: StrokeStyle(lineWidth: 3, dash: [7, 4])))
      }
      .accessibilityLabel("Add a child")
      Spacer(minLength: 0)
    }
  }

  private func avatar(_ child: Child, index: Int) -> some View {
    let selected = child.id == selectedID
    return ChildPicture(child: child, index: index, letterSize: 22)
      .frame(width: 48, height: 48)
      .overlay(Circle().strokeBorder(selected ? Theme.navy : .clear, lineWidth: 3))
      .contentShape(Circle())
      .onTapGesture { onSelect(child.id) }
      .onLongPressGesture(minimumDuration: 0.5) { onEdit(child.id) }
      .accessibilityElement()
      .accessibilityLabel(child.name)
      .accessibilityIdentifier("avatar")
      .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
      .accessibilityAction { onSelect(child.id) }
      .accessibilityAction(named: "Edit \(child.name)") { onEdit(child.id) }
  }

  private func selectedChild(_ child: Child, index: Int) -> some View {
    VStack(spacing: 14) {
      ChildPicture(child: child, index: index, letterSize: 64)
        .frame(width: 150, height: 150)
        .overlay(Circle().strokeBorder(.white, lineWidth: 6))
        .accessibilityLabel("\(child.name)'s photo")
      Text("\(child.name) is awake")
        .font(.baloo(40, .extraBold))
        .foregroundStyle(Theme.navy)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 90)
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
    .accessibilityHidden(true)
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
