import SwiftUI
import AppKit

// MARK: - Floating Panel Window

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Window behavior
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.animationBehavior = .default

        // Native macOS titlebar — transparent so content shows through
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        // Use the system vibrant dark appearance
        self.appearance = NSAppearance(named: .vibrantDark)
        self.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.10, alpha: 0.92)
        self.isOpaque = false
        self.hasShadow = true

        // Min/max size
        self.minSize = NSSize(width: 340, height: 500)
        self.maxSize = NSSize(width: 420, height: 900)
    }

    // Allow the window to become key even as a panel
    override func resignKey() {
        super.resignKey()
        // Don't hide — stay visible
    }
}

// MARK: - Visual Effect Hosting View

class VisualEffectHostingView: NSView {
    let hostingView: NSHostingView<AnyView>
    let effectView: NSVisualEffectView

    init<Content: View>(rootView: Content) {
        self.hostingView = NSHostingView(rootView: AnyView(rootView))
        self.effectView = NSVisualEffectView()

        super.init(frame: .zero)

        // Background vibrancy
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        // SwiftUI content on top
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),

            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    var statusItem: NSStatusItem?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create floating panel
        let panelRect = NSRect(x: 0, y: 0, width: 380, height: 740)
        panel = FloatingPanel(contentRect: panelRect)
        panel?.title = "SlapMyMac"

        // SwiftUI content with visual effect background
        let content = MenuBarView()
            .environment(appState)

        let visualHost = VisualEffectHostingView(rootView: content)
        panel?.contentView = visualHost

        // Position top-right of screen
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.maxX - 380 - 40
            let y = sf.maxY - 740 - 40
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Create menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "SlapMyMac")
            button.action = #selector(togglePanel)
            button.target = self
        }

        // Show on launch
        panel?.makeKeyAndOrderFront(nil)

        // Don't show in dock by default
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.makeKeyAndOrderFront(nil)
        return true
    }
}

// MARK: - Main Entry Point

@main
struct SlapMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
