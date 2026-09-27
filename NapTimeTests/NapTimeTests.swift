import Testing
@testable import NapTime

@MainActor
struct NapTimeTests {
    @Test func contentViewBuilds() {
        _ = ContentView().body
    }
}
