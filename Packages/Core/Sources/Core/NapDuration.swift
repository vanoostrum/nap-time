/// Pure, platform-independent formatting for nap durations.
/// Lives in `Core` so it can be tested with `swift test` (also on Linux).
public enum NapDuration {
    /// Formats a duration as `H:MM:SS` (or `M:SS` under an hour). Negative input is clamped to zero.
    public static func format(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(pad(minutes)):\(pad(secs))"
        }
        return "\(minutes):\(pad(secs))"
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
