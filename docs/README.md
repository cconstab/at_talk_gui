# AtTalk GUI Documentation

This directory contains comprehensive documentation for the AtTalk GUI project.

## Documentation Structure

### Main Documentation
- [`../README.md`](../README.md) - Main project README with overview, features, and quick start guide

### Development History (`development-history/`)
The `development-history/` directory contains detailed documentation of the project's evolution:

#### Core Architecture & Features
- [`SIDE_PANEL_IMPLEMENTATION.md`](development-history/SIDE_PANEL_IMPLEMENTATION.md) - Comprehensive side panel design and implementation
- [`UNIFIED_ARCHITECTURE.md`](development-history/UNIFIED_ARCHITECTURE.md) - Overall architectural decisions and patterns
- [`ENHANCED_FEATURES.md`](development-history/ENHANCED_FEATURES.md) - Feature enhancements and improvements
- [`COLLABORATIVE_DEVELOPMENT_STORY.md`](development-history/COLLABORATIVE_DEVELOPMENT_STORY.md) - AI-human collaboration story

#### Platform Compatibility & Migration
- [`TUI_COMPATIBILITY.md`](development-history/TUI_COMPATIBILITY.md) - Terminal User Interface compatibility
- [`MIGRATION_TO_ATTALK_SUMMARY.md`](development-history/MIGRATION_TO_ATTALK_SUMMARY.md) - Migration from previous versions

#### Bug Fixes & Technical Issues
- [`ATCLIENT_NAMESPACE_FIX.md`](development-history/ATCLIENT_NAMESPACE_FIX.md) - AtClient namespace resolution fixes
- [`ATSIGN_USERNAME_CONFLICT_FIX.md`](development-history/ATSIGN_USERNAME_CONFLICT_FIX.md) - Username conflict resolution
- [`DYNAMIC_NAMESPACE_CHANGE.md`](development-history/DYNAMIC_NAMESPACE_CHANGE.md) - Dynamic namespace handling
- [`MULTI_ATSIGN_ONBOARDING_FIX.md`](development-history/MULTI_ATSIGN_ONBOARDING_FIX.md) - Multi-atsign onboarding fixes
- [`NAMESPACE_PROTOCOL_SUMMARY.md`](development-history/NAMESPACE_PROTOCOL_SUMMARY.md) - Namespace protocol implementation
- [`NAMESPACE_SUPPORT_SUMMARY.md`](development-history/NAMESPACE_SUPPORT_SUMMARY.md) - Namespace support overview
- [`OFFLINE_MESSAGES_FIX.md`](development-history/OFFLINE_MESSAGES_FIX.md) - Offline message handling fixes
- [`STORAGE_FIX_SUMMARY.md`](development-history/STORAGE_FIX_SUMMARY.md) - Storage system fixes
- [`TUI_GUI_NAMESPACE_FIX.md`](development-history/TUI_GUI_NAMESPACE_FIX.md) - TUI/GUI namespace integration
- [`GROUP_ADD_FIX.md`](development-history/GROUP_ADD_FIX.md) - Group addition functionality fixes
- [`MEMBER_REMOVAL_FIX.md`](development-history/MEMBER_REMOVAL_FIX.md) - Group member removal fixes
- [`BUGFIX_GROUP_OVERWRITE.md`](development-history/BUGFIX_GROUP_OVERWRITE.md) - Group overwrite bug fixes
- [`1ON1_TO_GROUP_FIX.md`](development-history/1ON1_TO_GROUP_FIX.md) - One-on-one to group conversion fixes
- [`UPLOAD_KEYS_FIX.md`](development-history/UPLOAD_KEYS_FIX.md) - Key upload functionality fixes

### API Documentation
- [`../doc/api/`](../doc/api/) - Generated Dart API documentation

## Key Features Documented

### Modern Side Panel Navigation
- Responsive design (fixed on desktop, overlay on mobile)
- Real-time unread message indicators
- Smooth animations and transitions
- Search functionality with real-time filtering
- Auto-read logic for message count management

### Cross-Platform Compatibility
- Flutter GUI for mobile and desktop
- Terminal User Interface (TUI) for command-line usage
- Shared core services and data models

### AtProtocol Integration
- Secure end-to-end encrypted messaging
- Decentralized identity management
- Multi-atsign support and onboarding

## Getting Started

1. Read the main [`README.md`](../README.md) for project overview
2. For implementation details, start with [`SIDE_PANEL_IMPLEMENTATION.md`](development-history/SIDE_PANEL_IMPLEMENTATION.md)
3. Check the [`COLLABORATIVE_DEVELOPMENT_STORY.md`](development-history/COLLABORATIVE_DEVELOPMENT_STORY.md) for the development process
4. Browse the API documentation in [`doc/api/`](../doc/api/)

## Contributing

When adding new documentation:
1. Place feature documentation in `development-history/`
2. Update this index file with appropriate links
3. Follow the established naming conventions
4. Include clear headings and cross-references

For technical questions, refer to the API documentation or the detailed implementation guides in the development history.
