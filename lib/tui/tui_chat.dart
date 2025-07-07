import 'package:chalkdart/chalk.dart';
import 'dart:io';
import 'dart:async';

class ChatSession {
  final String id;
  final List<String> participants;
  String? groupName; // New field for group names
  final List<String> messages = [];
  int scrollOffset = 0;
  int unreadCount = 0;
  ChatSession(this.id, this.participants, {this.groupName});

  // Get display name for the session
  String getDisplayName(String myAtSign) {
    if (groupName != null && groupName!.isNotEmpty) {
      return groupName!;
    }

    // For all groups, show participants excluding me
    var others = participants.where((p) => p != myAtSign).toList();
    if (others.isEmpty) {
      // Fallback: show all participants
      return participants.join(', ');
    } else if (others.length == 1) {
      // Single other participant
      return others.first;
    } else {
      // Multiple other participants
      return others.join(', ');
    }
  }
}

class TuiChatApp {
  final String myAtSign;
  final Map<String, ChatSession> sessions = {};
  String? activeSession;
  void Function(String sessionId, String message)? onSend;
  void Function(String sessionId, String newGroupName)?
  onGroupRename; // New callback for group renames
  void Function(String sessionId, List<String> participants, String? groupName)?
  onGroupMembershipChange; // New callback for group membership changes
  Future<void> Function()? onCleanup; // Cleanup callback for graceful exit
  int windowOffset = 0;
  int windowSize = 1;
  List<String> get sessionList => sessions.keys.toList();
  String inputBuffer = '';
  int inputCursorPos = 0;
  int inputScrollOffset = 0;
  bool redrawRequested = false;
  bool showHelpHint = true;

  // State for group name input
  bool _waitingForGroupName = false;
  List<String>? _pendingParticipants;

  // Panel state for Windows compatibility
  bool _showingHelpPanel = false;
  bool _showingParticipantsPanel = false;
  int _participantsScroll = 0;

  // Participants panel input state
  bool _participantsInputMode = false;
  String _participantsInputBuffer = '';
  String _participantsInputPrompt = '';
  int _participantsInputAction = 0; // 1: rename, 2: add, 3: remove
  String? _pendingSessionKey;

  TuiChatApp(this.myAtSign);

  void addSession(String id, [List<String>? participants, String? groupName]) {
    if (!sessions.containsKey(id)) {
      sessions[id] = ChatSession(
        id,
        participants ?? [id],
        groupName: groupName,
      );
    } else {
      if (participants != null) {
        sessions[id]!.participants
          ..clear()
          ..addAll(participants);
      }
      if (groupName != null) {
        sessions[id]!.groupName = groupName;
      }
    }
    activeSession ??= id;
  }

  void switchSession(String id) {
    addSession(id);
    activeSession = id;
    windowOffset = sessionList.indexOf(id);
    sessions[id]!.unreadCount = 0;
    requestRedraw();
  }

  // Find existing session with the same participant set
  String? findSessionWithParticipants(List<String> participants) {
    var sortedParticipants = participants.toSet().toList()..sort();

    for (var entry in sessions.entries) {
      var sessionParticipants = entry.value.participants.toSet().toList()
        ..sort();
      if (sessionParticipants.length == sortedParticipants.length &&
          sessionParticipants.every((p) => sortedParticipants.contains(p))) {
        return entry.key;
      }
    }
    return null;
  }

  // Generate session key based on participants - consistent for all group sizes
  String generateSessionKey(List<String> participants) {
    var sortedParticipants = participants.toSet().toList()..sort();
    // Use comma-separated sorted list for all groups (consistent approach)
    return sortedParticipants.join(',');
  }

  void requestRedraw() {
    redrawRequested = true;
  }

  void addMessage(
    String id,
    String message, {
    bool incoming = false,
    String? sender,
  }) {
    addSession(id);
    final prefix = incoming
        ? (sender != null ? chalk.green('$sender: ') : chalk.yellow('me: '))
        : chalk.yellow('me: ');

    // Highlight "file sent" if it appears at the beginning of the message
    String processedMessage = message;
    if (message.startsWith('file sent\n')) {
      processedMessage =
          chalk.cyan.bold('file sent') +
          message.substring(9); // 9 = length of "file sent"
    }

    sessions[id]!.messages.add(prefix + processedMessage);
    if (incoming && activeSession != id) {
      sessions[id]!.unreadCount++;
    }
    if (activeSession == id) {
      requestRedraw();
    }
  }

  void nextWindow() {
    if (sessions.isEmpty) return;
    windowOffset = (windowOffset + 1) % sessions.length;
    activeSession = sessionList[windowOffset];
    if (sessions[activeSession!]!.unreadCount > 0) {
      sessions[activeSession!]!.unreadCount = 0;
      requestRedraw();
    }
  }

  void prevWindow() {
    if (sessions.isEmpty) return;
    windowOffset = (windowOffset - 1 + sessions.length) % sessions.length;
    activeSession = sessionList[windowOffset];
    if (sessions[activeSession!]!.unreadCount > 0) {
      sessions[activeSession!]!.unreadCount = 0;
      requestRedraw();
    }
  }

