/// Extracts a normalized quantization token from a model checkpoint.
///
/// Quantizations may be supplied directly after a colon, embedded in a GGUF
/// filename, or included in a colonless repository name. The last bounded
/// token wins so model names containing unrelated letters or digits are not
/// treated as quantizations.
String extractQuantization(String checkpoint) {
  final normalized = checkpoint.toUpperCase();
  final matches = RegExp(
    r'(?:^|[^A-Z0-9])((?:UD-)?(?:IQ|Q)\d(?:_[A-Z0-9]+)+|BF16|F16|F32)(?=$|[^A-Z0-9])',
  ).allMatches(normalized);

  if (matches.isEmpty) return 'Unknown';
  return matches.last.group(1)!;
}
