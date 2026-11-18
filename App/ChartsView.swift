import Core
import SwiftUI
import UIKit

/// The Charts tab: one week of the selected child, with the header and its arrows, the two stat cards,
/// "Hours per day", and the timeline "When <name> slept", or the empty state with "Add a sleep" for a week
/// with no sleeps. A tap on a bar or a timeline row opens the day sheet of that sleep day.
///
/// It opens on `Week.opening`. The week it shows is view state, so it opens there again
/// each time the tab or the child changes. The day sheet is an overlay, not a presented sheet,
/// so the sleep form that `RootView` presents shows over it and the sheet stays open behind the form.
struct ChartsView: View {
  let child: Child
  /// The sleeps of `child`.
  let sleeps: [Sleep]
  let now: Date
  let timeZone: TimeZone
  /// "Add a sleep" on the empty state, or "+ Add a sleep to this day" on the day sheet, with its start values.
  let onAddSleep: (SleepStartValues) -> Void
  /// A pencil on the day sheet.
  let onEditSleep: (Sleep) -> Void
  let onTab: (AppTab) -> Void

  /// The week the parent moved to, or `nil` for the opening week.
  @State private var movedTo: Week?
  /// The sleep day whose day sheet is open.
  @State private var openDay: SleepDay?

  private var week: Week { movedTo ?? Week.opening(now: now, in: timeZone) }
  private var reachable: ClosedRange<Week> {
    Week.reachable(firstSleepStart: sleeps.map(\.start).min(), now: now, in: timeZone)
  }

  var body: some View {
    let stats = WeekStats(week: week, sleeps: sleeps, birthDate: child.birthDate, now: now, in: timeZone)
    ZStack {
      Theme.daySkyMid.ignoresSafeArea()
      VStack(spacing: 6) {
        ScrollView {
          VStack(spacing: 12) {
            header
            statCards(stats)
            if stats.hasSleep {
              HoursPerDay(stats: stats, onTap: openSheet)
              TimelineCard(
                name: child.name, rows: Timeline.rows(of: week, sleeps: sleeps, now: now, in: timeZone),
                onTap: openSheet)
            } else {
              emptyCard
            }
          }
          // The arrows start 56 points from the top of the screen, as `.screen.plain` in the gallery.
          .padding(.top, 48)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        TabBar(current: .charts, onSelect: onTab)
      }
      .foregroundStyle(Theme.navy)
      .padding(.horizontal, 20)
      if let openDay {
        daySheet(openDay)
      }
    }
    .contentShape(Rectangle())
    // Simultaneous, so the week swipe does not block the vertical scroll.
    .simultaneousGesture(
      DragGesture(minimumDistance: 30).onEnded { drag in
        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
        move(drag.translation.width < 0 ? 1 : -1)
      }
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("charts")
  }

  private func openSheet(_ day: SleepDay) {
    withAnimation(.easeOut(duration: 0.25)) { openDay = day }
  }

  private func closeSheet() {
    withAnimation(.easeOut(duration: 0.25)) { openDay = nil }
  }

  /// The dimmed charts and the day sheet over them. A tap on the dimmed charts or a swipe down closes it.
  private func daySheet(_ day: SleepDay) -> some View {
    ZStack(alignment: .bottom) {
      Theme.scrim
        .contentShape(Rectangle())
        .onTapGesture(perform: closeSheet)
        .accessibilityElement()
        .accessibilityLabel("Close")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { closeSheet() }
        .accessibilityIdentifier("scrim")
        .transition(.opacity)
      DaySheetView(
        sheet: DaySheet(sleepDay: day, sleeps: sleeps, birthDate: child.birthDate, now: now, in: timeZone),
        onEdit: onEditSleep,
        onAdd: { onAddSleep(DaySheet.startValues(on: day, now: now, in: timeZone)) },
        onClose: closeSheet
      )
      .transition(.move(edge: .bottom))
    }
    .ignoresSafeArea()
  }

  private var header: some View {
    HStack {
      arrow(-1)
      Spacer(minLength: 0)
      VStack(spacing: -8) {
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
    .padding(.vertical, 4)
    .background(RoundedRectangle(cornerRadius: 24).fill(.white))
  }
}

/// "Hours per day": a bar per sleep day over the range band, on a fixed scale of 0 to 16 hours.
/// A tap on a bar opens the day sheet of that day.
private struct HoursPerDay: View {
  let stats: WeekStats
  let onTap: (SleepDay) -> Void

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
      Button {
        onTap(day.sleepDay)
      } label: {
        Group {
          if let judgement = day.judgement {
            shape.fill(Self.color(judgement))
          } else {
            Stripes().clipShape(shape).overlay(shape.strokeBorder(Theme.soFar, lineWidth: 2))
          }
        }
        .frame(height: height)
        .contentShape(shape)
      }
      .buttonStyle(.plain)
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

  static func color(_ judgement: WeekStats.Judgement) -> Color {
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

/// The timeline "When <name> slept": a row per sleep day on a fixed scale of 24 clock hours from 18:00.
/// A tap on a row opens the day sheet of that day, also for a day with no sleeps.
private struct TimelineCard: View {
  let name: String
  let rows: [TimelineRow]
  let onTap: (SleepDay) -> Void

  private static let axis = ["18:00", "00:00", "06:00", "12:00", "18:00"]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("When \(name) slept").balooLine(18, .extraBold, lineHeight: 19)
      ForEach(rows, id: \.sleepDay) { row in
        Button {
          onTap(row.sleepDay)
        } label: {
          HStack(spacing: 8) {
            Text(row.dayName).font(.baloo(14, .bold)).frame(width: 32, alignment: .leading)
            track(row.segments)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("row")
      }
      HStack(spacing: 0) {
        ForEach(Array(Self.axis.enumerated()), id: \.offset) { index, label in
          if index > 0 { Spacer(minLength: 0) }
          Text(label)
        }
      }
      .balooLine(12, lineHeight: 15)
      .padding(.leading, 40)
      .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    .background(RoundedRectangle(cornerRadius: 30).fill(.white))
  }

  private func track(_ segments: [TimelineSegment]) -> some View {
    GeometryReader { geometry in
      let perHour = geometry.size.width / 24
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 8).fill(Theme.track)
        ForEach(segments, id: \.sleepID) { segment in
          RoundedRectangle(cornerRadius: 8)
            .fill(segment.kind == .night ? Theme.navy : Theme.nap)
            .frame(width: max(segment.length * perHour, 2))
            .offset(x: segment.from * perHour)
        }
      }
    }
    .frame(height: 16)
  }
}

/// The day sheet of one sleep day, from `.sheet` in `design/gallery.css`: the day, its total and pill,
/// its sleeps with a pencil each, and "+ Add a sleep to this day". A swipe down closes it.
private struct DaySheetView: View {
  let sheet: DaySheet
  let onEdit: (Sleep) -> Void
  let onAdd: () -> Void
  let onClose: () -> Void

  @State private var drag: CGFloat = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Capsule().fill(Theme.handle).frame(width: 48, height: 6).frame(maxWidth: .infinity)
        .accessibilityHidden(true)
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 0) {
          Text(sheet.title).balooLine(28, .extraBold, lineHeight: 31)
          Text(sheet.summary).balooLine(18, lineHeight: 20)
        }
        Spacer(minLength: 8)
        if let pill = sheet.pill {
          Pill(pill)
        }
      }
      ForEach(sheet.items, id: \.sleep.id) { item in
        sleepItem(item)
      }
      Button("+ Add a sleep to this day", action: onAdd)
        .buttonStyle(DashedButtonStyle())
    }
    .foregroundStyle(Theme.navy)
    .padding(EdgeInsets(top: 12, leading: 22, bottom: 36, trailing: 22))
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32).fill(.white))
    .offset(y: max(0, drag))
    .gesture(
      DragGesture()
        .onChanged { drag = $0.translation.height }
        .onEnded { value in
          if value.translation.height > 60 || value.predictedEndTranslation.height > 160 {
            onClose()
          }
          withAnimation(.easeOut(duration: 0.2)) { drag = 0 }
        }
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("day-sheet")
  }

