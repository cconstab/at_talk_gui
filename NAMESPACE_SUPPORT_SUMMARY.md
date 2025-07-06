# Namespace Support Added to AtTalk GUI

## Overview
Successfully added TUI-like namespace support to the AtTalk GUI with the `-n` option functionality.

## New Features Added

### 1. Configurable Namespace Environment (`AtTalkEnv`)
- Made namespace configurable (was previously hardcoded)
- Added `setNamespace()`, `resetNamespace()` methods
- Automatically appends `.attalk` suffix like TUI
- Default: `default.attalk`

### 2. Command Line Support (`main.dart`)
- Added `-n, --namespace` option like TUI
- Added `-h, --help` option
- Graceful error handling for GUI (doesn't exit on parse errors)

### 3. Dynamic Namespace Change (`AtTalkService`)
- Added `changeNamespace()` method
- Reconfigures storage paths and reinitializes AtClient
- Supports both authenticated and unauthenticated states
- Proper cleanup and reinitialization

### 4. Settings UI (`SettingsScreen`)
- Added "App Configuration" section
- Namespace configuration dialog
- Real-time namespace display
- User-friendly namespace editing

## Usage Examples

### Command Line (like TUI)
```bash
# Default namespace (default.attalk)
flutter run

# Custom namespace
flutter run -- --namespace work        # Creates .work.attalk
flutter run -- --namespace personal    # Creates .personal.attalk
flutter run -- -n testing             # Creates .testing.attalk

# Help
flutter run -- --help
```

### Runtime Settings UI
1. Go to Settings screen
2. Click "App Configuration" → "Namespace"
3. Enter new namespace (e.g., "work", "personal")
4. Click "Apply"
5. App reinitializes with new storage paths

## Storage Path Changes

### Before (Fixed)
```
Persistent: {AppSupport}/.default.attalk/@atsign/storage
```

### After (Configurable)
```
Default:    {AppSupport}/.default.attalk/@atsign/storage
Work:       {AppSupport}/.work.attalk/@atsign/storage  
Personal:   {AppSupport}/.personal.attalk/@atsign/storage
Custom:     {AppSupport}/.{custom}.attalk/@atsign/storage
```

## Technical Implementation

### Storage Path Construction
```dart
// Uses configurable namespace
storagePath = '${dir.path}/.${AtTalkEnv.namespace}/$fullAtSign/storage';
```

### Namespace Management
```dart
// Set namespace (auto-appends .attalk)
AtTalkEnv.setNamespace('work');           // becomes 'work.attalk'
AtTalkEnv.setNamespace('test.attalk');    // stays 'test.attalk'

// Get current namespace
String current = AtTalkEnv.namespace;     // e.g., 'work.attalk'

// Reset to default
AtTalkEnv.resetNamespace();               // becomes 'default.attalk'
```

### Runtime Namespace Change
```dart
// Change namespace and reinitialize
bool success = await AtTalkService.instance.changeNamespace('work', '@alice');

// This will:
// 1. Cleanup current AtClient
// 2. Update namespace to 'work.attalk'
// 3. Reconfigure storage paths
// 4. Reinitialize AtClient with new paths
```

## Benefits

### 1. TUI Compatibility
- Same `-n` option as TUI
- Same namespace format (`.{name}.attalk`)
- Same storage directory isolation

### 2. Multi-Environment Support
- Separate storage for work/personal/testing
- No message mixing between namespaces
- Independent configurations

### 3. Runtime Flexibility
- Change namespace without restart (through settings)
- Dynamic storage reconfiguration
- Proper AtClient reinitialization

### 4. User Experience
- Command line power users: `-n` option
- GUI users: Settings dialog
- Help system: `--help` option

## Migration Notes

### Existing Users
- Default namespace remains `default.attalk`
- Existing storage paths unchanged
- Backward compatibility maintained

### New Users
- Can specify namespace from first run
- Clean separation by use case
- Easy switching between environments

## Example Workflows

### Development/Testing
```bash
# Development environment
flutter run -- -n dev

# Testing environment  
flutter run -- -n test

# Production environment
flutter run -- -n prod
```

### Multi-User Scenarios
```bash
# Work account
flutter run -- -n work

# Personal account
flutter run -- -n personal

# Family account
flutter run -- -n family
```

This brings the GUI to feature parity with the TUI regarding namespace management and storage isolation!
