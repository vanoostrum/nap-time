import Core
import SwiftUI

/// The sky behind the home screen for one phase, as in `design/pages/home/day.html`, `sunset.html`,
/// `night-awake.html` (and `night.html`), and `sunrise.html`.
struct SkyView: View {
  let phase: SkyPhase

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      ZStack(alignment: .topLeading) {
        LinearGradient(stops: gradient, startPoint: .top, endPoint: .bottom)
        switch phase {
        case .day:
          Capsule().fill(Theme.cloud.opacity(0.85))
            .frame(width: 170, height: 60)
            .position(x: -40 + 85, y: 150 + 30)
          Capsule().fill(Theme.cloud.opacity(0.85))
            .frame(width: 140, height: 50)
            .position(x: width + 30 - 70, y: 250 + 25)
          Circle().fill(Theme.sun)
            .frame(width: 64, height: 64)
            .position(x: width - 40 - 32, y: 130 + 32)
        case .night:
          Stars(dim: false)
          Crescent.filled.fill(Theme.moon)
            .frame(width: 84, height: 84)
            .position(x: width - 30 - 42, y: 120 + 42)
        case .sunset:
          Stars(dim: true)
          LowSun(color: Theme.duskSun)
            .position(x: 250 + 45, y: 530 + 45)
        case .sunrise:
          LowSun(color: Theme.dawnSun)
            .position(x: 50 + 45, y: 500 + 45)
        }
        Hill(points: Hill.back).fill(hills.back)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
        Hill(points: Hill.front).fill(hills.front)
          .frame(width: width, height: 324)
          .offset(y: height - 324)
      }
    }
    .ignoresSafeArea()
  }

  private var gradient: [Gradient.Stop] {
    switch phase {
    case .day:
      [
        .init(color: Theme.daySkyTop, location: 0), .init(color: Theme.daySkyMid, location: 0.6),
        .init(color: Theme.daySkyLow, location: 1),
      ]
    case .night:
      [
        .init(color: Theme.nightSkyTop, location: 0), .init(color: Theme.nightSkyMid, location: 0.55),
        .init(color: Theme.nightSkyLow, location: 0.8), .init(color: Theme.nightSkyLow, location: 1),
      ]
    case .sunset:
      [
        .init(color: Color(hex: 0x2B3672), location: 0), .init(color: Color(hex: 0x7A4F9E), location: 0.32),
        .init(color: Color(hex: 0xE0697A), location: 0.56), .init(color: Color(hex: 0xFFA060), location: 0.7),
        .init(color: Color(hex: 0xFFD08A), location: 0.8), .init(color: Color(hex: 0xFFD08A), location: 1),
      ]
    case .sunrise:
      [
        .init(color: Color(hex: 0x4A5FA8), location: 0), .init(color: Color(hex: 0xB58BC4), location: 0.35),
        .init(color: Color(hex: 0xFFB4A0), location: 0.58), .init(color: Color(hex: 0xFFE3A6), location: 0.78),
        .init(color: Color(hex: 0xFFE3A6), location: 1),
      ]
    }
  }

  private var hills: (back: Color, front: Color) {
    switch phase {
    case .day: (Theme.dayHillBack, Theme.dayHillFront)
    case .night: (Theme.nightHillBack, Theme.nightHillFront)
    case .sunset: (Color(hex: 0x6E8F6A), Color(hex: 0x3C6B4A))
    case .sunrise: (Color(hex: 0x5E8064), Color(hex: 0x3A6247))
    }
  }
}

/// The big sun of sunset and sunrise, low behind the hills, with its glow.
private struct LowSun: View {
  let color: Color

  var body: some View {
    // The gallery's glow: box-shadow 0 0 40px 12px rgba(255, 190, 80, 0.45).
    ZStack {
      Circle().fill(Color(red: 1, green: 190 / 255, blue: 80 / 255).opacity(0.45))
        .frame(width: 114, height: 114)
        .blur(radius: 20)
      Circle().fill(color)
        .frame(width: 90, height: 90)
    }
  }
}

/// The stars of the night sky; at sunset they are dim.
private struct Stars: View {
  /// The stars of the gallery page: x, y, size, rotation in degrees, and whether it is a big one.
  private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, big: Bool)] = [
    (30, 140, 18, -20, true), (90, 215, 10, 3, false), (165, 118, 14, -14, false), (250, 190, 22, 9, true),
    (318, 262, 12, -8, false), (56, 330, 24, 15, true), (205, 300, 9, -2, false), (300, 160, 11, -19, false),
    (24, 404, 13, 4, false), (300, 470, 20, -13, true), (20, 470, 11, 10, false), (350, 440, 15, -7, false),
    (150, 490, 8, 16, false), (230, 250, 7, -1, false),
  ]

  let dim: Bool

  var body: some View {
    ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
      Star()
        .fill(Theme.star)
        .stroke(Theme.star, style: StrokeStyle(lineWidth: 1.5 * star.size / 24, lineJoin: .round))
        .frame(width: star.size, height: star.size)
        .rotationEffect(.degrees(star.rotation))
        .opacity(dim ? 0.3 : star.big ? 0.9 : 0.6)
        .position(x: star.x + star.size / 2, y: star.y + star.size / 2)
    }
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
