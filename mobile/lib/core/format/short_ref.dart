/// Short, speakable reference for a server id: '#' + the last 6 letters/digits,
/// uppercased ("…-04826f" → "#04826F"). '#—' when the id has none.
String shortRef(String id) {
  final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (compact.isEmpty) {
    return '#—';
  }
  return '#${compact.length <= 6 ? compact : compact.substring(compact.length - 6)}';
}
