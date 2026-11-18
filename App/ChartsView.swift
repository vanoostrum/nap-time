import Core
import SwiftUI

/// The Charts tab: one week of the selected child, with the header and its arrows, the two stat cards,
/// and "Hours per day", or the empty state with "Add a sleep" for a week with no sleeps.
///
/// It opens on `Week.opening`. The week it shows is view state, so it opens there again
/// each time the tab or the child changes.
struct ChartsView: View {
  let child: Child
  /// The sleeps of `child`.
  let sleeps: [Sleep]
  let now: Date
  let timeZone: TimeZone
  /// "Add a sleep" on the empty state, with the start values for the shown week.
  let onAddSleep: (SleepStartValues) -> Void
  let onTab: (AppTab) -> Void

  /// The week the parent moved to, or `nil` for the opening week.
  @State private var movedTo: Week?

  private var week: Week { movedTo ?? Week.opening(now: now, in: timeZone) }
  private var reachable: ClosedRange<Week> {
    Week.reachable(firstSleepStart: sleeps.map(\.start).min(), now: now, in: timeZone)
  }

  var body: some View {
    let stats = WeekStats(week: week, sleeps: sleeps, birthDate: child.birthDate, now: now, in: timeZone)
    ZStack {
      Theme.daySkyMid.ignoresSafeArea()
      VStack(spacing: 12) {
        header
        statCards(stats)
        if stats.hasSleep {
          HoursPerDay(stats: stats)
        } else {
          emptyCard
        }
        Spacer(minLength: 0)
        TabBar(current: .charts, onSelect: onTab)
      }
      .foregroundStyle(Theme.navy)
      .padding(.horizontal, 20)
      .padding(.top, 4)
    }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 30).onEnded { drag in
        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
        move(drag.translation.width < 0 ? 1 : -1)
      }
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("charts")
  }

  private var header: some View {
    HStack {
      arrow(-1)
      Spacer(minLength: 0)
      VStack(spacing: -6) {
        Text("\(child.name)'s week")
          .font(.baloo(28, .extraBold))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(week.title)
          .font(.baloo(16))
      }
      Spacer(minLength: 0)
      arrow(1)
    }
  }

  /// The previous arrow for -1, the next arrow for 1. It is grey at each end of the reachable weeks.
  private func arrow(_ step: Int) -> some View {
    let enabled = reachable.contains(week.adding(weeks: step))
    return Button {
      move(step)
    } label: {
      Chevron(pointsLeft: step < 0)
        .stroke(Theme.navy, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .frame(width: 22, height: 22)
        .frame(width: 44, height: 44)
        .background(Circle().fill(.white))
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.35)
    .accessibilityLabel(step < 0 ? "Previous week" : "Next week")
  }

  private func move(_ step: Int) {
    let target = week.adding(weeks: step)
    guard reachable.contains(target) else { return }
    movedTo = target
  }

  private func statCards(_ stats: WeekStats) -> some View {
    let note =
      stats.hasSleep
      ? UsualBedtime(nights: UsualBedtime.nights(of: sleeps, in: week, timeZone: timeZone), in: timeZone).note
      : "no sleeps yet"
    return HStack(spacing: 10) {
      StatCard(label: "Average", value: stats.averageText, note: "range \(stats.range)")
      StatCard(label: "In range", value: stats.inRangeText, note: note)
    }
  }

  private var emptyCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("No sleeps this week")
        .font(.baloo(18, .extraBold))
      Text("Log \(child.name)'s sleeps on the Today tab, or add one from earlier.")
        .font(.baloo(18))
        .fixedSize(horizontal: false, vertical: true)
      Button("Add a sleep") {
        let current = Week.current(now: now, in: timeZone)
        onAddSleep(
          week == current
            ? SleepStartValues.today(now: now, in: timeZone) : SleepStartValues.on(week.sunday, now: now, in: timeZone))
      }
      .buttonStyle(PrimaryButtonStyle())
      .padding(.bottom, 6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    .background(RoundedRectangle(cornerRadius: 30).fill(.white))
  }
}

/// A white card with a label, a big value, and a note.
private struct StatCard: View {
  let label: String
  let value: String
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: -4) {
      Text(label).font(.baloo(15))
      Text(value).font(.baloo(26, .extraBold)).lineLimit(1).minimumScaleFactor(0.7)
      Text(note).font(.baloo(14)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(RoundedRectangle(cornerRadius: 24).fill(.white))
  }
}

/// "Hours per day": a bar per sleep day over the range band, on a fixed scale of 0 to 16 hours.
private struct HoursPerDay: View {
  let stats: WeekStats

