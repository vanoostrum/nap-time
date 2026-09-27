import Core
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Nap Time")
                .font(.largeTitle.bold())
            Text(NapDuration.format(seconds: 0))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
