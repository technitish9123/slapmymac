import SwiftUI

struct StatusIcon: View {
    var showSlapAnimation: Bool

    var body: some View {
        Image(systemName: "hand.raised.fill")
            .symbolRenderingMode(.hierarchical)
            .scaleEffect(showSlapAnimation ? 1.4 : 1.0)
            .foregroundStyle(showSlapAnimation ? .red : .primary)
            .animation(
                showSlapAnimation
                    ? .spring(response: 0.15, dampingFraction: 0.3)
                    : .easeOut(duration: 0.2),
                value: showSlapAnimation
            )
            .symbolEffect(.bounce, value: showSlapAnimation)
    }
}
