# AtTalk Unified Architecture

## Project Overview

This project successfully unifies the AtTalk GUI (Flutter) and TUI (Terminal) implementations into a single codebase with shared core functionality.

## Architecture

```
lib/
├── core/              # Shared business logic, models, and services
│   ├── models/        # Shared data models (ChatMessage, Group, etc.)
│   ├── providers/     # Shared state management (AuthProvider, GroupsProvider, ChatProvider)
│   ├── services/      # Shared services (AtTalkService, AtClientService)
│   └── utils/         # Shared utilities (AtTalkEnv, AtsignManager)
├── gui/               # Flutter GUI implementation
│   ├── screens/       # Flutter screens (OnboardingScreen, GroupsListScreen, etc.)
│   └── widgets/       # Flutter widgets
├── tui/               # Terminal UI implementation
│   ├── services/      # TUI-specific services (ServiceFactories)
│   ├── utils/         # TUI-specific utilities (HomeDirectory, FileExists)
│   └── tui_chat.dart  # TUI chat interface
└── main.dart          # Flutter entry point

bin/
├── at_talk_gui.dart   # GUI entry point (checks for Flutter)
└── at_talk_tui.dart   # TUI entry point (complete TUI implementation)
```

## Usage

### TUI (Terminal Interface)
```bash
# Show help
dart run bin/at_talk_tui.dart --help

# Start chat between two atSigns
dart run bin/at_talk_tui.dart -a @alice -t @bob

# Send a message and exit
dart run bin/at_talk_tui.dart -a @alice -t @bob -m "Hello!"

# Group chat
dart run bin/at_talk_tui.dart -a @alice -t @bob,@charlie

# Pipe input
echo "Hello from script" | dart run bin/at_talk_tui.dart -a @alice -t @bob
```

### GUI (Flutter Interface)
```bash
# Run Flutter GUI
flutter run

# Or use the entry point script
dart run bin/at_talk_gui.dart
```

## Key Features

### Shared Core
- **Unified Business Logic**: Both GUI and TUI use the same core services for authentication, messaging, and group management
- **Consistent Data Models**: Same ChatMessage, Group, and other models across both interfaces
- **Shared State Management**: AuthProvider, GroupsProvider, and ChatProvider work for both implementations

### TUI Features
- **Real-time Chat**: Interactive terminal-based chat interface with multiple sessions
- **Group Support**: Create and manage group chats from command line
- **Message History**: Persistent message history across sessions
- **Pipe Support**: Send messages via stdin for automation
- **Cross-platform**: Works on Windows, macOS, and Linux

### GUI Features
- **Modern Flutter UI**: Clean, responsive interface with Material Design
- **Onboarding**: Integrated atSign onboarding and authentication
- **Group Management**: Visual group creation and management
- **Real-time Updates**: Live message and group updates
- **Settings**: Key management and configuration

## Implementation Details

### TUI Integration
The TUI implementation (`bin/at_talk_tui.dart`) is based on the real cc-tui branch of the at_talk repository, not a scratch implementation. It includes:

- Complete argument parsing with help system
- AtPlatform authentication and onboarding
- Real-time message listening and sending
- Group chat support with membership management
- Background/pipe mode for automation
- Proper error handling and retry logic

### Shared Services
Both GUI and TUI implementations use:

- `AtTalkService`: Core messaging and notification handling
- `AtClientService`: AtPlatform client management
- `AuthProvider`: Authentication state management
- `GroupsProvider`: Group management and synchronization

### Project Structure Benefits
1. **Code Reuse**: Maximum code sharing between GUI and TUI
2. **Maintainability**: Single source of truth for business logic
3. **Consistency**: Same behavior across both interfaces
4. **Testing**: Shared tests for core functionality
5. **Development**: Easier to add features to both interfaces simultaneously

## Current Status

✅ **TUI**: Fully functional with all features from cc-tui branch
✅ **GUI**: Fully functional Flutter application  
✅ **Shared Core**: All business logic, models, and services unified
✅ **Project Structure**: Clean separation of concerns
✅ **Dependencies**: All required packages installed and configured
✅ **Analysis**: All structural errors resolved (only minor warnings remain)

## Next Steps

- [ ] Remove debug print statements for production
- [ ] Add comprehensive test suite
- [ ] Update documentation for new architecture
- [ ] Consider CI/CD pipeline for both GUI and TUI builds
- [ ] Performance optimization for shared services

## Technical Notes

### Dependencies
The project uses a carefully managed set of dependencies that work for both GUI and TUI:
- AtPlatform packages: `at_client`, `at_onboarding_cli`, `at_onboarding_flutter`
- Flutter packages: Only used in GUI code
- TUI packages: `chalkdart`, `args`, etc. only used in TUI code
- Shared packages: `uuid`, `logging`, `version` used by both

### Import Strategy
- GUI code imports from `lib/core/` and `lib/gui/`
- TUI code imports from `lib/core/` and `lib/tui/`
- Core code only imports from within `lib/core/` or external packages
- No circular dependencies between layers

This architecture successfully achieves the goal of unifying the GUI and TUI codebases while maintaining clean separation of concerns and maximizing code reuse.
