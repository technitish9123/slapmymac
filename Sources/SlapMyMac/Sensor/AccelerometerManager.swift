import Foundation
import Observation
import CHIDAccelerometer

// ---------------------------------------------------------------------------
// MARK: - AccelSample
// ---------------------------------------------------------------------------

/// A single accelerometer reading with a timestamp.
struct AccelSample: Sendable {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date
}

// ---------------------------------------------------------------------------
// MARK: - AccelerometerManager
// ---------------------------------------------------------------------------

/// Wraps the C HID accelerometer API and exposes an observable, MainActor-bound
/// interface for SwiftUI consumption, plus an AsyncStream for background processing.
@Observable
@MainActor
final class AccelerometerManager {

    // MARK: - Published state

    /// Whether the accelerometer reader is currently running.
    private(set) var isRunning: Bool = false

    /// Whether a compatible accelerometer device was detected on this Mac.
    private(set) var isAvailable: Bool = false

    /// The most recent accelerometer sample (for UI display).
    private(set) var latestSample: AccelSample?

    // MARK: - Stream

    /// Continuous stream of accelerometer samples for consumers like SlapDetector.
    /// A new stream is created each time `start()` is called.
    private(set) var sampleStream: AsyncStream<AccelSample>?

    // MARK: - Private state

    /// Opaque handle returned by HIDAccelCreate; NULL when not running.
    @ObservationIgnored
    private var hidHandle: UnsafeMutableRawPointer?

    /// Continuation backing the current AsyncStream.
    @ObservationIgnored
    private var streamContinuation: AsyncStream<AccelSample>.Continuation?

    // MARK: - Init

    init() {
        // Don't check availability in init — defer to checkAvailability()
        // to avoid IOKit crashes during early app startup.
        self.isAvailable = false
    }

    /// Check if an accelerometer device is available. Call after app is fully launched.
    func checkAvailability() {
        let available = HIDAccelIsAvailable()
        self.isAvailable = available
    }

    deinit {
        // If the manager is deallocated while running, clean up.
        if let handle = hidHandle {
            HIDAccelDestroy(handle)
        }
        streamContinuation?.finish()
    }

    // MARK: - Public API

    /// Begin reading accelerometer data. Creates a fresh AsyncStream.
    func start() {
        guard !isRunning else { return }
        guard isAvailable else { return }

        // Build a new AsyncStream + continuation pair.
        var continuation: AsyncStream<AccelSample>.Continuation!
        let stream = AsyncStream<AccelSample> { cont in
            continuation = cont
        }
        self.sampleStream = stream
        self.streamContinuation = continuation

        // We pass an Unmanaged reference to self through the C callback's context
        // pointer. We use `passRetained` to prevent deallocation while the callback
        // is active; the matching `takeRetainedValue` happens in stop()/deinit.
        let unmanaged = Unmanaged.passRetained(self)
        let context = unmanaged.toOpaque()

        let handle = HIDAccelCreate({ ctx, x, y, z in
            // This closure executes on the HID run-loop thread.
            guard let ctx else { return }
            let mgr = Unmanaged<AccelerometerManager>.fromOpaque(ctx).takeUnretainedValue()

            let sample = AccelSample(x: x, y: y, z: z, timestamp: Date())

            // Yield into the AsyncStream (thread-safe).
            mgr.streamContinuation?.yield(sample)

            // Update the observable latest sample on the main actor.
            Task { @MainActor in
                mgr.latestSample = sample
            }
        }, context)

        if let handle {
            hidHandle = handle
            isRunning = true
        } else {
            // Creation failed; release the retained reference.
            unmanaged.release()
            streamContinuation?.finish()
            streamContinuation = nil
            sampleStream = nil
        }
    }

    /// Stop reading accelerometer data and tear down resources.
    func stop() {
        guard isRunning, let handle = hidHandle else { return }

        HIDAccelDestroy(handle)
        hidHandle = nil
        isRunning = false

        // Finish the stream so consumers exit their for-await loops.
        streamContinuation?.finish()
        streamContinuation = nil
        sampleStream = nil

        // Balance the passRetained from start().
        // We recover the Unmanaged pointer indirectly: since `self` is still alive
        // (we're executing a method on it), we can safely release.
        Unmanaged.passUnretained(self).release()
    }
}
