import Foundation

enum ConnectionError {
    static let localSynologyCertificate = "Your Synology's certificate isn't trusted by this Mac. On your home network you can turn off Use HTTPS, or install a trusted certificate on the Synology."

    /// Turns an error into a full sentence for the user. Matches on error codes, never on text.
    /// `host` (the configured server host) refines a few messages, e.g. Synology on the home network.
    static func message(for error: Error, client: ClientType, host: String? = nil) -> String {
        let c = client.displayName
        let timedOut = "\(c) didn't answer in time. Check that it's running and reachable from this Mac."

        if let e = error as? BackendError {
            switch e {
            case .invalidURL:
                return "That address doesn't look right. Check it for typos."
            case .authenticationFailed:
                return "\(c) said the username or password is wrong. Check them on its web page and try again."
            case .connectionFailed(let reason):
                return "Couldn't reach \(c): \(reason)"
            case .serverError(let reason):
                return "\(c) couldn't add the link: \(reason)"
            case .insecureConnection:
                return "Synology needs HTTPS for addresses outside your home network."
            case .daemonNotConnected:
                return "Deluge's web page isn't connected to Deluge. Open it in a browser and connect to a host first."
            case .httpStatus(let code):
                switch code {
                case 404: return "\(c) isn't at that address. Check the port and path."
                case 403: return "\(c) refused the connection. Check its web UI security settings."
                case 401: return "\(c) said the username or password is wrong. Check them on its web page and try again."
                default: return "\(c) answered with an unexpected response (HTTP \(code)). Check the address, port and path."
                }
            }
        }

        if let e = error as? URLError {
            switch e.code {
            case .cannotConnectToHost:
                return "Couldn't reach \(c). Check the address and port, and that it's running."
            case .cannotFindHost, .dnsLookupFailed:
                return "Couldn't find that address. Check it for typos."
            case .timedOut:
                return timedOut
            case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .secureConnectionFailed:
                if client == .synology, let host, NetworkAddress.isLocal(host: host) {
                    return localSynologyCertificate
                }
                return "The server's certificate isn't trusted by this Mac. Use a trusted certificate, or HTTPS may not be set up on this port."
            case .appTransportSecurityRequiresSecureConnection:
                return "This address needs HTTPS. Turn on Use HTTPS, or use the server's local IP address."
            case .notConnectedToInternet:
                return "This Mac isn't connected to a network."
            default: break
            }
        }

        return "Something went wrong: \(error.localizedDescription)"
    }
}
