import Core
import SwiftUI

/// Which sleep form to show, with its one input.
enum SleepFormMode {
  /// "Add a sleep", with the start values that the caller gives.
  case new(SleepStartValues, childID: Child.ID)
  /// "Edit sleep" for a sleep that has ended, with "Delete this sleep".
  case edit(Sleep)
  /// "Woke earlier?" for the running sleep: saving ends it.
  case wokeEarlier(Sleep)
  /// "Edit sleep" for the running sleep: saving keeps it running.
  case runningStart(Sleep)

  var childID: Child.ID {
    switch self {
    case .new(_, let childID): childID
    case .edit(let sleep), .wokeEarlier(let sleep), .runningStart(let sleep): sleep.childID
    }
  }
}

/// The form to add, edit, or end a sleep: the type, "Fell asleep", and "Woke up".
/// The Core save rule runs on every change; while it finds a problem, the reason shows in red and the button is grey.
struct SleepFormView: View {
  let mode: SleepFormMode
  let child: Child
  /// The saved sleeps of the child.
  let sleeps: [Sleep]
  let now: Date
  let calendar: Calendar
  /// The child is only on this phone, so a delete reaches only this phone.
  var onlyOnThisPhone = false
  let onSave: (Sleep) throws -> Void
  var onCancel: () -> Void = {}
  var onDelete: (Sleep) throws -> Void = { _ in }

  @State private var id: Sleep.ID
  @State private var start: Date
  /// `nil` while the sleep keeps running.
  @State private var end: Date?
  /// The type the parent tapped, or the saved type. `nil` follows the guess from "Fell asleep".
  @State private var chosenKind: SleepKind?
  @State private var picking: Field?
  @State private var draft = Date()
  @State private var confirmsDelete = false
  @State private var errorText: String?

  private enum Field: String, Identifiable {
    case fellAsleep
    case wokeUp
    var id: String { rawValue }
  }

  init(
    mode: SleepFormMode, child: Child, sleeps: [Sleep], now: Date, calendar: Calendar, onlyOnThisPhone: Bool = false,
    onSave: @escaping (Sleep) throws -> Void, onCancel: @escaping () -> Void = {},
    onDelete: @escaping (Sleep) throws -> Void = { _ in }
  ) {
    self.mode = mode
    self.child = child
    self.sleeps = sleeps
    self.now = now
    self.calendar = calendar
    self.onlyOnThisPhone = onlyOnThisPhone
    self.onSave = onSave
    self.onCancel = onCancel
    self.onDelete = onDelete
    switch mode {
    case .new(let values, _):
      _id = State(initialValue: UUID())
      _start = State(initialValue: values.fellAsleep)
      _end = State(initialValue: values.wokeUp)
      _chosenKind = State(initialValue: nil)
    case .edit(let sleep):
      _id = State(initialValue: sleep.id)
      _start = State(initialValue: sleep.start)
      _end = State(initialValue: sleep.end ?? now)
      _chosenKind = State(initialValue: sleep.kind)
    case .wokeEarlier(let sleep):
      // The pickers are to the minute, so "Woke up" starts at now without its seconds.
      let minute = calendar.dateInterval(of: .minute, for: now)?.start ?? now
      _id = State(initialValue: sleep.id)
      _start = State(initialValue: sleep.start)
      _end = State(initialValue: minute)
      _chosenKind = State(initialValue: sleep.kind)
    case .runningStart(let sleep):
      _id = State(initialValue: sleep.id)
      _start = State(initialValue: sleep.start)
      _end = State(initialValue: nil)
      _chosenKind = State(initialValue: sleep.kind)
    }
  }

  private var timeZone: TimeZone { calendar.timeZone }
  private var kind: SleepKind { chosenKind ?? SleepKind.guess(start: start, in: timeZone) }
  private var edited: Sleep { Sleep(id: id, childID: child.id, start: start, end: end, kind: kind) }
  private var problem: SleepProblem? { SleepSaveRule.problem(of: edited, among: sleeps, now: now) }

