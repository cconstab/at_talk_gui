# AtTalk Unified GUI/TUI

A unified messaging application built on the atPlatform that supports both graphical (Flutter) and terminal (CLI) interfaces, sharing the same core business logic for consistent behavior across different environments.

## 🌟 Overview

AtTalk is a secure, peer-to-peer messaging application that leverages atSigns for identity and end-to-end encryption. This repository contains a unified codebase that supports:

- **GUI Mode**: Full-featured Flutter application with rich UI
- **TUI Mode**: Terminal-based interface for command-line environments
- **Shared Core**: Common business logic, models, and services used by both interfaces

## 🏗️ Architecture

### Unified Project Structure

```
lib/
├── core/                    # 🔧 Shared business logic
│   ├── models/             # Data models (ChatMessage, Group)
│   ├── services/           # AtClient services and messaging
│   ├── providers/          # State management providers
│   └── utils/              # Shared utilities and environment config
├── gui/                    # 🖼️ Flutter GUI implementation
│   ├── screens/            # GUI screens (onboarding, chat, groups)
│   └── widgets/            # Reusable GUI components
├── tui/                    # 💻 Terminal UI implementation
│   ├── utils/              # TUI-specific utilities
│   └── at_talk_tui.dart    # Main TUI application
├── main.dart               # GUI entry point
bin/
├── at_talk_gui.dart        # GUI executable entry point
└── at_talk_tui.dart        # TUI executable entry point
```

## 🚀 Features

### Core Features (Both GUI & TUI)
- ✅ AtSign authentication and key management
- ✅ Real-time peer-to-peer messaging
- ✅ End-to-end encryption
- ✅ Group messaging and management
- ✅ Conversation history
- ✅ Message notifications
- ✅ Cross-platform support

### GUI-Specific Features
- 🎨 Modern Material Design interface
- 📱 Touch-friendly controls
- 🔐 Visual onboarding flow
- 👥 Rich group management UI
- 📄 File attachment support
- 🌙 Dark/light theme support

### TUI-Specific Features
- 🎨 Colored terminal output
- ⌨️ Command-line argument parsing
- 📊 Real-time message streaming
- 📝 Conversation history commands
- 🔧 Verbose logging options
- 🌐 Cross-platform terminal support

## 📦 Installation & Setup

### Prerequisites
- Flutter SDK (for GUI mode)
- Dart SDK (for TUI mode)
- atSign account and keys

### Dependencies
```yaml
# Core atPlatform
at_client: ^3.4.2
at_client_mobile: ^3.2.18
at_onboarding_flutter: ^6.1.12
at_utils: ^3.0.19

# GUI Framework
flutter:
  sdk: flutter
provider: ^6.1.2

# TUI/CLI
args: ^2.5.0
chalkdart: ^2.0.9
```

### Installation
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd at_talk_gui
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

## 🎮 Usage

### GUI Mode (Flutter Application)

Run the full graphical interface:
```bash
flutter run
```

Or use the executable entry point:
```bash
dart bin/at_talk_gui.dart
```

### TUI Mode (Terminal Interface)

Basic usage:
```bash
dart bin/at_talk_tui.dart -a @yoursign -t @destination
```

#### Command Line Options
- `-a, --atsign`: Your atSign (required)
- `-t, --toatsign`: Destination atSign to chat with (required)
- `-k, --key-file`: Path to atKeys file (optional, defaults to ~/.atsign/keys/)
- `-d, --root-domain`: Root domain (optional, defaults to root.atsign.org)
- `-n, --namespace`: Namespace (optional, defaults to ai6bh)
- `-v, --verbose`: Enable verbose logging
- `--never-sync`: Disable sync completely
- `-h, --help`: Show help message

#### TUI Commands
- `/exit` - Quit the application
- `/history` - Show conversation history
- Type any message to send it
- Real-time incoming messages display automatically

### Example TUI Session
```bash
$ dart bin/at_talk_tui.dart -a @alice -t @bob -v

AtClient initialized successfully!
From: @alice, To: @bob
Commands:
  /exit - quit the application
  /history - show conversation history
  Type any message to send it
──────────────────────────────────────────────────

> Hello Bob!
[14:30] You: Hello Bob!
[14:30] @bob: Hi Alice! How are you?
> /history
Conversation History:
──────────────────────────────────────────────────
[14:30] You: Hello Bob!
[14:30] @bob: Hi Alice! How are you?
──────────────────────────────────────────────────
> /exit
Goodbye!
```

## 🛠️ Development

### Project Creation Story

This unified codebase was created by merging separate GUI and TUI implementations into a single repository with shared core logic. The process involved:

1. **Analysis Phase**: Identified common business logic between GUI and TUI versions
2. **Architecture Design**: Designed unified structure with `lib/core/` for shared components
3. **Code Migration**: Moved models, services, and providers to shared core
4. **Interface Separation**: Organized GUI and TUI specific code into separate directories
5. **Integration**: Updated imports and dependencies to use shared core
6. **Testing**: Ensured both interfaces work with unified business logic
7. **Cleanup**: Removed duplicate files and legacy code

### Key Benefits of Unified Architecture

- **🔄 Consistency**: Both interfaces use identical business logic
- **🛠️ Maintainability**: Single codebase for core functionality
- **🐛 Bug Fixes**: Fixes apply to both GUI and TUI automatically
- **🚀 Feature Parity**: New features can be added to both interfaces
- **📦 Code Reuse**: Maximize shared code, minimize duplication

### Building

For GUI:
```bash
flutter build windows
flutter build macos
flutter build linux
```

For TUI:
```bash
dart compile exe bin/at_talk_tui.dart -o at_talk_tui
```

### Testing

Run Flutter tests:
```bash
flutter test
```

Test TUI functionality:
```bash
dart bin/at_talk_tui.dart --help
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Add new business logic to `lib/core/`
- GUI-specific features go in `lib/gui/`
- TUI-specific features go in `lib/tui/`
- Maintain consistency between GUI and TUI interfaces
- Update both interfaces when adding new core features

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [atPlatform Documentation](https://docs.atsign.com/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)

## 🙏 Acknowledgments

- Built on the atPlatform for secure, decentralized messaging
- Uses Flutter for cross-platform GUI development
- Terminal interface powered by Dart CLI capabilities
- Colored terminal output via chalkdart package

---

**Made with ❤️ using atPlatform technology**

*Secure messaging without compromise - choose your interface!*
