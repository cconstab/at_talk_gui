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
- ✅ Multi-instance support with automatic storage conflict resolution
- ✅ Robust resource cleanup and signal handling

### GUI-Specific Features
- 🎨 Modern Material Design interface
- 📱 Touch-friendly controls
- 🔐 Visual onboarding flow
- 👥 Rich group management UI
- 🔧 AtKeys file management and backup
- ⚙️ Settings and preferences
- 🔄 Automatic ephemeral storage fallback for multi-instance scenarios

### TUI-Specific Features
- 🎨 Colored terminal output
- ⌨️ Command-line argument parsing
- 📊 Real-time message streaming
- 🔧 Multi-session chat management
- 🔧 Verbose logging options
- 🌐 Cross-platform terminal support
- 👥 Interactive group management commands
- ⚡ Ephemeral storage for one-shot message mode (`-m` flag)
- 🛡️ Signal handlers for graceful cleanup (Ctrl+C, SIGTERM)

### Platform Compatibility
- **Windows**: Full support with PowerShell, Command Prompt, or Windows Terminal
- **macOS/Linux**: Full support with any ANSI-compatible terminal
- **Input Handling**: Uses Enter key for all panel confirmations (Escape key may not work consistently on Windows)
- **Terminal Colors**: Automatically adapts to terminal capabilities
- **Multi-Instance**: Both GUI and TUI can run simultaneously without storage conflicts

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

#### Interactive Mode
Basic usage for interactive chat:
```bash
dart bin/at_talk_tui.dart -a @yoursign -t @destination
```

#### Non-Interactive Mode  
Send a single message and exit:
```bash
dart bin/at_talk_tui.dart -a @yoursign -t @destination -m "Your message here"
```

For group messages, separate multiple recipients with commas:
```bash
dart bin/at_talk_tui.dart -a @yoursign -t @alice,@bob,@charlie -m "Group message"
```

#### Command Line Options
- `-a, --atsign`: Your atSign (required)
- `-t, --toatsign`: Destination atSign to chat with (required)
- `-k, --key-file`: Path to atKeys file (optional, defaults to ~/.atsign/keys/)
- `-d, --root-domain`: Root domain (optional, defaults to root.atsign.org)
- `-n, --namespace`: Namespace (optional, defaults to ai6bh)
- `-m, --message`: Send a message then exit (non-interactive mode, uses ephemeral storage)
- `-v, --verbose`: Enable verbose logging
- `--never-sync`: Disable sync completely
- `--ephemeral`: Force ephemeral storage mode (no persistent storage)
- `-h, --help`: Show help message

#### TUI Interactive Commands
Once in the TUI, you can use these commands:
- `/?` - Show help panel with all commands
- `/switch @other` - Switch to chat with @other
- `/new @other` - Start new chat with @other (individuals or groups)
- `/add @other` - Add participant to current group
- `/remove @other` - Remove participant from current group
- `/rename name` - Rename current group
- `/delete` - Delete current session
- `/list` - Show participants panel (interactive: `r` rename group, `a` add participant, `d` remove participant, `j`/`k` scroll, Enter to close)
- `/exit` - Quit the application
- Type any message to send it
- Real-time incoming messages display automatically

**Note**: All interactive panels use the Enter key to close/confirm. While Escape may work on some platforms, Enter is recommended for consistent cross-platform behavior, especially on Windows.

