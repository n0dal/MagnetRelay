import Foundation

enum MagnetLink {
    static func isMagnet(_ s: String) -> Bool {
        guard let c = URLComponents(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
              c.scheme?.lowercased() == "magnet" else { return false }
        return (c.percentEncodedQueryItems ?? []).contains { $0.name.lowercased() == "xt" }
    }

    static func displayName(from s: String, maxLength: Int = 45) -> String {
        let items = URLComponents(string: s.trimmingCharacters(in: .whitespacesAndNewlines))?.percentEncodedQueryItems ?? []
        func decoded(_ v: String?) -> String? {
            guard let v else { return nil }
            let spaced = v.replacingOccurrences(of: "+", with: " ")
            return spaced.removingPercentEncoding ?? spaced
        }

        var name: String
        if let dn = decoded(items.first { $0.name.lowercased() == "dn" }?.value)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !dn.isEmpty {
            name = dn
        } else if let xt = decoded(items.first { $0.name.lowercased() == "xt" }?.value),
                  let r = xt.range(of: "btih:", options: .caseInsensitive),
                  !xt[r.upperBound...].isEmpty {
            name = String(xt[r.upperBound...].prefix(8)) + "…"
        } else {
            return "Unknown link"
        }

        if name.count > maxLength { name = String(name.prefix(maxLength - 1)) + "…" }
        return name
    }
}
