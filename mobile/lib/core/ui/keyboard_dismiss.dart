import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide keyboard dismissal (wired in `DealGoApp`'s `MaterialApp.builder`):
/// a tap anywhere outside the focused text field closes the keyboard.
///
/// It runs on tap *up* (after buttons have handled the tap), so a button the
/// keyboard is about to uncover still gets its press. Drags are left to
/// scroll views ([DealGoScrollBehavior] dismisses on drag) and maps keep
/// their pan. Selection handles, the text toolbar and anything wrapped in
/// [TextFieldTapRegion] (chat / reply composers with their send buttons)
/// count as inside the field.
class KeyboardDismissOnTapOutside extends StatefulWidget {
  const KeyboardDismissOnTapOutside({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardDismissOnTapOutside> createState() =>
      _KeyboardDismissOnTapOutsideState();
}

class _KeyboardDismissOnTapOutsideState
    extends State<KeyboardDismissOnTapOutside> {
  final _downAt = <int, Offset>{};

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: (intent) {
        final down = intent.pointerDownEvent;
        _downAt[down.pointer] = down.position;
        return null;
      },
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: (intent) {
            final up = intent.pointerUpEvent;
            final start = _downAt.remove(up.pointer);
            if (start != null && (up.position - start).distance <= kTouchSlop) {
              intent.focusNode.unfocus();
            }
            return null;
          },
        ),
  };

  @override
  Widget build(BuildContext context) =>
      Actions(actions: _actions, child: widget.child);
}

/// Scroll views close the keyboard as soon as the user drags them.
class DealGoScrollBehavior extends MaterialScrollBehavior {
  const DealGoScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}
