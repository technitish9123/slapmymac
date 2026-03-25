import Foundation

// MARK: - Sound Pack

struct SoundPack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String       // SF Symbol name
    let description: String
    let files: [String]    // List of audio filenames (mp3/wav/aiff)

    // MARK: Hashable

    static func == (lhs: SoundPack, rhs: SoundPack) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
