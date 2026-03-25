import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "SoundPackManager")

/// Discovers and manages both bundled and user-installed sound packs.
@Observable
final class SoundPackManager: @unchecked Sendable {

    // MARK: - Published State

    private(set) var packs: [SoundPack] = []

    /// Maps pack ID -> directory URL where the pack's audio files live.
    private(set) var packDirectories: [String: URL] = [:]

    // MARK: - Initialization

    init() {
        // Don't load packs in init — defer to explicit loadPacks() call
        // to avoid crashes during early app startup.
    }

    // MARK: - Public API

    /// Scans bundled and custom sound directories, populating `packs`.
    func loadPacks() {
        var discovered: [SoundPack] = []
        var directories: [String: URL] = [:]

        // 1. Bundled packs inside the SwiftPM resource bundle (Bundle.module).
        //    Also try Bundle.main for .app bundles.
        let moduleBundle: Bundle? = {
            // Bundle.module can fatalError if the resource bundle is missing.
            // Access it safely by checking the path first.
            let mainPath = Bundle.main.bundleURL.appendingPathComponent("SlapMyMac_SlapMyMac.bundle")
            if let b = Bundle(path: mainPath.path) { return b }
            // Try alongside the executable.
            if let execDir = Bundle.main.executableURL?.deletingLastPathComponent() {
                let buildPath = execDir.appendingPathComponent("SlapMyMac_SlapMyMac.bundle")
                if let b = Bundle(path: buildPath.path) { return b }
            }
            return nil
        }()
        let bundlesToTry: [Bundle] = [moduleBundle, Bundle.main].compactMap { $0 }
        for bundle in bundlesToTry {
            if let soundsURL = bundle.resourceURL?.appendingPathComponent("Sounds"),
               FileManager.default.fileExists(atPath: soundsURL.path) {
                let (bundledPacks, bundledDirs) = scanDirectory(soundsURL)
                discovered.append(contentsOf: bundledPacks)
                directories.merge(bundledDirs) { _, new in new }
                logger.info("Found sounds in bundle: \(bundle.bundlePath)")
                break
            }
        }

        // 2b. Fallback: look relative to the executable (for development).
        if discovered.isEmpty {
            let execURL = Bundle.main.executableURL?.deletingLastPathComponent()
            if let devSoundsURL = execURL?.appendingPathComponent("SlapMyMac_SlapMyMac.bundle/Sounds"),
               FileManager.default.fileExists(atPath: devSoundsURL.path) {
                let (devPacks, devDirs) = scanDirectory(devSoundsURL)
                discovered.append(contentsOf: devPacks)
                directories.merge(devDirs) { _, new in new }
                logger.info("Found sounds in dev bundle path")
            }
        }

        // 2. User custom packs.
        let customURL = customSoundsURL()
        let (customPacks, customDirs) = scanDirectory(customURL)
        discovered.append(contentsOf: customPacks)
        directories.merge(customDirs) { _, new in new }

        packs = discovered
        packDirectories = directories

        logger.info("Loaded \(discovered.count) sound pack(s)")
    }

    /// Returns (and creates if needed) the custom sounds directory.
    func customSoundsURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let customDir = appSupport
            .appendingPathComponent(AppConstants.appName)
            .appendingPathComponent("CustomSounds")

        if !FileManager.default.fileExists(atPath: customDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: customDir,
                    withIntermediateDirectories: true
                )
                logger.info("Created custom sounds directory at \(customDir.path)")
            } catch {
                logger.error("Failed to create custom sounds directory: \(error.localizedDescription)")
            }
        }

        return customDir
    }

    /// Returns the directory URL for a given pack, or nil if unknown.
    func directory(for pack: SoundPack) -> URL? {
        packDirectories[pack.id]
    }

    // MARK: - Private Helpers

    /// Scans a parent directory for subdirectories containing pack.json files.
    private func scanDirectory(_ parentURL: URL) -> ([SoundPack], [String: URL]) {
        var packs: [SoundPack] = []
        var directories: [String: URL] = [:]

        let fm = FileManager.default
        guard fm.fileExists(atPath: parentURL.path) else { return (packs, directories) }

        guard let contents = try? fm.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (packs, directories)
        }

        for url in contents {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let packFile = url.appendingPathComponent("pack.json")
            guard fm.fileExists(atPath: packFile.path) else { continue }

            do {
                let data = try Data(contentsOf: packFile)
                let pack = try JSONDecoder().decode(SoundPack.self, from: data)
                packs.append(pack)
                directories[pack.id] = url
                logger.debug("Discovered pack: \(pack.name) (\(pack.id))")
            } catch {
                logger.warning("Failed to decode pack.json at \(packFile.path): \(error.localizedDescription)")
            }
        }

        return (packs, directories)
    }
}