  private static let chartHeight: CGFloat = 150
  private static let pointsPerHour = chartHeight / 16
  private static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Hours per day").font(.baloo(18, .extraBold))
      ZStack(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 8)
          .fill(Theme.rangeBand)
          .frame(height: CGFloat(stats.range.upperHours - stats.range.lowerHours) * Self.pointsPerHour)
          .offset(y: -CGFloat(stats.range.lowerHours) * Self.pointsPerHour)
          .accessibilityHidden(true)
        HStack(alignment: .bottom, spacing: 10) {
          ForEach(stats.days, id: \.sleepDay) { day in
            bar(day).frame(maxWidth: .infinity)
          }
        }
      }
      .frame(height: Self.chartHeight, alignment: .bottom)
      HStack(spacing: 10) {
        ForEach(Self.dayNames, id: \.self) { name in
          Text(name).font(.baloo(14, .bold)).frame(maxWidth: .infinity)
        }
      }
      legend
    }
    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    .background(RoundedRectangle(cornerRadius: 30).fill(.white))
  }

  @ViewBuilder private func bar(_ day: WeekStats.Day) -> some View {
    if day.state == .empty {
      Color.clear.frame(height: 0)
    } else {
      let height = min(day.total / 3600, 16) * Self.pointsPerHour
      let shape = UnevenRoundedRectangle(
        topLeadingRadius: 12, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 12)
      Group {
        if let judgement = day.judgement {
          shape.fill(Self.color(judgement))
        } else {
          Stripes().clipShape(shape).overlay(shape.strokeBorder(Theme.soFar, lineWidth: 2))
        }
      }
      .frame(height: height)
      .accessibilityElement()
      .accessibilityLabel(day.accessibilityLabel)
      .accessibilityValue(Self.value(day.judgement))
      .accessibilityIdentifier("bar")
    }
  }

  private var legend: some View {
    HStack(spacing: 14) {
      legendItem("in range") { RoundedRectangle(cornerRadius: 4).fill(Theme.inRange) }
      legendItem("too little") { RoundedRectangle(cornerRadius: 4).fill(Theme.tooLittle) }
      legendItem("too much") { RoundedRectangle(cornerRadius: 4).fill(Theme.tooMuch) }
      if stats.days.contains(where: { $0.state == .soFar }) {
        legendItem("so far") {
          RoundedRectangle(cornerRadius: 4).fill(.white)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.soFar, lineWidth: 2))
        }
      }
    }
  }

  private func legendItem(_ text: String, @ViewBuilder swatch: () -> some View) -> some View {
    HStack(spacing: 5) {
      swatch().frame(width: 12, height: 12)
      Text(text).font(.baloo(13))
    }
  }

  private static func color(_ judgement: WeekStats.Judgement) -> Color {
    switch judgement {
    case .inRange: Theme.inRange
    case .tooLittle: Theme.tooLittle
    case .tooMuch: Theme.tooMuch
    }
  }

  private static func value(_ judgement: WeekStats.Judgement?) -> String {
    switch judgement {
    case .inRange: "in range"
    case .tooLittle: "too little"
    case .tooMuch: "too much"
    case nil: "so far"
    }
  }
}

/// The pale diagonal stripes of a so-far bar: 6 points of `Theme.soFar`, then 4 of white.
private struct Stripes: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
      let span = size.width + size.height
      var x = -size.height
      while x < span {
        var stripe = Path()
        // A band 6 points wide, from the bottom left to the top right, as CSS draws 135deg.
        let width = 6 * 2.squareRoot()
        stripe.move(to: CGPoint(x: x + size.height, y: 0))
        stripe.addLine(to: CGPoint(x: x + size.height + width, y: 0))
        stripe.addLine(to: CGPoint(x: x + width, y: size.height))
        stripe.addLine(to: CGPoint(x: x, y: size.height))
        stripe.closeSubpath()
        context.fill(stripe, with: .color(Theme.soFar))
        x += 10 * 2.squareRoot()
      }
    }
  }
}

/// The chevron of the week arrows, in a 24 × 24 box: "M15 6l-6 6 6 6", or its mirror.
private struct Chevron: Shape {
  let pointsLeft: Bool

  func path(in rect: CGRect) -> Path {
    let scale = rect.width / 24
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + (pointsLeft ? x : 24 - x) * scale, y: rect.minY + y * scale)
    }
    var path = Path()
    path.move(to: point(15, 6))
    path.addLine(to: point(9, 12))
    path.addLine(to: point(15, 18))
    return path
  }
}
