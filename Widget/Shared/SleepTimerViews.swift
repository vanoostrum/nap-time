import Core
import SwiftUI

// The views of the sleep timer, from `live-activity/lock-screen.html`, `live-activity/nap.html`, and
// `live-activity/dynamic-island.html`. They take the "Awake" control as a parameter: the widget passes a button with
// `EndSleepIntent`, and the UI tests a plain button. So they need only SwiftUI and Core.

/// What every view of one timer shows.
struct SleepTimerFace {
  var name: String
  var avatarColorIndex: Int
  var start: Date
  var kind: SleepKind
  /// The time zone of "since 19:42".
  var timeZone: TimeZone
  /// A fixed time that the timer shows, for the UI tests. `nil` counts live.
  var pauseTime: Date?

  var heading: String { "\(name) is sleeping" }
  var since: String { "since \(ClockTime.text(start, in: timeZone))" }
  var initial: String { name.first.map { String($0).uppercased() } ?? "" }
  var isNight: Bool { kind == .night }

  /// "8:28:14" from 1 hour, "45:12" under 1 hour, counting up from the start.
  var timer: Text {
    Text(timerInterval: start...Date.distantFuture, pauseTime: pauseTime, countsDown: false, showsHours: true)
  }
}

/// The colours of a night timer or a nap timer.
struct SleepTimerColors {
  var card: Color
  var ink: Color
  var timer: Color
  var button: Color
  var buttonInk: Color
  var avatar: Color
  var avatarInk: Color
  /// The timer in the Dynamic Island, on black.
  var islandTimer: Color

  init(_ kind: SleepKind, avatarColorIndex: Int) {
    if kind == .night {
      card = Theme.nightSkyMid
      ink = Theme.cream
      timer = Theme.gold
      button = Theme.gold
      buttonInk = Theme.nightSkyMid
      avatar = Theme.avatarColor(at: avatarColorIndex, sky: .night)
      avatarInk = Theme.cream
      islandTimer = Theme.gold
    } else {
      card = Theme.daySkyLow
      ink = Theme.navy
      timer = Theme.navy
      button = Theme.navy
      buttonInk = .white
      avatar = Theme.avatarColor(at: avatarColorIndex, sky: .day)
      avatarInk = Theme.navy
      islandTimer = Theme.nap
    }
  }
}

/// The card on the Lock Screen: the avatar, "Mila is sleeping", the timer, "since 19:42", and "Awake".
struct SleepTimerCard<Awake: View>: View {
  let face: SleepTimerFace
  let awake: Awake

  init(_ face: SleepTimerFace, @ViewBuilder awake: () -> Awake) {
    self.face = face
    self.awake = awake()
  }

  var body: some View {
    let colors = SleepTimerColors(face.kind, avatarColorIndex: face.avatarColorIndex)
    HStack(spacing: 14) {
      SleepTimerAvatar(face: face, size: 52, letterSize: 22)
      VStack(alignment: .leading, spacing: 0) {
        Text(face.heading).balooLine(17, lineHeight: 19)
        face.timer
          .balooLine(34, .extraBold, lineHeight: 37)
          .foregroundStyle(colors.timer)
          .monospacedDigit()
        Text(face.since).balooLine(14, lineHeight: 15)
      }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      awake
        .buttonStyle(SleepTimerAwakeStyle(colors: colors, height: 56, padding: 20, size: 22))
    }
    .foregroundStyle(colors.ink)
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
    .background(colors.card)
  }
}

/// The child's initial on the child's colour, with a ring.
struct SleepTimerAvatar: View {
  let face: SleepTimerFace
  let size: CGFloat
  let letterSize: CGFloat

  var body: some View {
    let colors = SleepTimerColors(face.kind, avatarColorIndex: face.avatarColorIndex)
    Text(face.initial)
      .font(.baloo(letterSize, .extraBold))
      .foregroundStyle(colors.avatarInk)
      .frame(width: size - 6, height: size - 6)
      .background(Circle().fill(colors.avatar))
      .padding(3)
      .overlay(Circle().strokeBorder(colors.avatarInk, lineWidth: 3))
  }
}

/// The "Awake" pill: gold on a night, navy on a nap.
struct SleepTimerAwakeStyle: ButtonStyle {
  let colors: SleepTimerColors
  let height: CGFloat
  let padding: CGFloat
  let size: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.baloo(size, .extraBold))
      .foregroundStyle(colors.buttonInk)
      .padding(.horizontal, padding)
      .frame(height: height)
      .background(Capsule().fill(colors.button))
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}

/// The moon of a night, or the sun of a nap, in the Dynamic Island.
struct SleepTimerIcon: View {
  let kind: SleepKind

  var body: some View {
    if kind == .night {
      Image(systemName: "moon.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Theme.moon)
    } else {
      Image(systemName: "sun.max")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(Theme.sun)
    }
  }
}

/// The timer in the compact Dynamic Island.
struct SleepTimerIslandTimer: View {
  let face: SleepTimerFace

  var body: some View {
    face.timer
      .font(.baloo(17, .extraBold))
      .monospacedDigit()
      .multilineTextAlignment(.trailing)
      .foregroundStyle(SleepTimerColors(face.kind, avatarColorIndex: face.avatarColorIndex).islandTimer)
      .frame(maxWidth: 80, alignment: .trailing)
  }
}

/// The expanded Dynamic Island: the avatar, "Mila is sleeping", the timer, "since 19:42", and "Awake".
struct SleepTimerExpanded<Awake: View>: View {
  let face: SleepTimerFace
  let awake: Awake

  init(_ face: SleepTimerFace, @ViewBuilder awake: () -> Awake) {
    self.face = face
    self.awake = awake()
  }

  var body: some View {
    let colors = SleepTimerColors(face.kind, avatarColorIndex: face.avatarColorIndex)
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        SleepTimerAvatar(face: face, size: 44, letterSize: 20)
        Text(face.heading)
          .balooLine(17, lineHeight: 19)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        face.timer
          .balooLine(30, .extraBold, lineHeight: 33)
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .foregroundStyle(colors.islandTimer)
          .frame(maxWidth: 140, alignment: .trailing)
      }
      HStack {
        Text(face.since).balooLine(15, lineHeight: 17)
        Spacer(minLength: 12)
        awake
          .buttonStyle(SleepTimerAwakeStyle(colors: colors, height: 52, padding: 24, size: 21))
      }
    }
    .foregroundStyle(Theme.cream)
  }
}
