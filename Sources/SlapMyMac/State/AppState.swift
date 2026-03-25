import SwiftUI
import Observation
import os.log

private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AppState")

/// Central observable coordinator for the SlapMyMac app.
///
/// Owns the sensor pipeline (AccelerometerManager -> SlapDetector),
/// audio playback (AudioEngine), and sound pack discovery (SoundPackManager).
/// All UI-facing state is published via the Observation framework.
@Observable
@MainActor
final class AppState {

    // MARK: - Subsystems

    let accelerometerManager = AccelerometerManager()
    let slapDetector = SlapDetector()
    let soundPackManager = SoundPackManager()
    let audioEngine = AudioEngine()

    // MARK: - Preferences (synced to UserDefaults via didSet)

    var isEnabled: Bool = false {
        didSet {
            prefs.isEnabled = isEnabled
            if isEnabled { startMonitoring() } else { stopMonitoring() }
        }
    }

    var volume: Double = 0.7 {
        didSet { prefs.volume = volume }
    }

    var sensitivity: Double = 0.5 {
        didSet {
            prefs.sensitivity = sensitivity
            slapDetector.sensitivity = sensitivity
        }
    }

    var selectedPackID: String = "Pain" {
        didSet {
            prefs.selectedPackId = selectedPackID
            loadSelectedPack()
        }
    }

    var totalSlapCount: Int = 0 {
        didSet { prefs.totalSlaps = totalSlapCount }
    }

    // MARK: - Session State

    var sessionSlaps: Int = 0
    var lastSlapForce: Double = 0.0
    var lastSlapTime: Date?
    var isAccelerometerAvailable: Bool = false

    var showSlapAnimation: Bool = false

    // MARK: - UI State

    var showSettings: Bool = false
    var showResetConfirmation: Bool = false
    var showSoundPackDropdown: Bool = false
    var cooldown: Double = 0.3 {
        didSet { prefs.cooldown = cooldown }
    }
    var showInDock: Bool = false {
        didSet {
            prefs.showInDock = showInDock
            NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
        }
    }
    var dynamicMode: Bool = true {
        didSet { prefs.dynamicMode = dynamicMode }
    }

    // MARK: - Computed

    var soundPacks: [SoundPack] {
        soundPackManager.packs
    }

    var selectedPack: SoundPack? {
        soundPacks.first { $0.id == selectedPackID }
    }

    // MARK: - Private

    private var prefs = Preferences()
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Call once at app launch (typically from `onAppear`).
    func initialize() {
        Preferences.registerDefaults()
        loadDefaults()
        soundPackManager.loadPacks()

        // Default selection fallback.
        if soundPacks.first(where: { $0.id == selectedPackID }) == nil,
           let first = soundPacks.first {
            selectedPackID = first.id
        }

        loadSelectedPack()

        accelerometerManager.checkAvailability()
        isAccelerometerAvailable = accelerometerManager.isAvailable
        slapDetector.sensitivity = sensitivity

        print("[APP] Packs loaded: \(soundPacks.count), selected: \(selectedPackID)")
        print("[APP] Accelerometer available: \(isAccelerometerAvailable)")
        print("[APP] isEnabled: \(isEnabled), volume: \(volume), sensitivity: \(sensitivity)")

        if isEnabled {
            startMonitoring()
        }

        logger.info("AppState initialized with \(self.soundPacks.count) packs, selected: \(self.selectedPackID)")
    }

    // MARK: - Sound Pack Loading

    /// Loads the currently selected sound pack into the AudioEngine.
    func loadSelectedPack() {
        guard let pack = selectedPack,
              let directory = soundPackManager.directory(for: pack) else {
            logger.warning("Cannot load selected pack: \(self.selectedPackID) not found")
            return
        }

        audioEngine.loadPack(pack, fromDirectory: directory)
        logger.info("Loaded sound pack: \(pack.name)")
    }

    // MARK: - Slap Registration

    /// Called when the SlapDetector fires. Updates stats, triggers audio, and animates.
    func registerSlap(force: Double) {
        lastSlapForce = force
        lastSlapTime = Date()
        sessionSlaps += 1
        totalSlapCount += 1

        // Play the sound.
        audioEngine.play(force: force, volume: volume)

        // Trigger the visual animation.
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            showSlapAnimation = true
        }

        // Auto-reset the animation flag.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.3)) {
                showSlapAnimation = false
            }
        }

        logger.debug("Slap registered: force=\(String(format: "%.2f", force)), total=\(self.totalSlapCount)")
    }

    func resetStats() {
        sessionSlaps = 0
        totalSlapCount = 0
        lastSlapForce = 0
        lastSlapTime = nil
    }

    // MARK: - Monitoring Pipeline

    /// Starts the accelerometer -> slap detection -> audio playback pipeline.
    private func startMonitoring() {
        // Cancel any existing task first.
        stopMonitoring()

        accelerometerManager.start()
        print("[APP] Accelerometer started, isRunning: \(accelerometerManager.isRunning)")

        guard let sampleStream = accelerometerManager.sampleStream else {
            print("[APP] ERROR: Failed to obtain accelerometer sample stream")
            logger.error("Failed to obtain accelerometer sample stream")
            return
        }

        print("[APP] Got sample stream, starting monitoring loop...")
        let detector = slapDetector
        var sampleCount = 0
        monitoringTask = Task { [weak self] in
            print("[APP] Monitoring task started")

            for await sample in sampleStream {
                guard !Task.isCancelled else { break }
                sampleCount += 1
                if sampleCount <= 3 || sampleCount % 500 == 0 {
                    print("[APP] Sample #\(sampleCount): x=\(String(format: "%.3f", sample.x)) y=\(String(format: "%.3f", sample.y)) z=\(String(format: "%.3f", sample.z))")
                }

                if let event = detector.processSample(sample) {
                    print("[APP] SLAP DETECTED! force=\(String(format: "%.2f", event.force))")
                    await MainActor.run {
                        self?.registerSlap(force: event.force)
                    }
                }
            }

            logger.info("Monitoring loop exited")
        }
    }

    /// Stops the monitoring pipeline.
    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        accelerometerManager.stop()
        slapDetector.reset()

        logger.info("Monitoring disabled")
    }

    // MARK: - Persistence

    private func loadDefaults() {
        let savedEnabled = prefs.isEnabled
        let savedVolume = prefs.volume
        let savedSensitivity = prefs.sensitivity
        let savedPackID = prefs.selectedPackId
        let savedSlaps = prefs.totalSlaps
        let savedCooldown = prefs.cooldown
        let savedShowInDock = prefs.showInDock
        let savedDynamicMode = prefs.dynamicMode

        isEnabled = savedEnabled
        volume = savedVolume
        sensitivity = savedSensitivity
        selectedPackID = savedPackID
        totalSlapCount = savedSlaps
        cooldown = savedCooldown
        showInDock = savedShowInDock
        dynamicMode = savedDynamicMode
    }

    /// Tears down monitoring when the app state is deallocated.
    /// Uses `nonisolated` to satisfy Swift concurrency requirements for deinit.
    nonisolated func tearDown() {
        // Called explicitly before the object goes away, since deinit
        // cannot access MainActor-isolated properties.
        Task { @MainActor [weak self] in
            self?.stopMonitoring()
        }
    }
}
