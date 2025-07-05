# AtTalk Unified GUI/TUI

This project now supports both GUI (Flutter) and TUI (Terminal) interfaces for AtTalk messaging, with shared core business logic.

## Project Structure

```
lib/
├── core/                    # Shared business logic
│   ├── models/             # Data models (ChatMessage, Group)
│   ├── services/           # AtClient services and messaging
│   ├── providers/          # State management providers
│   └── utils/              # Shared utilities
├── gui/                    # Flutter GUI implementation
│   ├── screens/            # GUI screens
│   └── widgets/            # GUI widgets
├── tui/                    # Terminal UI implementation
│   ├── utils/              # TUI-specific utilities
│   └── at_talk_tui.dart    # Main TUI application
├── main.dart               # GUI entry point
bin/
├── at_talk_gui.dart        # GUI executable entry point
└── at_talk_tui.dart        # TUI executable entry point
```

## Features

### Shared Core Features
- AtSign authentication and client management
- Message sending and receiving
- Group management
- Conversation history
- Real-time message streaming

### GUI Features (Flutter)
- Full graphical interface
- Touch-friendly design
- Visual group management
- Rich text messaging

### TUI Features (Terminal)
- Command-line interface
- Colored output with chalk
- Real-time messaging
- Conversation history viewing
- Cross-platform terminal support

## Usage

### GUI Mode (Flutter)
```bash
flutter run
# or
dart bin/at_talk_gui.dart
```

### TUI Mode (Terminal)
```bash
dart bin/at_talk_tui.dart -a @yoursign -t @destination
```

#### TUI Command Line Options
- `-a, --atsign`: Your atSign (required)
- `-t, --toatsign`: Destination atSign to chat with (required)
- `-k, --key-file`: Path to atKeys file (optional, defaults to ~/.atsign/keys/)
- `-d, --root-domain`: Root domain (optional, defaults to root.atsign.org)
- `-n, --namespace`: Namespace (optional, defaults to ai6bh)
- `-v, --verbose`: Enable verbose logging
- `--never-sync`: Disable sync completely

#### TUI Commands
- `/exit` - Quit the application
- `/history` - Show conversation history
- Type any message to send it

## Dependencies

The project includes dependencies for both GUI and TUI modes:

### GUI Dependencies
- Flutter framework
- at_client_mobile
- at_onboarding_flutter
- provider (state management)

### TUI Dependencies
- args (command line parsing)
- chalkdart (colored terminal output)
- at_client (core atPlatform client)

### Shared Dependencies
- at_utils, at_commons, at_auth
- logging, uuid, collection

## Development

### Building
```bash
flutter pub get
dart pub get
```

### Testing GUI
```bash
flutter run
```

### Testing TUI
```bash
# Example usage (replace with your actual atSigns)
dart bin/at_talk_tui.dart -a @alice -t @bob -v
```

## Benefits of Unified Architecture

1. **Shared Business Logic**: Both GUI and TUI use the same core services for messaging, authentication, and data management
2. **Consistent Behavior**: Message handling, group management, and atSign operations work identically
3. **Reduced Maintenance**: Bug fixes and feature updates apply to both interfaces
4. **Code Reuse**: Models, services, and utilities are shared between implementations
5. **Flexible Deployment**: Choose the appropriate interface for different environments

## Next Steps

- [ ] Implement group messaging in TUI
- [ ] Add file transfer support
- [ ] Enhance TUI with more interactive features
- [ ] Add configuration file support
- [ ] Implement message encryption indicators
- [ ] Add offline message queuing
