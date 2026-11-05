# Third-party notices

MagnetRelay is MIT-licensed (see [LICENSE](LICENSE)).

**The app bundles no third-party code, libraries, fonts or images.** It is built only on Apple's
system frameworks (SwiftUI, AppKit, Foundation, Security, ServiceManagement, UserNotifications), which
ship with macOS and are not redistributed. The app icon, the magnet mark and all artwork in `assets/`
were made for this project. Text uses the system font, which is not included in this repository.

## Build tools (not shipped)

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the Xcode project from `project.yml`.
  MIT licence. It is a development tool and is not part of the app.

## Services it talks to

MagnetRelay talks only to the download server you configure (qBittorrent, Transmission, Deluge,
rTorrent or Synology Download Station). No code from those projects is included. Their names are
trademarks of their respective owners; see [DISCLAIMER.md](DISCLAIMER.md).

*This is an engineering record, not legal advice.*
