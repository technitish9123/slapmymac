import Foundation
import AppKit

print("Step 1: Starting...")

print("Step 2: Bundle.main.bundleIdentifier = \(Bundle.main.bundleIdentifier ?? "nil")")

print("Step 3: Bundle.main.bundleURL = \(Bundle.main.bundleURL)")

let resourceBundlePath = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("SlapMyMac_SlapMyMac.bundle")
print("Step 4: Resource bundle path = \(resourceBundlePath?.path ?? "nil")")
print("Step 4b: Exists = \(FileManager.default.fileExists(atPath: resourceBundlePath?.path ?? ""))")

print("Step 5: Trying NSApplication...")
let app = NSApplication.shared
print("Step 5b: NSApplication OK")

print("Step 6: Setting activation policy...")
app.setActivationPolicy(.accessory)
print("Step 6b: Activation policy OK")

print("Step 7: All basic checks passed! The crash is in SwiftUI.")
print("Done.")
