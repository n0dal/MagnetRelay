#!/usr/bin/env python3
"""
Window capture helper for MagnetRemote screenshots.

Uses macOS Quartz framework to get proper window IDs for screenshot capture
with rounded corners and shadows preserved.

Usage:
    python3 window_capture.py --get-id              # Print window ID
    python3 window_capture.py --capture output.png  # Capture window to file
    python3 window_capture.py --capture output.png --no-shadow  # Without shadow

Requirements:
    pip3 install pyobjc-framework-Quartz
"""

import argparse
import subprocess
import sys

try:
    import Quartz
except ImportError:
    print("Installing required package: pyobjc-framework-Quartz", file=sys.stderr)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pyobjc-framework-Quartz"])
    import Quartz


def get_magnetremote_window_id():
    """Find the main MagnetRemote window ID."""
    window_list = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
        Quartz.kCGNullWindowID
    )

    main_wid = None
    max_area = 0

    for window in window_list:
        owner = window.get('kCGWindowOwnerName', '')
        # Match "Magnet Remote" (the app's display name)
        if owner != 'Magnet Remote':
            continue

        bounds = window.get('kCGWindowBounds', {})
        width = bounds.get('Width', 0)
        height = bounds.get('Height', 0)
        area = width * height

        # Skip tiny windows (like the empty SwiftUI window)
        if area > max_area and width > 100 and height > 100:
            max_area = area
            main_wid = window.get('kCGWindowNumber', 0)

    return main_wid


def capture_window(output_path, include_shadow=True):
    """Capture the MagnetRemote window to a file."""
    window_id = get_magnetremote_window_id()

    if not window_id:
        print("Error: MagnetRemote window not found", file=sys.stderr)
        return False

    # Build screencapture command
    # -l<windowID>  Capture specific window
    # -o            Exclude shadow (optional)
    # -x            No sound
    cmd = ["screencapture", f"-l{window_id}", "-x"]

    if not include_shadow:
        cmd.append("-o")

    cmd.append(output_path)

    result = subprocess.run(cmd, capture_output=True)

    if result.returncode == 0:
        print(f"Captured window {window_id} to {output_path}")
        return True
    else:
        print(f"Error capturing window: {result.stderr.decode()}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="MagnetRemote window capture helper")
    parser.add_argument("--get-id", action="store_true", help="Print window ID only")
    parser.add_argument("--capture", metavar="FILE", help="Capture window to file")
    parser.add_argument("--no-shadow", action="store_true", help="Exclude window shadow")

    args = parser.parse_args()

    if args.get_id:
        wid = get_magnetremote_window_id()
        if wid:
            print(wid)
            sys.exit(0)
        else:
            print("Window not found", file=sys.stderr)
            sys.exit(1)

    elif args.capture:
        success = capture_window(args.capture, include_shadow=not args.no_shadow)
        sys.exit(0 if success else 1)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
