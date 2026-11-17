import XCTest

/// TEMPORARY (CRAFT-64 proof, never merged): fails on every attempt.
final class TemporaryAlwaysFailsTests: XCTestCase {
  func testFailsOnEveryAttempt() throws {
    XCTFail("Fails on every attempt on purpose")
  }
}
