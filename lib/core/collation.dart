/// Alphabetical order of names shown to the user (exercises, programs, folders, filter labels).
library;

/// Sort key of a name in the German alphabetical order (DIN 5007-1): case-insensitive, the
/// umlauts sorted as their base vowel (ä → a, ö → o, ü → u) and ß as ss – plain code-point
/// order puts "Überzüge" after "Zottman Curl". English names are not affected.
String collationKey(String s) => s.toLowerCase().replaceAll('ä', 'a').replaceAll('ö', 'o').replaceAll('ü', 'u').replaceAll('ß', 'ss');

/// Compares [a] and [b] in the German alphabetical order ([collationKey]); names equal there
/// ("Bar" / "Bär") in a fixed order.
int compareNames(String a, String b) {
  final c = collationKey(a).compareTo(collationKey(b));
  return c != 0 ? c : a.compareTo(b);
}
