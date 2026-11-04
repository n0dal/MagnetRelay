import Foundation

/// Stores recently added magnet links for quick access
class RecentMagnets: ObservableObject {
    static let shared = RecentMagnets()

    private let maxItems = 5
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
            self.displayName = MagnetLink.displayName(from: magnetURL)
            self.addedAt = Date()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MagnetItem].self, from: data) {
            items = decoded
        }
    }
}
