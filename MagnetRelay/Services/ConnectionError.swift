import Foundation

enum ConnectionError {
    /// Turns an error into a full sentence for the user. Matches on error codes, never on text.
    static func message(for error: Error, client: ClientType) -> String {
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
            case .timeout:
                return timedOut
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
                return "The server's certificate isn't trusted by this Mac. Use a trusted certificate, or HTTPS may not be set up on this port."
            case .notConnectedToInternet:
                return "This Mac isn't connected to a network."
            default: break
            }
        }

        return "Something went wrong: \(error.localizedDescription)"
    }
}
