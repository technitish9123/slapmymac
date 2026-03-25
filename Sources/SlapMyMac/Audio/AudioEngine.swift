import AVFoundation
import Observation
import os.log

private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AudioEngine")

/// Manages audio playback for the active sound pack.
/// Supports packs with multiple MP3/WAV/AIFF files — plays a random one on each trigger.
/// Uses a small player pool to allow overlapping sounds.
@Observable
@MainActor
final class AudioEngine {

    // MARK: - State

    private(set) var isLoaded: Bool = false
    private(set) var loadedPackId: String?

    // MARK: - Player Pool

    /// All pre-loaded players for the current pack, keyed by filename.
    private var players: [String: AVAudioPlayer] = [:]

    /// Ordered list of filenames for random/sequential access.
    private var fileNames: [String] = []

    /// Pool of extra players for overlapping playback.
    private var overlapPool: [AVAudioPlayer] = []
    private var overlapIndex: Int = 0
    private let overlapPoolSize = 4

    /// For "Sexy" mode: escalating index based on slap frequency.
    private var sexyIndex: Int = 0

    // MARK: - Public API

    /// Loads all audio files from a sound pack directory.
    func loadPack(_ pack: SoundPack, fromDirectory directory: URL) {
        unload()

        var loaded: [String: AVAudioPlayer] = [:]
        var names: [String] = []

        for filename in pack.files {
            let fileURL = directory.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logger.warning("Audio file not found: \(filename)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: fileURL)
                player.prepareToPlay()
                loaded[filename] = player
                names.append(filename)
            } catch {
                logger.error("Failed to load \(filename): \(error.localizedDescription)")
            }
        }

        players = loaded
        fileNames = names
        loadedPackId = pack.id
        isLoaded = !players.isEmpty
        sexyIndex = 0

        // Build overlap pool from first file for rapid-fire scenarios.
        overlapPool = []
        if let firstFile = names.first, let url = urlForFile(firstFile, in: directory) {
            for _ in 0..<overlapPoolSize {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    overlapPool.append(p)
                }
            }
        }

        logger.info("Loaded pack \"\(pack.name)\" with \(names.count) sound(s)")
    }

    /// Play a sound from the current pack.
    /// - Parameters:
    ///   - force: Normalized slap force [0, 1]. For "Sexy" packs, higher force = higher index.
    ///   - volume: User-configured volume [0, 1].
    func play(force: Double, volume: Double) {
        guard isLoaded, !fileNames.isEmpty else { return }

        // Pick which file to play.
        let filename: String
        if loadedPackId == "Sexy" {
            // Escalating mode: pick file based on cumulative index.
            filename = fileNames[sexyIndex % fileNames.count]
            sexyIndex = min(sexyIndex + 1, fileNames.count - 1)
        } else {
            // Random selection.
            filename = fileNames.randomElement()!
        }

        guard let player = players[filename] else { return }

        let effectiveVolume = Float(min(max(volume * max(force, 0.3), 0.1), 1.0))

        if player.isPlaying {
            // Use overlap pool.
            let overlapPlayer = overlapPool[overlapIndex % max(overlapPool.count, 1)]
            overlapIndex += 1
            overlapPlayer.volume = effectiveVolume
            overlapPlayer.currentTime = 0
            overlapPlayer.play()
        } else {
            player.volume = effectiveVolume
            player.currentTime = 0
            player.play()
        }
    }

    /// Reset the escalation index (for Sexy mode).
    func resetEscalation() {
        sexyIndex = 0
    }

    /// Unloads all players.
    func unload() {
        for (_, player) in players { player.stop() }
        for player in overlapPool { player.stop() }
        players.removeAll()
        fileNames.removeAll()
        overlapPool.removeAll()
        isLoaded = false
        loadedPackId = nil
        sexyIndex = 0
    }

    // MARK: - Private

    private func urlForFile(_ filename: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
