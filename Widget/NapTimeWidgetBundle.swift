import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NapTimeWidgetBundle: WidgetBundle {
  var body: some Widget {
    NapLiveActivity()
  }
}

/// The attributes of the placeholder Live Activity. The v1 plan adds the sleep it tracks.
struct NapActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {}
}

struct NapLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: NapActivityAttributes.self) { _ in
      LiveActivityView()
        .activityBackgroundTint(Color(red: 0.11, green: 0.13, blue: 0.29))
    } dynamicIsland: { _ in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "moon.stars.fill")
            .foregroundStyle(.yellow)
        }
        DynamicIslandExpandedRegion(.center) {
          Text("Nap Time")
            .font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("Asleep since 08:30")
            .font(.subheadline)
        }
      } compactLeading: {
        Image(systemName: "moon.stars.fill")
          .foregroundStyle(.yellow)
      } compactTrailing: {
        Text("08:30")
      } minimal: {
        Image(systemName: "moon.stars.fill")
          .foregroundStyle(.yellow)
      }
    }
  }
}
