import 'package:flutter/material.dart';
import '../../core/utils/atsign_manager.dart';

class AtsignSelector extends StatefulWidget {
  const AtsignSelector({required this.options, required this.onAtsignSelected, this.selectedAtsign, super.key});

  final Map<String, AtsignInformation> options;
  final Function(String?, String?) onAtsignSelected; // atSign, rootDomain
  final String? selectedAtsign;

  @override
  State<AtsignSelector> createState() => _AtsignSelectorState();
}

class _AtsignSelectorState extends State<AtsignSelector> {
  final focusNode = FocusNode();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.selectedAtsign ?? '');
  }

  @override
  void didUpdateWidget(AtsignSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAtsign != widget.selectedAtsign) {
      controller.text = widget.selectedAtsign ?? '';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  String _normalizeAtsign(String input) {
    if (input.isEmpty) return input;
    if (!input.startsWith('@')) {
      return '@$input';
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (atsign) {
          if (atsign.isEmpty) {
            widget.onAtsignSelected(null, null);
            return;
          }

          final normalized = _normalizeAtsign(atsign);
          if (normalized != atsign) {
            controller.value = TextEditingValue(
              text: normalized,
              selection: TextSelection.collapsed(offset: normalized.length),
            );
          }

          final rootDomain = widget.options[normalized]?.rootDomain;
          widget.onAtsignSelected(normalized, rootDomain);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter an atSign';
          }
          final normalized = _normalizeAtsign(value);
          if (!RegExp(r'^@[a-zA-Z0-9_]+$').hasMatch(normalized)) {
            return 'Please enter a valid atSign (e.g. @alice)';
          }
          return null;
        },
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: 'atSign',
          hintText: 'e.g. @alice',
          prefixIcon: const Icon(Icons.alternate_email),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
          suffixIcon: widget.options.isNotEmpty
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (String atsign) {
                    controller.text = atsign;
                    final rootDomain = widget.options[atsign]?.rootDomain;
                    widget.onAtsignSelected(atsign, rootDomain);
                    // Dismiss keyboard focus when selecting from dropdown
                    focusNode.unfocus();
                  },
                  itemBuilder: (BuildContext context) {
                    return widget.options.keys.map((String atsign) {
                      return PopupMenuItem<String>(
                        value: atsign,
                        child: Row(
                          children: [
                            const Icon(Icons.account_circle, size: 20),
                            const SizedBox(width: 8),
                            Text(atsign),
                          ],
                        ),
                      );
                    }).toList();
                  },
                )
              : null,
        ),
      ),
    );
  }
}
