import Foundation

/// Represents a single detected slap event with timing, force, and directional info.
struct SlapEvent: Sendable {
    /// When the slap was detected.
    let timestamp: Date

    /// Normalized force in the range 0.0 (barely detected) to 1.0 (maximum).
    let force: Double

    /// The raw acceleration magnitude that triggered detection, in g-force.
    let rawMagnitude: Double

    /// Which accelerometer axis contributed the most energy to the slap.
    let dominantAxis: Axis

    enum Axis: String, Sendable {
        case x, y, z
    }
}
