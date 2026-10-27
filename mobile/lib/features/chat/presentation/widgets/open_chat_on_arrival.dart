import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Query flag a tapped chat push adds to the job page it opens (`?chat=1`).
const chatOnArrivalParam = 'chat';

/// Opens the job's chat once when the page was reached from a chat push
/// (Grab / Uber pattern: a "new message" tap lands in the conversation, the job
/// page stays underneath for back). Wrap the part of the page that only renders
/// once the job is loaded, so the sheet opens over real content.
class OpenChatOnArrival extends StatefulWidget {
  const OpenChatOnArrival({
    required this.onOpen,
    required this.child,
    this.requested,
    super.key,
  });

  final VoidCallback onOpen;
  final Widget child;

  /// Test hook; null reads `?chat=` from the current route.
  final bool? requested;

  @override
  State<OpenChatOnArrival> createState() => _OpenChatOnArrivalState();
}

class _OpenChatOnArrivalState extends State<OpenChatOnArrival> {
  /// The request already handled; a new link (different location) to the
  /// same page reopens the chat, a rebuild of the same one does not.
  String? _handled;

  String? _requestKey() {
    final explicit = widget.requested;
    if (explicit != null) {
      return explicit ? 'explicit' : null;
    }
    try {
      final uri = GoRouterState.of(context).uri;
      final value = uri.queryParameters[chatOnArrivalParam];
      final on = value != null && value.isNotEmpty && value != '0';
      return on ? uri.toString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeOpen();
  }

  @override
  void didUpdateWidget(covariant OpenChatOnArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeOpen();
  }

  void _maybeOpen() {
    final key = _requestKey();
    if (key == null || key == _handled) {
      return;
    }
    _handled = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onOpen();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
