/// Short, speakable reference for a server id: '#' + the last 4 letters/digits,
/// uppercased ("…-04826f" → "#826F"). '#—' when the id has none.
///
/// OPEN-011 / DEC-PROD-047: one code everywhere (customer, merchant, driver,
/// support) so the handover code matches what every screen shows.
String shortRef(String id) {
  final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (compact.isEmpty) {
    return '#—';
  }
  return '#${compact.length <= 4 ? compact : compact.substring(compact.length - 4)}';
}