  private var title: String {
    switch mode {
    case .new: "Add a sleep"
    case .edit, .runningStart: "Edit sleep"
    case .wokeEarlier: "Woke earlier?"
    }
  }

  private var isNew: Bool {
    if case .new = mode { true } else { false }
  }

  private var savedSleep: Sleep? {
    if case .edit(let sleep) = mode { sleep } else { nil }
  }

  var body: some View {
    ZStack {
      Theme.daySkyMid.ignoresSafeArea()
      VStack(spacing: 12) {
        header
        typeField
        fellAsleepField
        wokeUpField
        buttons
          .opacity(confirmsDelete ? 0 : 1)
          .accessibilityHidden(confirmsDelete)
        Spacer(minLength: 0)
      }
      .foregroundStyle(Theme.navy)
      .padding(.horizontal, 20)
      if confirmsDelete, let savedSleep {
        deleteConfirmation(savedSleep)
      }
    }
    .sheet(item: $picking) { field in timeSheet(field) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sleep-form")
  }

  // MARK: Parts

  private var header: some View {
    HStack(spacing: 12) {
      Button("Cancel", action: onCancel)
        .font(.baloo(19, .bold))
        .frame(minWidth: 64, alignment: .leading)
        .accessibilityIdentifier("cancel")
      Text(title)
        .font(.baloo(30, .extraBold))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
      Color.clear.frame(width: 64, height: 1)
    }
    .frame(minHeight: 44)
  }

  private var typeField: some View {
    VStack(alignment: .leading, spacing: 4) {
      label("Type")
      HStack(spacing: 8) {
        segment(.night, title: "Night")
        segment(.nap, title: "Nap")
      }
      .padding(6)
      .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
  }

  private func segment(_ value: SleepKind, title: String) -> some View {
    let selected = kind == value
    return Button {
      chosenKind = value
    } label: {
      Text(title)
        .font(.baloo(20, .bold))
        .foregroundStyle(selected ? .white : Theme.navy)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Theme.navy : .clear))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var fellAsleepField: some View {
    VStack(alignment: .leading, spacing: 4) {
      label("Fell asleep")
      timeButton(.fellAsleep, start)
      if case .runningStart = mode {
        hint("Saving keeps the sleep running.")
      }
    }
  }

  private var wokeUpField: some View {
    VStack(alignment: .leading, spacing: 4) {
      label("Woke up")
      if let end {
        timeButton(.wokeUp, end)
      } else {
        Text("Still asleep")
          .font(.baloo(22, .bold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18)
          .frame(height: 58)
          .background(.white, in: RoundedRectangle(cornerRadius: 20))
      }
      if let problem {
        Text(problem.text(childName: child.name, in: timeZone))
          .font(.baloo(14, .bold))
          .foregroundStyle(Theme.tooLittle)
          .padding(.leading, 6)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("problem")
      } else {
        hint(durationHint)
      }
      if let errorText {
        Text(errorText)
          .font(.baloo(14, .bold))
          .foregroundStyle(Theme.tooLittle)
          .padding(.leading, 6)
      }
    }
  }

  /// "1 h 00 m of sleep", "2 h 14 m of sleep. Mila is awake after you save.", or "2 h 36 m so far".
  private var durationHint: String {
    let duration = SleepDuration.text((end ?? now).timeIntervalSince(start))
    switch mode {
    case .new, .edit: return "\(duration) of sleep"
    case .wokeEarlier: return "\(duration) of sleep. \(child.name) is awake after you save."
    case .runningStart: return "\(duration) so far"
    }
  }

  private func label(_ text: String) -> some View {
    Text(text)
      .font(.baloo(16, .bold))
      .padding(.leading, 6)
  }

  private func hint(_ text: String) -> some View {
    Text(text)
      .font(.baloo(14))
      .padding(.leading, 6)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func timeButton(_ field: Field, _ value: Date) -> some View {
    Button {
      draft = min(max(value, earliest), now)
      picking = field
    } label: {
      HStack {
        Text(SleepFormTime.text(value, in: timeZone))
        Spacer(minLength: 8)
        Chevron()
          .stroke(Theme.navy, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
          .frame(width: 18, height: 18)
          .accessibilityHidden(true)
      }
      .font(.baloo(22, .bold))
      .foregroundStyle(Theme.navy)
      .padding(.horizontal, 18)
      .frame(height: 58)
      .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    .accessibilityLabel(SleepFormTime.text(value, in: timeZone))
    .accessibilityIdentifier(field == .fellAsleep ? "fell-asleep" : "woke-up")
  }

  private var buttons: some View {
    VStack(spacing: 12) {
      Button(isNew ? "Add sleep" : "Save") { save() }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(problem != nil)
        .accessibilityIdentifier("save")
      if savedSleep != nil {
        Button("Delete this sleep") { confirmsDelete = true }
          .font(.baloo(19, .bold))
          .foregroundStyle(Theme.tooLittle)
          .padding(8)
          .accessibilityIdentifier("delete")
      }
    }
  }

  /// The earliest time a picker allows: the start of the child's birthdate.
  private var earliest: Date { child.birthDate.date(in: calendar) }

  private func timeSheet(_ field: Field) -> some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button("Done") {
          if field == .fellAsleep { start = draft } else { end = draft }
          picking = nil
        }
        .font(.baloo(19, .bold))
        .foregroundStyle(Theme.navy)
      }
      DatePicker(
        field == .fellAsleep ? "Fell asleep" : "Woke up", selection: $draft, in: earliest...now,
        displayedComponents: [.date, .hourAndMinute]
      )
      .datePickerStyle(.wheel)
      .labelsHidden()
    }
    .padding(20)
    .environment(\.calendar, calendar)
    .environment(\.timeZone, timeZone)
    .environment(\.locale, calendar.locale ?? Locale(identifier: "en_GB"))
    .presentationDetents([.height(320)])
  }

  private func deleteConfirmation(_ sleep: Sleep) -> some View {
    ZStack(alignment: .bottom) {
      Theme.scrim.ignoresSafeArea()
      VStack(spacing: 10) {
        Text("Delete this sleep?")
          .font(.baloo(26, .extraBold))
          .accessibilityAddTraits(.isHeader)
        Text(DeleteText.sleep(sleep, name: child.name, onlyOnThisPhone: onlyOnThisPhone, now: now, in: timeZone))
          .font(.baloo(17))
        Button("Delete sleep") { delete(sleep) }
          .buttonStyle(PrimaryButtonStyle(destructive: true))
          .padding(.top, 6)
          .accessibilityIdentifier("confirm-delete")
        Button("Cancel") { confirmsDelete = false }
          .font(.baloo(19, .bold))
          .padding(8)
          .accessibilityIdentifier("confirm-cancel")
      }
      .foregroundStyle(Theme.navy)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(EdgeInsets(top: 22, leading: 20, bottom: 16, trailing: 20))
      .background(.white, in: RoundedRectangle(cornerRadius: 30))
      .padding(.horizontal, 12)
    }
  }

  // MARK: Actions

  private func save() {
    guard problem == nil else { return }
    do {
      try onSave(edited)
    } catch {
      errorText = "Nap Time could not save this. Try again."
    }
  }

  private func delete(_ sleep: Sleep) {
    do {
      try onDelete(sleep)
    } catch {
      confirmsDelete = false
      errorText = "Nap Time could not delete this. Try again."
    }
  }
}

/// The gallery's chevron, in a 24 × 24 box: M9 6l6 6-6 6.
private struct Chevron: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = rect.width / 24
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 9 * scale, y: rect.minY + 6 * scale))
    path.addLine(to: CGPoint(x: rect.minX + 15 * scale, y: rect.minY + 12 * scale))
    path.addLine(to: CGPoint(x: rect.minX + 9 * scale, y: rect.minY + 18 * scale))
    return path
  }
}