### Example TUI Session
```bash
$ dart bin/at_talk_tui.dart -a @alice -t @bob

Connecting ... Connected

atTalk TUI - @alice
────────────────────────────────────────────────────────────────────────────────
 Participants: @alice, @bob
├───────────────────┬────────────────────────────────────────────────────────┤
   > @bob           │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │me: Hello Bob!                                          │
                    │@bob: Hi Alice! How are you doing?                      │
────────────────────┴────────────────────────────────────────────────────────
> Great! Working on the AtTalk TUI
atTalk TUI - @alice
────────────────────────────────────────────────────────────────────────────────
 Participants: @alice, @bob
├───────────────────┬────────────────────────────────────────────────────────┤
   > @bob           │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │me: Hello Bob!                                          │
                    │@bob: Hi Alice! How are you doing?                      │
                    │me: Great! Working on the AtTalk TUI                    │
────────────────────┴────────────────────────────────────────────────────────
> /new @charlie
[Enter a name for this group (or press Enter for no name):]
> Team Chat
me: [Group "Team Chat" created]
atTalk TUI - @alice
────────────────────────────────────────────────────────────────────────────────
 Participants: @alice, @bob, @charlie
├───────────────────┬────────────────────────────────────────────────────────┤
   > Team Chat      │                                                        │
     @bob           │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │                                                        │
                    │              me: [Group "Team Chat" created]           │
────────────────────┴────────────────────────────────────────────────────────
> /?
┌────────────────────────────────────────────────────────┐
│ atTalk TUI Help                                        │
│                                                        │
│ Text Commands:                                         │
│   /switch @other   Switch to chat with @other         │
│   /new @other      Start new chat with @other         │
│   /add @other      Add participant to group           │
│   /remove @other   Remove participant from group      │
│   /rename name     Rename current group               │
│   /delete          Delete current session             │
│   /list            Show participants panel            │
│   /exit            Quit                               │
│                                                        │
│ Press [Enter] to close this help panel.               │
└────────────────────────────────────────────────────────┘
> /exit
```

#### Non-Interactive Mode Examples
Send a single message:
```bash
$ dart bin/at_talk_tui.dart -a @alice -t @bob -m "Quick message!"
Connecting ... Connected  
Message sent.
```

Send to multiple recipients:
```bash
$ dart bin/at_talk_tui.dart -a @alice -t @bob,@charlie -m "Group announcement"
Connecting ... Connected
Message sent.
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

#### Windows-Specific Testing
For Windows users, test the TUI with different terminals:
```powershell
# PowerShell
dart bin/at_talk_tui.dart -a @yoursign -t @destination

# Command Prompt
dart bin/at_talk_tui.dart -a @yoursign -t @destination

# Windows Terminal (recommended for best experience)
dart bin/at_talk_tui.dart -a @yoursign -t @destination
```

All interactive features including the `/list` panel should work correctly across all Windows terminal environments.

## 🗄️ Storage Architecture

AtTalk implements robust storage handling with automatic conflict resolution:

### Persistent vs Ephemeral Storage
- **Persistent Storage**: Default mode that saves conversation history and settings
- **Ephemeral Storage**: Temporary storage that doesn't persist between sessions

### Multi-Instance Support
- **Automatic Detection**: Both GUI and TUI detect when storage is already in use
- **Smart Fallback**: Automatically switches to ephemeral storage when conflicts detected
- **Lock File Management**: Uses Hive lock files to detect active storage usage
- **Stale Lock Cleanup**: Automatically removes abandoned lock files (5-minute timeout)

### Storage Modes

#### GUI Storage
- **Default**: Uses application support directory for persistent storage
- **Multi-Instance**: Automatically falls back to ephemeral temp storage with UUID isolation
- **Cross-Platform**: Adapts to platform-specific storage conventions

#### TUI Storage
- **Interactive Mode**: Uses persistent storage in `~/.ai6bh/$atsign/storage`
- **Message Mode (`-m`)**: Always uses ephemeral storage for faster, conflict-free operation
- **Ephemeral Flag (`--ephemeral`)**: Forces ephemeral storage regardless of conflicts
- **Multi-Instance**: Automatic fallback to ephemeral storage when persistent storage in use

### Resource Cleanup
- **Signal Handlers**: Graceful cleanup on Ctrl+C, SIGTERM (TUI)
- **App Lifecycle**: Proper cleanup on app termination (GUI)
- **AtClient Reset**: Ensures AtClient connections are properly closed
- **Hive Box Closure**: All database connections closed on exit

This architecture ensures that multiple instances of AtTalk can run simultaneously without interfering with each other, while providing the best possible user experience in both single and multi-instance scenarios.

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
