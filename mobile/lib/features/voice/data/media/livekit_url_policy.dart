/// LiveKit signalling URL rule: release builds only join `wss://` (TLS, the self-hosted
/// server behind Caddy or LiveKit Cloud). Debug/profile builds also accept `ws://` for the
/// local docker LiveKit on the dev machine's LAN IP.
void assertLiveKitUrlAllowed(String url, {required bool isRelease}) {
  final uri = Uri.tryParse(url.trim());
  final scheme = uri?.scheme ?? '';
  if (uri == null || uri.host.isEmpty || (scheme != 'wss' && scheme != 'ws')) {
    throw StateError('LiveKit URL must be ws:// or wss://');
  }
  if (isRelease && scheme != 'wss') {
    throw StateError('Release builds only join LiveKit over wss://');
  }
}
