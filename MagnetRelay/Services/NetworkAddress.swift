import Foundation

enum NetworkAddress {
    /// True for loopback, link-local, private-range and `.local` hosts.
    static func isLocal(host: String) -> Bool {
        var h = host.trimmed.lowercased()
        if h.hasPrefix("["), h.hasSuffix("]") { h = String(h.dropFirst().dropLast()) }
        if h == "localhost" || h.hasSuffix(".local") || h == "::1" { return true }
        if h.hasPrefix("fe8") || h.hasPrefix("fe9") || h.hasPrefix("fea") || h.hasPrefix("feb"), h.contains(":") { return true }

        // Single-label names (e.g. "diskstation") only resolve on the local network.
        if !h.contains("."), !h.contains(":"), !h.isEmpty { return true }

        let parts = h.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 != nil && (0...255).contains($0!) }) else { return false }
        let o = parts.map { $0! }
        switch (o[0], o[1]) {
        case (127, _), (10, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        default: return false
        }
    }
}