  private func sleepItem(_ item: DaySheet.Item) -> some View {
    HStack(spacing: 12) {
      Circle().fill(item.sleep.kind == .night ? Theme.navy : Theme.nap).frame(width: 14, height: 14)
      VStack(alignment: .leading, spacing: 0) {
        Text(item.kindName).balooLine(17, .extraBold, lineHeight: 20)
        times(item.times).balooLine(20, .bold, lineHeight: 23)
      }
      Spacer(minLength: 4)
      Text(item.duration).font(.baloo(17, .bold))
      Button {
        onEdit(item.sleep)
      } label: {
        Pencil()
          .stroke(Theme.navy, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
          .frame(width: 24, height: 24)
          .frame(width: 48, height: 48)
          .background(Circle().fill(.white))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(item.editLabel)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(RoundedRectangle(cornerRadius: 22).fill(Theme.track))
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

/// "20:54 → 06:12" with a bold arrow: Baloo 2 has no "→", and the fallback glyph is thin.
private func times(_ text: String) -> Text {
  let parts = text.components(separatedBy: " → ")
  guard parts.count == 2 else { return Text(text) }
  let arrow = Text("→").font(.system(size: 18, weight: .black))
  return Text("\(parts[0]) \(arrow) \(parts[1])")
}

/// The pill in the sheet head: the verdict in the colour of its bar, or a pale "So far".
private struct Pill: View {
  let pill: DaySheet.Pill

  init(_ pill: DaySheet.Pill) { self.pill = pill }

  var body: some View {
    let (text, fill): (String, Color) =
      switch pill {
      case .judgement(.inRange): ("In range", Theme.inRange)
      case .judgement(.tooLittle): ("Too little", Theme.tooLittle)
      case .judgement(.tooMuch): ("Too much", Theme.tooMuch)
      case .soFar: ("So far", .white)
      }
    return Text(text)
      .font(.baloo(15, .extraBold))
      .foregroundStyle(pill == .soFar ? Theme.navy : .white)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(Capsule().fill(fill))
      .overlay(Capsule().strokeBorder(pill == .soFar ? Theme.soFar : .clear, lineWidth: 2))
  }
}

/// "+ Add a sleep to this day": a navy dashed pill, from `.dashed` in `design/gallery.css`.
private struct DashedButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.baloo(18, .bold))
      .foregroundStyle(Theme.navy)
      .frame(maxWidth: .infinity, minHeight: 54)
      .overlay(Capsule().strokeBorder(Theme.navy, style: StrokeStyle(lineWidth: 3, dash: [9, 6])))
      .contentShape(Capsule())
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

/// The pencil of the edit buttons, in a 24 × 24 box: "M4 20h4L19 9l-4-4L4 16v4z".
private struct Pencil: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = rect.width / 24
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
    }
    var path = Path()
    path.move(to: point(4, 20))
    path.addLine(to: point(8, 20))
    path.addLine(to: point(19, 9))
    path.addLine(to: point(15, 5))
    path.addLine(to: point(4, 16))
    path.closeSubpath()
    return path
  }
}
