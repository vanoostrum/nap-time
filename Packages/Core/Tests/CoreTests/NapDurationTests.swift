import Testing
@testable import Core

struct NapDurationTests {
    @Test(arguments: [
        (0, "0:00"),
        (59, "0:59"),
        (61, "1:01"),
        (3600, "1:00:00"),
        (5025, "1:23:45"),
        (-5, "0:00")
    ])
    func formats(seconds: Int, expected: String) {
        #expect(NapDuration.format(seconds: seconds) == expected)
    }
}
