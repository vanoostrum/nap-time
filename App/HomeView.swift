import SwiftUI

/// The placeholder home screen. The v1 plan replaces it.
struct HomeView: View {
  var body: some View {
    ZStack {
      Color(.systemBackground).ignoresSafeArea()
      Text("Nap Time")
        .font(.largeTitle.bold())
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("home")
  }
}

#Preview {
  HomeView()
}
