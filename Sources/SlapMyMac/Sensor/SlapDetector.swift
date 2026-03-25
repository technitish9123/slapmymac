import Foundation
import Observation

/// Detects physical slap events from accelerometer data.
///
/// Uses deviation from baseline gravity to detect impacts.
/// At rest, the accelerometer reads ~(0, 0, -1.0) due to gravity.
/// A slap causes a sudden spike in acceleration magnitude above the baseline.
@Observable
final class SlapDetector {

    // MARK: - Configuration

    /// Detection sensitivity from 0.0 (least sensitive) to 1.0 (most sensitive).
    /// Maps to a minimum amplitude threshold.
    var sensitivity: Double = 0.5

    // MARK: - Observable output

    private(set) var lastDetectedSlap: SlapEvent?

    // MARK: - Internal state

    /// Running baseline magnitude (gravity-compensated).
    private var baselineMag: Double = 1.0

    /// Exponential moving average factor for baseline.
    private let baselineAlpha: Double = 0.001

    /// Timestamp of the last detected slap.
    private var lastSlapTime: Date = .distantPast

    /// Minimum interval between successive slap detections.
    private let cooldownInterval: TimeInterval = 0.3

    /// Number of samples processed (for warmup).
    private var sampleCount: Int = 0

    /// Warmup period before detection starts.
    private let warmupSamples: Int = 50

    // MARK: - Public API

    func processSample(_ sample: AccelSample) -> SlapEvent? {
        sampleCount += 1

        let magnitude = sqrt(
            sample.x * sample.x +
            sample.y * sample.y +
            sample.z * sample.z
        )

        // Update baseline with slow EMA (tracks gravity, ignores spikes).
        if sampleCount < warmupSamples {
            // During warmup, converge faster.
            baselineMag = baselineMag * 0.9 + magnitude * 0.1
            return nil
        }

        // Deviation from baseline (how much above normal gravity).
        let deviation = abs(magnitude - baselineMag)

        // Update baseline slowly (only when not in a spike).
        if deviation < 0.05 {
            baselineMag = baselineMag * (1.0 - baselineAlpha) + magnitude * baselineAlpha
        }

        // Map sensitivity [0, 1] to threshold:
        // 1.0 (most sensitive) -> 0.05g
        // 0.5 (default)        -> 0.15g
        // 0.0 (least sensitive) -> 0.30g
        let clampedSensitivity = min(max(sensitivity, 0.0), 1.0)
        let threshold = 0.30 - clampedSensitivity * 0.25  // 0.30 -> 0.05

        guard deviation > threshold else { return nil }

        // Cooldown check.
        let now = Date()
        guard now.timeIntervalSince(lastSlapTime) >= cooldownInterval else { return nil }

        // Determine dominant axis.
        let absX = abs(sample.x)
        let absY = abs(sample.y)
        let absZ = abs(sample.z - (-1.0))  // Deviation from gravity on Z.

        let dominantAxis: SlapEvent.Axis
        if absX >= absY && absX >= absZ {
            dominantAxis = .x
        } else if absY >= absX && absY >= absZ {
            dominantAxis = .y
        } else {
            dominantAxis = .z
        }

        // Normalize force: map deviation to [0, 1].
        // threshold = barely detected, threshold * 5 = maximum force.
        let force = min(max((deviation - threshold) / (threshold * 4.0), 0.0), 1.0)

        let event = SlapEvent(
            timestamp: now,
            force: force,
            rawMagnitude: magnitude,
            dominantAxis: dominantAxis
        )

        lastSlapTime = now
        lastDetectedSlap = event

        print("[SLAP] deviation=\(String(format: "%.4f", deviation))g threshold=\(String(format: "%.4f", threshold))g force=\(String(format: "%.2f", force)) mag=\(String(format: "%.4f", magnitude))")

        return event
    }

    func reset() {
        baselineMag = 1.0
        sampleCount = 0
        lastSlapTime = .distantPast
        lastDetectedSlap = nil
    }
}
