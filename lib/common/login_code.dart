/// The authorization code in what the user pasted: the bare code, `code=…`,
/// or the whole redirect URL copied from the address bar.
String extractLoginCode(String input) {
  final text = input.trim();
  if (!text.contains('code=')) return text;
  final fromQuery = Uri.tryParse(text)?.queryParameters['code'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  final tail = text.substring(text.lastIndexOf('code=') + 'code='.length);
  return tail.split(RegExp(r'[&#\s]')).first;
}
