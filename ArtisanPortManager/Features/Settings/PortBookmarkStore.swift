import Foundation

/// Persists user-assigned aliases and favorites for ports.
///
/// Both are keyed by `PortIdentity` rather than PID so they survive server restarts.
/// Lookup falls back to a port-only key so a bookmark still resolves when the executable
/// path is unavailable (for example a process owned by another user).
@MainActor
final class PortBookmarkStore: ObservableObject {
    private enum Key {
        static let aliases = "portAliases"
        static let favorites = "favoritePorts"
    }

    @Published private(set) var aliases: [String: String]
    @Published private(set) var favorites: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aliases = defaults.dictionary(forKey: Key.aliases) as? [String: String] ?? [:]
        favorites = Set(defaults.stringArray(forKey: Key.favorites) ?? [])
    }

    // MARK: - Aliases

    func alias(for identity: PortIdentity) -> String? {
        aliases[identity.storageKey] ?? aliases[identity.portOnlyKey]
    }

    /// Assigns an alias, or clears it when the trimmed value is empty.
    func setAlias(_ alias: String?, for identity: PortIdentity) {
        let trimmed = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            aliases.removeValue(forKey: identity.storageKey)
            aliases.removeValue(forKey: identity.portOnlyKey)
        } else {
            aliases[identity.storageKey] = trimmed
        }
        defaults.set(aliases, forKey: Key.aliases)
    }

    // MARK: - Favorites

    func isFavorite(_ identity: PortIdentity) -> Bool {
        favorites.contains(identity.storageKey) || favorites.contains(identity.portOnlyKey)
    }

    func toggleFavorite(_ identity: PortIdentity) {
        if isFavorite(identity) {
            favorites.remove(identity.storageKey)
            favorites.remove(identity.portOnlyKey)
        } else {
            favorites.insert(identity.storageKey)
        }
        defaults.set(Array(favorites).sorted(), forKey: Key.favorites)
    }
}
