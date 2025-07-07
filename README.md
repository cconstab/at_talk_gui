# AtTalk Unified GUI/TUI

A modern, responsive messaging applicat### 🔧 Core Security & Messaging
- ✅ AtSign authentication with keychain management
- ✅ End-to-end encryption for all communications
- ✅ Real-time peer-to-peer messaging with zero duplicates
- ✅ Advanced group messaging with member management and automatic consolidation
- ✅ Conversation history with persistent storage and intelligent conflict resolution
- ✅ Cross-## 📚 Documentation

For comprehensive project documentation, see the [`docs/`](docs/) directory:

- **[docs/README.md](docs/README.md)** - Complete documentation index and navigation guide
- **[docs/development-history/](docs/development-history/)** - Detailed development history and technical documentation
- **[doc/api/](doc/api/)** - Generated Dart API documentation

### Key Documentation Files

#### Core Architecture & Bug Fixes
- **[BUGFIX_1ON1_RENAME.md](docs/development-history/BUGFIX_1ON1_RENAME.md)** - **⭐ ESSENTIAL** - Complete fix for duplicate messages, race conditions, and group consolidation
- **[REFACTOR_GROUPS_ONLY.md](docs/development-history/REFACTOR_GROUPS_ONLY.md)** - Groups-only architecture implementation and benefits
- **[Side Panel Implementation](docs/development-history/SIDE_PANEL_IMPLEMENTATION.md)** - Modern navigation system design and implementation

#### Development Process & Collaboration
- **[Collaborative Development Story](docs/development-history/COLLABORATIVE_DEVELOPMENT_STORY.md)** - AI-human collaboration process and outcomes
- **[Unified Architecture](docs/development-history/UNIFIED_ARCHITECTURE.md)** - Overall project architecture and design decisions
- **[Enhanced Features](docs/development-history/ENHANCED_FEATURES.md)** - Feature enhancements and improvements

#### Platform & Technical Fixes
- **[Group Management Fixes](docs/development-history/GROUP_ADD_FIX.md)** - Group addition and member management improvements
- **[Storage Architecture](docs/development-history/STORAGE_FIX_SUMMARY.md)** - Multi-instance storage conflict resolution
- **[Namespace Handling](docs/development-history/TUI_GUI_NAMESPACE_FIX.md)** - TUI/GUI namespace integration

### Recent Major Improvements

The project has undergone significant architectural improvements documented in `BUGFIX_1ON1_RENAME.md`:

✅ **Complete elimination of duplicate messages** through race condition prevention  
✅ **Automatic group consolidation** for seamless TUI/GUI interoperability  
✅ **Groups-only architecture** eliminating special-case logic and edge cases  
✅ **Content-based duplicate detection** for bulletproof message handling  
✅ **Perfect TUI/GUI sync** with consistent group identification across all interfaces  

For API reference and technical details, browse the auto-generated documentation at [`doc/api/index.html`](doc/api/index.html).t (Windows, macOS, Linux)
- ✅ Multi-instance support with automatic conflict resolution
- ✅ Robust cleanup and signal handling
- ✅ Race condition prevention for instant message delivery
- ✅ Content-based duplicate detection for bulletproof message handling on the atPlatform with both graphical (Flutter) and terminal (CLI) interfaces. Features a comprehensive side panel navigation system, real-time messaging, intelligent unread message management, and robust group messaging with automatic consolidation and duplicate detection.

## 🌟 Overview

AtTalk is a secure, peer-to-peer messaging application that leverages atSigns for identity and end-to-end encryption. This repository contains a unified codebase supporting:

- **GUI Mode**: Full-featured Flutter app with responsive design and side panel navigation
- **TUI Mode**: Terminal-based interface for command-line environments  
- **Shared Core**: Common business logic, models, and services for consistent behavior

**🎯 Current Status**: ✅ **Production Ready** - All critical bugs resolved, zero-duplicate messaging architecture, perfect TUI/GUI synchronization. See [Project Status](docs/development-history/PROJECT_STATUS.md) for complete details.

## 🏗️ Architecture

### Modern Messaging Architecture

AtTalk features a next-generation messaging architecture that eliminates common chat application problems:

#### Groups-Only Design
- **Universal Group IDs**: All conversations use comma-separated, sorted member lists (e.g., `@alice,@bob,@charlie`)
- **No Special Cases**: 1-on-1 conversations are simply groups with 2 members - no separate code paths
- **Perfect Consistency**: TUI and GUI use identical group identification across all conversation types
- **Zero ID Conflicts**: Deterministic group IDs prevent duplicate conversations with same participants

