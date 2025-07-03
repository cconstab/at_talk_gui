# Windows /list Command Fix

## Problem
On Windows, the `/list` command would hang and not respond to input due to multiple stdin listeners conflicting.

## Solution
Refactored the TUI input handling to use a single main input loop that handles panel states rather than creating separate stdin listeners for each panel.

## Changes Made
1. Added panel state fields: `_showingHelpPanel`, `_showingParticipantsPanel`, `_participantsScroll`
2. Added participants panel input state fields: `_participantsInputMode`, `_participantsInputBuffer`, `_participantsInputPrompt`, `_participantsInputAction`
3. Modified `showHelpPanel()` and `showParticipantsPanel()` to set state flags and draw panels directly
4. Updated the main input loop to check for panel states first and handle panel input appropriately
5. Restored full interactive functionality for participants panel: `r` (rename), `a` (add), `d` (remove)
6. Removed separate stdin listeners for panels to avoid conflicts on Windows

## Features Restored
- **Participants Panel (`/list`)**:
  - `r` - Rename group (only available for groups with 3+ participants)
  - `a` - Add participant to chat
  - `d` - Remove participant from group (only available for groups with 3+ participants)
  - `j`/`k` - Scroll through participant list if it's long
  - `Enter` - Close panel (Escape may not work reliably on Windows)

## Testing Instructions
1. Run the TUI: `dart run bin/at_talk_tui.dart -a @yoursign -t @othersign`
2. Type `/list` and press Enter
3. Verify the participants panel displays with action buttons
4. Test the interactive features:
   - Press `a` to add a participant (should prompt for atSign)
   - Press `r` to rename group (if it's a group)
   - Press `d` to remove a participant (if it's a group)
   - Press `j`/`k` to scroll if there are many participants
5. Press Enter to close the panel
6. Verify you can interact with the TUI normally after closing the panel

## Expected Result
- The `/list` command should work on Windows without hanging
- All interactive features should work within the participants panel
- Panels should close properly with Enter (Escape may not work on Windows)
- TUI should remain responsive after closing panels
- Input prompts should work correctly for rename/add/remove operations
