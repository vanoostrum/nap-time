import ActivityKit
import Core
import SwiftUI
import WidgetKit

@main
struct NapTimeWidgetBundle: WidgetBundle {
  var body: some Widget {
    SleepTimerLiveActivity()
  }
}

/// The sleep timer on the Lock Screen and in the Dynamic Island.
struct SleepTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SleepTimerAttributes.self) { context in
      SleepTimerCard(face(context)) { awake(context) }
        .activityBackgroundTint(SleepTimerColors(context.state.kind, avatarColorIndex: 0).card)
        .activitySystemActionForegroundColor(SleepTimerColors(context.state.kind, avatarColorIndex: 0).ink)
    } dynamicIsland: { context in
      let face = face(context)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          SleepTimerExpanded(face) { awake(context) }
        }
      } compactLeading: {
        SleepTimerIcon(kind: face.kind)
      } compactTrailing: {
        SleepTimerIslandTimer(face: face)
      } minimal: {
        SleepTimerIcon(kind: face.kind)
      }
    }
  }

  private func face(_ context: ActivityViewContext<SleepTimerAttributes>) -> SleepTimerFace {
    SleepTimerFace(
      name: context.attributes.childName, avatarColorIndex: context.attributes.avatarColorIndex,
      start: context.state.start, kind: context.state.kind, timeZone: .current, pauseTime: nil)
  }

  private func awake(_ context: ActivityViewContext<SleepTimerAttributes>) -> some View {
    Button("Awake", intent: EndSleepIntent(childID: context.attributes.childID, sleepID: context.state.sleepID))
  }
}