#### Advanced Duplicate Prevention
- **Race Condition Protection**: Messages are added to UI immediately before network transmission
- **Content-Based Detection**: Duplicate messages detected by text content, sender, and timing
- **Multi-Layer Defense**: Both ID-based and content-based duplicate detection for bulletproof handling
- **Self-Message Filtering**: Own notifications automatically filtered to prevent echo effects

#### Intelligent Group Consolidation
- **Automatic Merging**: Multiple groups with identical members are automatically consolidated
- **Message Preservation**: All conversation history preserved during consolidation
- **Canonical Groups**: Smart selection of primary group based on activity and recency
- **Legacy Compatibility**: Handles groups created by older versions or different interfaces

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
- ✅ **Groups-Only Architecture**: All conversations use consistent comma-separated member list IDs
- ✅ **Zero Duplicate Messages**: Robust race condition prevention and content-based duplicate detection
- ✅ **Automatic Group Consolidation**: Intelligent merging of groups with identical members
- ✅ **Perfect TUI/GUI Compatibility**: Seamless conversation continuity between interfaces
- ✅ **Universal Group Support**: Both 1-on-1 and group conversations use the same robust infrastructure
## 🎯 Key Features

### 🖼️ Modern GUI Interface
- **Responsive Side Panel**: Desktop-style fixed panel, mobile-style sliding overlay
- **Real-time Navigation**: Instant conversation switching with live updates
- **Smart Unread Management**: Floating notification badge for unread messages
- **Smooth Animations**: Hardware-accelerated 300ms transitions
- **Search & Filter**: Real-time conversation search with multi-field support
- **Auto-Read Intelligence**: Multi-layer system ensuring accurate unread counts
- **Material Design 3**: Modern, accessible UI with proper theming
- **Touch Optimized**: Responsive controls for both desktop and mobile
- **Visual Onboarding**: Guided setup with AtKeys management

### 💻 Terminal Interface (TUI)  
- **Full CLI Control**: Complete messaging functionality in terminal
- **Keyboard Navigation**: Vim-style shortcuts and intuitive controls
- **Cross-platform**: Works on Windows, macOS, and Linux terminals
- **Resource Efficient**: Minimal memory footprint for server environments
- **Signal Handling**: Graceful cleanup on Ctrl+C and SIGTERM
- **Command Arguments**: Rich CLI options for automation

### � Core Security & Messaging
- ✅ AtSign authentication with keychain management
- ✅ End-to-end encryption for all communications
- ✅ Real-time peer-to-peer messaging
- ✅ Group messaging with member management
- ✅ Conversation history with persistent storage
- ✅ Cross-platform support (Windows, macOS, Linux)
- ✅ Multi-instance support with conflict resolution
- ✅ Robust cleanup and signal handling

### 📱 Platform Compatibility
- **Windows**: Full support with PowerShell, Command Prompt, Windows Terminal
- **macOS/Linux**: Complete compatibility with ANSI-capable terminals
- **Responsive Design**: Adapts to screen sizes from mobile to ultrawide
- **Multi-Instance**: GUI and TUI can run simultaneously without conflicts
- **Performance**: Optimized for 60fps animations and real-time updates

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

- **🔄 Consistency**: Both interfaces use identical business logic with bulletproof message handling
- **🛠️ Maintainability**: Single codebase for core functionality eliminates drift between GUI and TUI
- **🐛 Bug Fixes**: Fixes apply to both GUI and TUI automatically - no duplicate maintenance
- **🚀 Feature Parity**: New features can be added to both interfaces simultaneously
- **📦 Code Reuse**: Maximize shared code, minimize duplication
- **⚡ Zero Duplicates**: Advanced duplicate detection and group consolidation across all interfaces
- **🎯 Perfect Sync**: Seamless conversation continuity when switching between GUI and TUI modes

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
- **Interactive Mode**: Uses persistent storage in `~/.default.attalk/$atsign/storage`
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

## � Documentation

For comprehensive project documentation, see the [`docs/`](docs/) directory:

- **[docs/README.md](docs/README.md)** - Complete documentation index and navigation guide
- **[docs/development-history/](docs/development-history/)** - Detailed development history and technical documentation
- **[doc/api/](doc/api/)** - Generated Dart API documentation

### Key Documentation Files

- **[Side Panel Implementation](docs/development-history/SIDE_PANEL_IMPLEMENTATION.md)** - Modern navigation system design and implementation
- **[Collaborative Development Story](docs/development-history/COLLABORATIVE_DEVELOPMENT_STORY.md)** - AI-human collaboration process and outcomes
- **[Unified Architecture](docs/development-history/UNIFIED_ARCHITECTURE.md)** - Overall project architecture and design decisions

For API reference and technical details, browse the auto-generated documentation at [`doc/api/index.html`](doc/api/index.html).

## �📝 License

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