  void scrollUp() {
    if (activeSession == null) return;
    final session = sessions[activeSession!]!;
    if (session.scrollOffset < session.messages.length - 1) {
      session.scrollOffset++;
    }
  }

  void scrollDown() {
    if (activeSession == null) return;
    final session = sessions[activeSession!]!;
    if (session.scrollOffset > 0) {
      session.scrollOffset--;
    }
  }

  String stripAnsi(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  }

  // Word wrap helper for chat messages
  List<String> wrapText(String text, int maxWidth) {
    if (maxWidth <= 0) return [text];

    List<String> lines = [];

    // First split on existing newlines
    List<String> paragraphs = text.split('\n');

    for (String paragraph in paragraphs) {
      if (paragraph.isEmpty) {
        lines.add('');
        continue;
      }

      List<String> words = paragraph.split(' ');
      String currentLine = '';

      for (String word in words) {
        // Check if adding this word would exceed the width
        String testLine = currentLine.isEmpty ? word : '$currentLine $word';

        // Use stripAnsi to get actual visible length for width calculation
        if (stripAnsi(testLine).length <= maxWidth) {
          currentLine = testLine;
        } else {
          // If current line is not empty, save it and start new line
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            currentLine = '';
          }

          // Handle case where single word is longer than maxWidth
          if (stripAnsi(word).length > maxWidth) {
            // Split the word into chunks that fit
            String remainingWord = word;
            while (stripAnsi(remainingWord).length > maxWidth) {
              // Find the best break point that preserves ANSI codes
              int visibleCount = 0;
              int breakPoint = 0;
              bool inAnsiSequence = false;

              for (
                int i = 0;
                i < remainingWord.length && visibleCount < maxWidth;
                i++
              ) {
                if (remainingWord[i] == '\x1B') {
                  inAnsiSequence = true;
                } else if (inAnsiSequence && remainingWord[i] == 'm') {
                  inAnsiSequence = false;
                } else if (!inAnsiSequence) {
                  visibleCount++;
                }

                if (visibleCount <= maxWidth) {
                  breakPoint = i + 1;
                }
              }

              String chunk = remainingWord.substring(0, breakPoint);
              lines.add(chunk);
              remainingWord = remainingWord.substring(breakPoint);
            }

            // Add the remaining part of the word to current line
            currentLine = remainingWord;
          } else {
            currentLine = word;
          }
        }
      }

      // Add the last line of this paragraph if it's not empty
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = '';
      }
    }

    return lines.isEmpty ? [''] : lines;
  }

  // Fuzzy matching helper for session switching
  String? findBestMatch(String query) {
    if (query.isEmpty) return null;

    // Get candidates excluding the current active session
    var candidates = sessions.keys.where((id) => id != activeSession).toList();

    // First try exact match (excluding current session)
    if (candidates.contains(query)) return query;

    // Then try partial matches
    var matches = <String>[];

    // Look for sessions that contain the query (case insensitive)
    for (var sessionId in candidates) {
      if (sessionId.toLowerCase().contains(query.toLowerCase())) {
        matches.add(sessionId);
      }
    }

    // If we have matches, return the shortest one (most likely match)
    if (matches.isNotEmpty) {
      matches.sort((a, b) => a.length.compareTo(b.length));
      return matches.first;
    }

    return null;
  }

  void draw() {
    final termWidth = stdout.hasTerminal ? stdout.terminalColumns : 80;
    final termHeight = stdout.hasTerminal ? stdout.terminalLines : 24;
    final sessionWidth = 20;
    final chatWidth = termWidth - sessionWidth - 2;
    final chatHeight = termHeight - 5;
    stdout.write('\x1b[2J\x1b[H');
    stdout.writeln(chalk.bold('atTalk TUI - $myAtSign').padRight(termWidth));
    stdout.writeln('─' * termWidth);
    if (activeSession != null) {
      var session = sessions[activeSession!]!;
      var sortedParticipants = [
        myAtSign,
        ...session.participants.where((p) => p != myAtSign),
      ];
      var participants = sortedParticipants
          .map((p) => p == myAtSign ? chalk.yellow.bold(p) : chalk.cyan(p))
          .join(', ');
      stdout.writeln(chalk.cyan(' Participants: ') + participants);
      // Draw a line under participants, joining the session list and chat window
      stdout.write(chalk.yellow('├${'─' * (sessionWidth - 1)}'));
      stdout.writeln(chalk.yellow('┬${'─' * (chatWidth - 1)}┤'));
    }
    List<String> chatLines = [];
    if (activeSession != null) {
      var session = sessions[activeSession!]!;
      int maxLines = chatHeight;

      // Process messages with word wrapping
      List<String> wrappedMessages = [];
      for (String message in session.messages) {
        List<String> wrapped = wrapText(
          message,
          chatWidth - 2,
        ); // -2 for padding
        wrappedMessages.addAll(wrapped);
      }

      int start = (wrappedMessages.length - maxLines - session.scrollOffset)
          .clamp(0, wrappedMessages.length);
      int end = (wrappedMessages.length - session.scrollOffset).clamp(
        0,
        wrappedMessages.length,
      );
      for (int i = start; i < end; i++) {
        chatLines.add(wrappedMessages[i]);
      }
      while (chatLines.length < chatHeight) {
        chatLines.insert(0, '');
      }
    } else {
      chatLines = List.filled(chatHeight, '');
    }
    for (int i = 0; i < chatHeight; i++) {
      String sessionLine = '';
      if (i < sessionList.length) {
        var s = sessionList[i];
        var marker = (i == windowOffset) ? chalk.yellow('>') : ' ';
        int unread = sessions[s]!.unreadCount;
        String unreadStr = '';
        if (unread > 0) {
          if (unread > 99) {
            unreadStr = chalk.red.bold('** ');
          } else {
            unreadStr = chalk.red.bold('${unread.toString().padLeft(2, '0')} ');
          }
        } else {
          unreadStr = '   ';
        }
        sessionLine =
            '$unreadStr$marker ${sessions[s]!.getDisplayName(myAtSign).padRight(sessionWidth - 6 - marker.length)}';
      } else {
        sessionLine = ' '.padRight(sessionWidth);
      }
      int visibleLen = stripAnsi(sessionLine).length;
      if (visibleLen < sessionWidth) {
        stdout.write(sessionLine + ' ' * (sessionWidth - visibleLen));
      } else if (visibleLen > sessionWidth) {
        int count = 0;
        String out = '';
        for (int j = 0; j < sessionLine.length && count < sessionWidth; j++) {
          if (sessionLine[j] == '\x1B') {
            int m = sessionLine.indexOf('m', j);
            if (m != -1) {
              out += sessionLine.substring(j, m + 1);
              j = m;
            }
          } else {
            out += sessionLine[j];
            count++;
          }
        }
        stdout.write(out);
      } else {
        stdout.write(sessionLine);
      }
      stdout.write(chalk.yellow('│'));
      stdout.writeln(chatLines[i].padRight(chatWidth));
    }
    stdout.writeln('─' * termWidth);
    updateInputDisplay();
  }

  Future<void> showHelpPanel() async {
    _showingHelpPanel = true;
    _drawHelpPanel();
    // The main input loop will handle the exit condition
  }

  void _drawHelpPanel() {
    final termWidth = stdout.hasTerminal ? stdout.terminalColumns : 80;
    final termHeight = stdout.hasTerminal ? stdout.terminalLines : 24;
    final helpLines = [
      'atTalk TUI Help',
      '',
      'Text Commands:',
      '  /switch @other   Switch to chat with @other',
      '  /new @other      Start new chat with @other',
      '  /add @other      Add participant to group',
      '  /remove @other   Remove participant from group',
      '  /rename name     Rename current group',
      '  /delete          Delete current session',
      '  /list            Show group info panel',
      '  /exit            Quit',
      '',
      'Press Enter to close this help panel.',
    ];
    int panelWidth = 50;
    int panelHeight = helpLines.length + 2;
    int left = ((termWidth - panelWidth) ~/ 2).clamp(0, termWidth - 1);
    int top = ((termHeight - panelHeight) ~/ 2).clamp(0, termHeight - 1);

    // Save cursor position
    stdout.write('\x1b[s');

    // Draw overlay panel
    for (int i = 0; i < helpLines.length + 2; i++) {
      stdout.write('\x1b[${top + i + 1};${left + 1}H');
      if (i == 0) {
        stdout.write(chalk.yellow('┌${'─' * (panelWidth - 2)}┐'));
      } else if (i == helpLines.length + 1) {
        stdout.write(chalk.yellow('└${'─' * (panelWidth - 2)}┘'));
      } else {
        String line = helpLines[i - 1].padRight(panelWidth - 2);
        stdout.write(chalk.yellow('│') + chalk.bold(line) + chalk.yellow('│'));
      }
    }
  }

  Future<void> showParticipantsPanel() async {
    _showingParticipantsPanel = true;
    _participantsScroll = 0;
    _participantsInputMode = false;
    _participantsInputBuffer = '';
    _participantsInputAction = 0;
    _drawParticipantsPanel();
    // The main input loop will handle the exit condition
  }

  void _drawParticipantsPanel() {
    if (activeSession == null) return;
    final session = sessions[activeSession!]!;
    final termWidth = stdout.hasTerminal ? stdout.terminalColumns : 80;
    final termHeight = stdout.hasTerminal ? stdout.terminalLines : 24;
    final panelWidth = 50;
    final maxPanelHeight = termHeight - 8;

    final participants = [
      myAtSign,
      ...session.participants.where((p) => p != myAtSign),
    ];
    final visibleCount = (participants.length < maxPanelHeight - 8)
        ? participants.length
        : (maxPanelHeight - 8);
    final panelHeight = visibleCount + 8; // More space for buttons and input
    final left = ((termWidth - panelWidth) ~/ 2).clamp(0, termWidth - 1);
    final top = ((termHeight - panelHeight) ~/ 2).clamp(0, termHeight - 1);

    // Draw overlay panel
    for (int i = 0; i < panelHeight; i++) {
      stdout.write('\x1b[${top + i + 1};${left + 1}H');
      if (i == 0) {
        stdout.write(chalk.yellow('┌${'─' * (panelWidth - 2)}┐'));
      } else if (i == panelHeight - 1) {
        stdout.write(chalk.yellow('└${'─' * (panelWidth - 2)}┘'));
      } else if (i == 1) {
        // Title with scroll indicators
        String title = session.groupName != null
            ? ' Group: ${session.groupName}'
            : ' Participants (${participants.length})';
        String scrollInfo = '';
        if (participants.length > visibleCount) {
          String upIndicator = _participantsScroll > 0 ? '↑' : ' ';
          String downIndicator =
              _participantsScroll < participants.length - visibleCount
              ? '↓'
              : ' ';
          scrollInfo = ' $upIndicator$downIndicator ';
        }
        String titleLine =
            chalk.bold(title) +
            scrollInfo +
            ' ' * (panelWidth - 2 - title.length - scrollInfo.length);
        stdout.write(chalk.yellow('│') + titleLine + chalk.yellow('│'));
      } else if (i == 2) {
        // Separator line
        stdout.write(chalk.yellow('├${'─' * (panelWidth - 2)}┤'));
      } else if (i >= 3 && i < 3 + visibleCount) {
        // Participant list
        int participantIndex = i - 3 + _participantsScroll;
        if (participantIndex < participants.length) {
          String p = participants[participantIndex];
          String displayName = (p == myAtSign
              ? chalk.yellow.bold('$p (you)')
              : chalk.cyan(p));
          int visibleLen = stripAnsi(displayName).length;
          String line = ' $displayName' + ' ' * (panelWidth - 3 - visibleLen);
          stdout.write(chalk.yellow('│') + line + chalk.yellow('│'));
        } else {
          stdout.write(chalk.yellow('│${' ' * (panelWidth - 2)}│'));
        }
      } else if (i == 3 + visibleCount) {
        // Separator line
        stdout.write(chalk.yellow('├${'─' * (panelWidth - 2)}┤'));
      } else if (i == 4 + visibleCount) {
        // Rename button (only for groups)
        String renameText = session.participants.length >= 3
            ? chalk.cyan(' [r] Rename Group')
            : chalk.gray(' [r] Rename Group (groups only)');
        String line =
            renameText + ' ' * (panelWidth - 2 - stripAnsi(renameText).length);
        stdout.write(chalk.yellow('│') + line + chalk.yellow('│'));
      } else if (i == 5 + visibleCount) {
        // Add participant button
        String addText = chalk.green(' [a] Add Participant');
        String line =
            addText + ' ' * (panelWidth - 2 - stripAnsi(addText).length);
        stdout.write(chalk.yellow('│') + line + chalk.yellow('│'));
      } else if (i == 6 + visibleCount) {
        // Remove participant button (only if more than 2 participants)
        String removeText = session.participants.length > 2
            ? chalk.red(' [d] Remove Participant')
            : chalk.gray(' [d] Remove Participant (groups only)');
        String line =
            removeText + ' ' * (panelWidth - 2 - stripAnsi(removeText).length);
        stdout.write(chalk.yellow('│') + line + chalk.yellow('│'));
      } else {
        stdout.write(chalk.yellow('│${' ' * (panelWidth - 2)}│'));
      }
    }

    // Show input prompt or instructions below panel
    stdout.write('\x1b[${top + panelHeight + 1};${left + 1}H');
    if (_participantsInputMode) {
      String promptLine =
          chalk.bold('$_participantsInputPrompt ') + _participantsInputBuffer;
      stdout.write(promptLine.padRight(panelWidth));
      stdout.write('\x1b[${top + panelHeight + 2};${left + 1}H');
      stdout.write(
        chalk.dim('[Enter] to confirm or cancel if empty').padRight(panelWidth),
      );
    } else {
      if (participants.length > visibleCount) {
        stdout.write(
          chalk
              .bold('Use j/k to scroll, action keys, [Enter] to close')
              .padRight(panelWidth),
        );
      } else {
        stdout.write(
          chalk
              .bold('Use action keys or [Enter] to close')
              .padRight(panelWidth),
        );
      }
    }
  }

  Future<void> _handleParticipantsInput() async {
    if (activeSession == null) return;
    final session = sessions[activeSession!]!;

    if (_participantsInputBuffer.trim().isEmpty) return;

    if (_participantsInputAction == 1) {
      // Rename group
      session.groupName = _participantsInputBuffer.trim();
      var displayName = session.groupName ?? 'Unnamed Group';
      addMessage(
        activeSession!,
        '[Group renamed to "$displayName"]',
        incoming: true,
      );
      if (onGroupRename != null) {
        onGroupRename!(activeSession!, _participantsInputBuffer.trim());
      }

      // Close the participants panel immediately to avoid Windows terminal state issues
      _showingParticipantsPanel = false;
      _participantsInputMode = false;
      _participantsInputBuffer = '';
      _participantsInputAction = 0;
      _participantsScroll = 0;

      // Force a full redraw to ensure terminal state is properly reset on Windows
      requestRedraw();
      return;
    } else if (_participantsInputAction == 2) {
      // Add participant
      var newParticipant = _participantsInputBuffer.trim();
      if (!session.participants.contains(newParticipant) &&
          newParticipant != myAtSign) {
        // Simply add the participant to the existing session
        session.participants.add(newParticipant);

        addMessage(
          activeSession!,
          '[Added $newParticipant to the chat]',
          incoming: true,
        );

        // Send membership change notifications to all participants
        onGroupMembershipChange?.call(
          activeSession!,
          session.participants,
          session.groupName,
        );

        // Close the participants panel
        _showingParticipantsPanel = false;
        _participantsInputMode = false;
        _participantsInputBuffer = '';
        _participantsInputAction = 0;
        _participantsScroll = 0;

        requestRedraw();
        return;
      }
    } else if (_participantsInputAction == 3) {
      // Remove participant
      var participantToRemove = _participantsInputBuffer.trim();
      if (session.participants.contains(participantToRemove) &&
          participantToRemove != myAtSign) {
        // Simply remove from the current session, preserving group name and messages
        session.participants.remove(participantToRemove);
        addMessage(
          activeSession!,
          '[Removed $participantToRemove from the chat]',
          incoming: true,
        );

        // Notify other participants of the membership change
        if (onGroupMembershipChange != null) {
          onGroupMembershipChange!(
            activeSession!,
            session.participants.toList(),
            session.groupName,
          );
        }

        // Close the participants panel immediately to avoid Windows terminal state issues
        _showingParticipantsPanel = false;
        _participantsInputMode = false;
        _participantsInputBuffer = '';
        _participantsInputAction = 0;
        _participantsScroll = 0;

        // Force a full redraw to ensure terminal state is properly reset on Windows
        requestRedraw();
        return;
      }
    }
  }

  void deleteSession(String id) {
    if (sessions.containsKey(id)) {
      sessions.remove(id);
      if (activeSession == id) {
        activeSession = sessions.isNotEmpty ? sessionList.first : null;
        windowOffset = 0;
      }
      requestRedraw();
    }
  }

  void updateInputDisplay() {
    final termWidth = stdout.hasTerminal ? stdout.terminalColumns : 80;
    final termHeight = stdout.hasTerminal ? stdout.terminalLines : 24;
    final maxInputWidth = termWidth - 3; // Account for "> " prefix

    // Adjust scroll offset to keep cursor visible
    if (inputCursorPos < inputScrollOffset) {
      inputScrollOffset = inputCursorPos;
    } else if (inputCursorPos >= inputScrollOffset + maxInputWidth) {
      inputScrollOffset = inputCursorPos - maxInputWidth + 1;
    }

    // Extract visible portion of input
    String visibleInput;
    int visibleCursorPos = inputCursorPos - inputScrollOffset;

    if (inputBuffer.length <= maxInputWidth) {
      // Input fits entirely, show it all
      visibleInput = inputBuffer;
      visibleCursorPos = inputCursorPos;
      inputScrollOffset = 0; // Reset scroll when input is short enough
    } else {
      // Input is too long, show visible portion
      int startPos = inputScrollOffset;
      int endPos = (inputScrollOffset + maxInputWidth).clamp(
        0,
        inputBuffer.length,
      );
      visibleInput = inputBuffer.substring(startPos, endPos);

      // Add scroll indicators without affecting cursor position
      if (inputScrollOffset > 0 && visibleInput.isNotEmpty) {
        visibleInput = '<${visibleInput.substring(1)}';
        if (visibleCursorPos == 0)
          visibleCursorPos = 1; // Adjust cursor if at start
      }
      if (endPos < inputBuffer.length && visibleInput.isNotEmpty) {
        visibleInput = '${visibleInput.substring(0, visibleInput.length - 1)}>';
        if (visibleCursorPos >= visibleInput.length)
          visibleCursorPos = visibleInput.length - 1;
      }
    }

    // Clear the input line and redraw
    stdout.write('\x1b[$termHeight;1H\x1b[K');
    if (inputBuffer.isEmpty && showHelpHint) {
      // Show greyed-out help hint when input is empty
      stdout.write('> ');
      stdout.write(
        '\x1b[90m /? for help\x1b[0m',
      ); // 90m = dark grey, 0m = reset
      stdout.write('\x1b[$termHeight;3H'); // Position cursor after "> "
    } else {
      stdout.write('> $visibleInput');
      stdout.write('\x1b[$termHeight;${visibleCursorPos + 3}H');
    }
  }

  Future<void> run() async {
    stdin.echoMode = false;
    stdin.lineMode = false;
    draw();

    // Listen for terminal resize events (SIGWINCH) - Unix/Linux/Mac only
    if (!Platform.isWindows) {
      ProcessSignal.sigwinch.watch().listen((_) {
        requestRedraw();
      });

      // Handle Ctrl+C gracefully on Unix-like systems
      ProcessSignal.sigint.watch().listen((_) async {
        stdout.writeln('Exiting atTalk TUI...');

        // Call cleanup function if available
        if (onCleanup != null) {
          try {
            await onCleanup!();
          } catch (e) {
            stdout.writeln('⚠️ Cleanup error: $e');
          }
        }

        exit(0);
      });
    }

    // Timer for redraw requests
    Timer.periodic(Duration(milliseconds: 100), (_) {
      if (redrawRequested) {
        draw();
        redrawRequested = false;
      }
    });

    // Reset input state
    inputBuffer = '';
    inputCursorPos = 0;

    // Use StreamSubscription approach for better control
    late StreamSubscription<List<int>> mainSubscription;
    List<int> escapeSequence = [];
    bool inEscapeSequence = false;

    mainSubscription = stdin.listen((charCodes) async {
      for (int charCode in charCodes) {
        // Handle panel input first
        if (_showingHelpPanel) {
          if (charCode == 27 || charCode == 13 || charCode == 10) {
            // Escape key, Enter, or newline - close help panel
            _showingHelpPanel = false;
            draw(); // Restore screen
          }
          continue;
        }

        if (_showingParticipantsPanel) {
          if (_participantsInputMode) {
            // Handle input mode for participants panel
            if (charCode == 27) {
              // Escape - cancel input
              _participantsInputMode = false;
              _participantsInputBuffer = '';
              _participantsInputAction = 0;
              _drawParticipantsPanel();
            } else if (charCode == 13 || charCode == 10) {
              // Enter - submit input
              await _handleParticipantsInput();
              _participantsInputMode = false;
              _participantsInputBuffer = '';
              _participantsInputAction = 0;
              _drawParticipantsPanel();
            } else if (charCode == 127 || charCode == 8) {
              // Backspace
              if (_participantsInputBuffer.isNotEmpty) {
                _participantsInputBuffer = _participantsInputBuffer.substring(
                  0,
                  _participantsInputBuffer.length - 1,
                );
                _drawParticipantsPanel();
              }
            } else if (charCode >= 32 && charCode <= 126) {
              // Printable characters
              _participantsInputBuffer += String.fromCharCode(charCode);
              _drawParticipantsPanel();
            }
          } else {
            // Handle navigation mode for participants panel
            if (charCode == 27 || charCode == 13 || charCode == 10) {
              // Escape key, Enter, or newline - close participants panel
              _showingParticipantsPanel = false;
              _participantsInputMode = false;
              _participantsInputBuffer = '';
              _participantsInputAction = 0;
              _participantsScroll = 0;
              draw(); // Restore screen
            } else if (charCode == 106) {
              // 'j' - scroll down
              if (activeSession != null) {
                final session = sessions[activeSession!]!;
                final participants = [
                  myAtSign,
                  ...session.participants.where((p) => p != myAtSign),
                ];
                final maxVisible = 10; // Approximate visible count
                if (_participantsScroll < participants.length - maxVisible) {
                  _participantsScroll++;
                  _drawParticipantsPanel();
                }
              }
            } else if (charCode == 107) {
              // 'k' - scroll up
              if (_participantsScroll > 0) {
                _participantsScroll--;
                _drawParticipantsPanel();
              }
            } else if (charCode == 114) {
              // 'r' - rename group
              if (activeSession != null) {
                final session = sessions[activeSession!]!;
                if (session.participants.length >= 3) {
                  _participantsInputAction = 1;
                  _participantsInputMode = true;
                  _participantsInputBuffer = session.groupName ?? '';
                  _participantsInputPrompt = 'Enter new group name:';
                  _drawParticipantsPanel();
                }
              }
            } else if (charCode == 97) {
              // 'a' - add participant
              _participantsInputAction = 2;
              _participantsInputMode = true;
              _participantsInputBuffer = '';
              _participantsInputPrompt = 'Enter atSign to add:';
              _drawParticipantsPanel();
            } else if (charCode == 100) {
              // 'd' - remove participant (delete)
              if (activeSession != null) {
                final session = sessions[activeSession!]!;
                if (session.participants.length > 2) {
                  _participantsInputAction = 3;
                  _participantsInputMode = true;
                  _participantsInputBuffer = '';
                  _participantsInputPrompt = 'Enter atSign to remove:';
                  _drawParticipantsPanel();
                }
              }
            }
          }
          continue;
        }

        // Handle escape sequences (arrow keys)
        if (charCode == 27) {
          // ESC
          escapeSequence = [27];
          inEscapeSequence = true;
          continue;
        }

        if (inEscapeSequence) {
          escapeSequence.add(charCode);

          // Check for complete arrow key sequences: ESC [ A/B/C/D
          if (escapeSequence.length == 3 && escapeSequence[1] == 91) {
            // ESC [
            switch (escapeSequence[2]) {
              case 65: // Up arrow (ESC [ A)
                scrollUp();
                requestRedraw();
                break;
              case 66: // Down arrow (ESC [ B)
                scrollDown();
                requestRedraw();
                break;
              case 67: // Right arrow (ESC [ C)
                if (inputBuffer.isNotEmpty) {
                  // Input has content - move cursor in input field
                  if (inputCursorPos < inputBuffer.length) {
                    inputCursorPos++;
                    updateInputDisplay();
                  }
                } else {
                  // Input is empty - navigate to next session
                  nextWindow();
                  requestRedraw();
                }
                break;
              case 68: // Left arrow (ESC [ D)
                if (inputBuffer.isNotEmpty) {
                  // Input has content - move cursor in input field
                  if (inputCursorPos > 0) {
                    inputCursorPos--;
                    updateInputDisplay();
                  }
                } else {
                  // Input is empty - navigate to previous session
                  prevWindow();
                  requestRedraw();
                }
                break;
            }
            inEscapeSequence = false;
            escapeSequence.clear();
            continue;
          }
          // Reset if we get an unexpected sequence
          if (escapeSequence.length > 5) {
            inEscapeSequence = false;
            escapeSequence.clear();
          }
          continue;
        }

        // Handle regular characters
        if (charCode == 12) {
          // Ctrl+L - refresh screen immediately
          draw();
          continue;
        } else if (charCode == 3) {
          // Ctrl+C - exit immediately
          mainSubscription.cancel();
          stdout.writeln('Exiting atTalk TUI...');
          exit(0);
        } else if (charCode == 13 || charCode == 10) {
          // Enter
          String input = inputBuffer.trim();
          inputBuffer = '';
          inputCursorPos = 0;
          inputScrollOffset = 0;

          // Clear the input line
          final termHeight = stdout.hasTerminal ? stdout.terminalLines : 24;
          stdout.write('\x1b[$termHeight;1H\x1b[K> ');

          // Check if we're waiting for a group name
          if (_waitingForGroupName &&
              _pendingParticipants != null &&
              _pendingSessionKey != null) {
            _waitingForGroupName = false;
            var groupName = input.isNotEmpty ? input : null;
            var oldSessionKey = _pendingSessionKey!;
            var oldSession = sessions[oldSessionKey]!;

            // Generate new session key for the group
            var newSessionKey = generateSessionKey(_pendingParticipants!);

            // If the session key changes (individual to group), migrate the session
            if (newSessionKey != oldSessionKey) {
              // Create new session with group participants and name
              addSession(newSessionKey, _pendingParticipants!, groupName);

              // Transfer all messages from old session to new session
              sessions[newSessionKey]!.messages.addAll(oldSession.messages);

              // Remove old session
              sessions.remove(oldSessionKey);

              // Switch to new session
              activeSession = newSessionKey;
              windowOffset = sessionList.indexOf(newSessionKey);
            } else {
              // Same session key, just update participants and group name
              oldSession.participants.clear();
              oldSession.participants.addAll(_pendingParticipants!);
              oldSession.groupName = groupName;
            }

            // Clear the prompt message (it was the last one added)
            if (sessions[activeSession!]!.messages.isNotEmpty &&
                sessions[activeSession!]!.messages.last.contains(
                  '[Enter a name for this group',
                )) {
              sessions[activeSession!]!.messages.removeLast();
            }

            var displayName = groupName?.isNotEmpty == true
                ? groupName!
                : 'Unnamed Group';
            addMessage(
              activeSession!,
              '[Group "$displayName" created]',
              incoming: true,
            );

            // Notify other participants of the new group membership
            if (onGroupMembershipChange != null) {
              var session = sessions[activeSession!]!;
              // Use a small delay to ensure the session migration is complete
              Future.delayed(Duration(milliseconds: 100), () {
                onGroupMembershipChange!(
                  activeSession!,
                  session.participants.toList(),
                  session.groupName,
                );
              });
            }

            // Clear pending state
            _pendingParticipants = null;
            _pendingSessionKey = null;
            requestRedraw();
            return;
          }

          if (input == '/?') {
            await showHelpPanel();
            return;
          } else if (input.startsWith('/switch ')) {
            var query = input.substring(8).trim();
            var bestMatch = findBestMatch(query);
            if (bestMatch != null) {
              switchSession(bestMatch);
            } else {
              // Create a new session if no match found
              switchSession(query);
            }
          } else if (input.startsWith('/new ')) {
            var rest = input.substring(5).trim();
            var ids = rest
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (ids.length == 1) {
              // Individual chat: include both sender and receiver in participants
              var individualParticipants = {myAtSign, ids[0]}.toList()..sort();
              addSession(ids[0], individualParticipants);
              switchSession(ids[0]);
            } else if (ids.length > 1) {
              // Group chat: include myself in the participants list for consistency
              ids.add(myAtSign);
              var allParticipants = ids.toSet().toList()..sort();

              // For /new command, always create a unique session key to avoid reusing existing groups
              var timestamp = DateTime.now().millisecondsSinceEpoch;
              var groupKey = '${allParticipants.join(',')}#$timestamp';

              // Create and switch to the new group session immediately
              // Use direct session creation to ensure a fresh session
              sessions[groupKey] = ChatSession(groupKey, allParticipants);
              activeSession = groupKey;

              // Set up for group name prompting
              _waitingForGroupName = true;
              _pendingParticipants = allParticipants;
              _pendingSessionKey = groupKey;

              // Add the prompt message to the clean session
              addMessage(
                groupKey,
                '[Enter a name for this group (or press Enter for no name):]',
                incoming: true,
              );
              requestRedraw();
            }
          } else if (input == '/delete') {
            if (activeSession != null) deleteSession(activeSession!);
          } else if (input.startsWith('/rename ')) {
            var newName = input.substring(8).trim();
            if (activeSession != null) {
              var session = sessions[activeSession!]!;
              session.groupName = newName.isNotEmpty ? newName : null;

              var displayName = session.groupName ?? 'Unnamed Group';
              addMessage(
                activeSession!,
                '[Group renamed to "$displayName"]',
                incoming: true,
              );

              // Notify other participants of the rename
              if (onGroupRename != null) {
                onGroupRename!(activeSession!, newName);
              }

              requestRedraw();
            }
          } else if (input.startsWith('/add ')) {
            var newParticipant = input.substring(5).trim();
            if (activeSession != null && newParticipant.isNotEmpty) {
              var session = sessions[activeSession!]!;
              if (!session.participants.contains(newParticipant)) {
                // Simply add the participant to the existing session
                session.participants.add(newParticipant);

                addMessage(
                  activeSession!,
                  '[Added $newParticipant to the chat]',
                  incoming: true,
                );

                // Notify other participants of the membership change
                onGroupMembershipChange?.call(
                  activeSession!,
                  session.participants.toList(),
                  session.groupName,
                );
              } else {
                addMessage(
                  activeSession!,
                  '[Participant $newParticipant is already in this chat]',
                  incoming: true,
                );
              }
            }
          } else if (input.startsWith('/remove ')) {
            var participantToRemove = input.substring(8).trim();
            if (activeSession != null && participantToRemove.isNotEmpty) {
              var session = sessions[activeSession!]!;
              if (session.participants.contains(participantToRemove)) {
                // Don't allow removing yourself from the chat
                if (participantToRemove != myAtSign) {
                  // Simply remove from the current session, preserving group name and messages
                  session.participants.remove(participantToRemove);
                  addMessage(
                    activeSession!,
                    '[Removed $participantToRemove from the chat]',
                    incoming: true,
                  );

                  // Notify other participants of the membership change
                  if (onGroupMembershipChange != null) {
                    onGroupMembershipChange!(
                      activeSession!,
                      session.participants.toList(),
                      session.groupName,
                    );
                  }
                } else {
                  // Show error message - can't remove yourself
                  addMessage(
                    activeSession!,
                    '[Cannot remove yourself from chat]',
                    incoming: true,
                  );
                }
              } else {
                // Show error message - participant not found
                addMessage(
                  activeSession!,
                  '[Participant $participantToRemove not found in chat]',
                  incoming: true,
                );
              }
            }
          } else if (input == '/list') {
            await showParticipantsPanel();
            return;
          } else if (input == '/exit') {
            mainSubscription.cancel();
            stdout.writeln('Exiting atTalk TUI...');

            // Call cleanup function if available
            if (onCleanup != null) {
              try {
                await onCleanup!();
              } catch (e) {
                stdout.writeln('⚠️ Cleanup error: $e');
              }
            }

            exit(
              0,
            ); // Force exit the program without trying to reset stdin modes
          } else if (activeSession != null && input.isNotEmpty) {
            // CRITICAL: Preserve message sending functionality
            addMessage(activeSession!, input);
            if (onSend != null) {
              onSend!(activeSession!, input);
            }
          }
          draw();
        } else if (charCode == 127 || charCode == 8) {
          // Backspace/Delete
          if (inputBuffer.isNotEmpty && inputCursorPos > 0) {
            inputBuffer =
                inputBuffer.substring(0, inputCursorPos - 1) +
                inputBuffer.substring(inputCursorPos);
            inputCursorPos--;
            updateInputDisplay();
          }
        } else if (charCode >= 32 && charCode <= 126) {
          // Printable characters
          String char = String.fromCharCode(charCode);

          // Hide help hint when user starts typing
          if (showHelpHint) {
            showHelpHint = false;
          }

          inputBuffer =
              inputBuffer.substring(0, inputCursorPos) +
              char +
              inputBuffer.substring(inputCursorPos);
          inputCursorPos++;
          updateInputDisplay();
        }
      }
    });

    // Keep the main subscription alive
    await mainSubscription.asFuture();

    stdin.echoMode = true;
    stdin.lineMode = true;
  }
}
