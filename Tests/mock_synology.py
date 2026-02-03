#!/usr/bin/env python3
"""
Mock Synology Download Station API Server

This mimics Synology's API for testing Magnet Remote without a real NAS.

Usage:
    python3 Tests/mock_synology.py

Then configure Magnet Remote:
    - Host: localhost
    - Port: 5000
    - HTTPS: OFF (for local testing)
    - Username: admin
    - Password: password123

The mock server will:
    1. Validate authentication requests
    2. Accept magnet links
    3. Log all requests for verification
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json
import sys

# Test credentials
VALID_USERNAME = "admin"
VALID_PASSWORD = "password123"
SESSION_ID = "mock_session_12345"

# Track received magnets for verification
received_magnets = []

class SynologyMockHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        """Custom logging with color"""
        print(f"  → {args[0]}")

    def do_GET(self):
        """Handle GET requests (Synology uses GET for everything)"""
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        # Flatten params (parse_qs returns lists)
        params = {k: v[0] if len(v) == 1 else v for k, v in params.items()}

        print(f"\n{'='*50}")
        print(f"📥 {parsed.path}")
        print(f"   Params: {json.dumps(params, indent=2)}")

        # Route to appropriate handler
        if "/webapi/auth.cgi" in self.path:
            self.handle_auth(params)
        elif "/webapi/DownloadStation/task.cgi" in self.path:
            self.handle_task(params)
        else:
            self.send_error_response(f"Unknown endpoint: {parsed.path}")

    def handle_auth(self, params):
        """Handle authentication requests"""
        api = params.get("api", "")
        method = params.get("method", "")

        if api != "SYNO.API.Auth":
            self.send_error_response("Invalid API")
            return

        if method == "login":
            username = params.get("account", "")
            password = params.get("passwd", "")

            print(f"   🔐 Login attempt: {username}")

            if username == VALID_USERNAME and password == VALID_PASSWORD:
                print(f"   ✅ Authentication successful!")
                self.send_json_response({
                    "success": True,
                    "data": {"sid": SESSION_ID}
                })
            else:
                print(f"   ❌ Invalid credentials")
                self.send_json_response({
                    "success": False,
                    "error": {"code": 400}
                })
        else:
            self.send_error_response(f"Unknown auth method: {method}")

    def handle_task(self, params):
        """Handle Download Station task requests"""
        api = params.get("api", "")
        method = params.get("method", "")
        sid = params.get("_sid", "")

        if api != "SYNO.DownloadStation.Task":
            self.send_error_response("Invalid API")
            return

        # Verify session
        if sid != SESSION_ID:
            print(f"   ❌ Invalid session ID: {sid}")
            self.send_json_response({
                "success": False,
                "error": {"code": 105}  # Invalid session
            })
            return

        if method == "create":
            uri = params.get("uri", "")

            if uri.startswith("magnet:"):
                received_magnets.append(uri)
                print(f"   🧲 Received magnet link!")
                print(f"   📝 Total magnets received: {len(received_magnets)}")

                # Extract display name if present
                if "dn=" in uri:
                    dn_start = uri.index("dn=") + 3
                    dn_end = uri.find("&", dn_start)
                    if dn_end == -1:
                        dn_end = len(uri)
                    from urllib.parse import unquote
                    name = unquote(uri[dn_start:dn_end])
                    print(f"   📄 Name: {name}")

                self.send_json_response({"success": True})
            else:
                print(f"   ❌ Invalid URI (not a magnet)")
                self.send_json_response({
                    "success": False,
                    "error": {"code": 400}
                })
        else:
            self.send_error_response(f"Unknown task method: {method}")

    def send_json_response(self, data):
        """Send a JSON response"""
        response = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(response))
        self.end_headers()
        self.wfile.write(response)

    def send_error_response(self, message):
        """Send an error response"""
        print(f"   ❌ Error: {message}")
        self.send_json_response({
            "success": False,
            "error": {"code": 100, "message": message}
        })


def main():
    port = 5000
    server = HTTPServer(("localhost", port), SynologyMockHandler)

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║           Mock Synology Download Station Server              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Server running at: http://localhost:{port}                   ║
║                                                              ║
║  Configure Magnet Remote with:                               ║
║    • Host: localhost                                         ║
║    • Port: {port}                                              ║
║    • HTTPS: OFF                                              ║
║    • Username: {VALID_USERNAME}                                        ║
║    • Password: {VALID_PASSWORD}                                   ║
║                                                              ║
║  Press Ctrl+C to stop                                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
""")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n\n📊 Session Summary:")
        print(f"   Total magnets received: {len(received_magnets)}")
        if received_magnets:
            print(f"   Magnets:")
            for i, m in enumerate(received_magnets, 1):
                print(f"     {i}. {m[:60]}...")
        print("\n👋 Server stopped.")
        sys.exit(0)


if __name__ == "__main__":
    main()
