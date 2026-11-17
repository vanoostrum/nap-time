import UIKit
import XCTest

/// TEMPORARY (CRAFT-64 proof, removed before review): fails on its first attempt and passes on its retry.
/// Each attempt attaches retry-proof.png, which shows the attempt number.
final class TemporaryRetryTests: XCTestCase {
  @MainActor
  func testFailsOnlyOnTheFirstAttempt() throws {
    let counter = FileManager.default.temporaryDirectory.appendingPathComponent("craft-64-attempts")
    let previous = (try? String(contentsOf: counter, encoding: .utf8)).flatMap { Int($0) } ?? 0
    let attempt = previous + 1
    try String(attempt).write(to: counter, atomically: true, encoding: .utf8)

    let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200)).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
      ("attempt \(attempt)" as NSString).draw(
        at: CGPoint(x: 40, y: 70), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 48)])
    }
    let attachment = XCTAttachment(data: image.pngData()!, uniformTypeIdentifier: "public.png")
    attachment.name = "retry-proof.png"
    attachment.lifetime = .keepAlways
    add(attachment)

    XCTAssertGreaterThan(attempt, 1, "Fails on the first attempt on purpose")
  }
}
