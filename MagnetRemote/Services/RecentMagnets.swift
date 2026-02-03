import Foundation

/// Stores recently added magnet links for quick access
class RecentMagnets: ObservableObject {
    static let shared = RecentMagnets()

    private let maxItems = 10
    private let storageKey = "recentMagnets"

    @Published private(set) var items: [MagnetItem] = []

    struct MagnetItem: Codable, Identifiable {
        let id: UUID
        let magnetURL: String
        let displayName: String
        let addedAt: Date

        init(magnetURL: String) {
            self.id = UUID()
            self.magnetURL = magnetURL
            self.displayName = Self.extractDisplayName(from: magnetURL)
            self.addedAt = Date()
        }

        /// Extract the display name (dn=) from magnet URL, or use truncated hash
        private static func extractDisplayName(from magnetURL: String) -> String {
            // Try to extract dn= parameter
            if let range = magnetURL.range(of: "dn="),
               let endRange = magnetURL[range.upperBound...].firstIndex(of: "&") {
                let encoded = String(magnetURL[range.upperBound..<endRange])
                if let decoded = encoded.removingPercentEncoding {
                    return decoded
                }
            } else if let range = magnetURL.range(of: "dn=") {
                // dn= is the last parameter
                let encoded = String(magnetURL[range.upperBound...])
                if let decoded = encoded.removingPercentEncoding {
                    return decoded
                }
            }

            // Fall back to truncated hash
            if let hashRange = magnetURL.range(of: "btih:") {
                let hashStart = hashRange.upperBound
                let hashEnd = magnetURL[hashStart...].firstIndex(of: "&") ?? magnetURL.endIndex
                let hash = String(magnetURL[hashStart..<hashEnd])
                return String(hash.prefix(8)) + "..."
            }

            return "Unknown Torrent"
        }
    }

    private init() {
        load()
    }

    /// Add a new magnet to the recent list
    func add(_ magnetURL: String) {
        // Remove duplicate if exists
        items.removeAll { $0.magnetURL == magnetURL }

        // Add new item at the beginning
        let item = MagnetItem(magnetURL: magnetURL)
        items.insert(item, at: 0)

        // Trim to max items
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    /// Clear all recent magnets
    func clear() {
        items = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MagnetItem].self, from: data) {
            items = decoded
        }
    }
}
