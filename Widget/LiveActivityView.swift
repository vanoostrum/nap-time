import SwiftUI

/// The Lock Screen view of the placeholder Live Activity.
///
/// The text is static, so its render is the same on every run. The v1 ticket that adds the timer makes it fixed.
struct LiveActivityView: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "moon.stars.fill")
        .font(.title)
        .foregroundStyle(.yellow)
      VStack(alignment: .leading, spacing: 2) {
        Text("Nap Time")
          .font(.headline)
        Text("Asleep since 08:30")
          .font(.subheadline)
      }
      .foregroundStyle(.white)
      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.11, green: 0.13, blue: 0.29))
  }
}
