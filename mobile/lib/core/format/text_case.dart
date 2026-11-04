/// Uppercases the first letter of a merchant-entered label.
///
/// Menu categories are free text stored verbatim, so "món chính" must still
/// read as "Món chính" wherever the customer sees it.
String capitalizeFirstLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final first = String.fromCharCode(trimmed.runes.first);
  return '${first.toUpperCase()}${trimmed.substring(first.length)}';
}
