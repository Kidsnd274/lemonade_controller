import 'dart:ui';

/// Maps a quantization Q-level (1–8) to a color.
/// Q8 = best quality (green), Q1 = lowest quality (red).
Color quantizationColor(int? level) {
  return switch (level) {
    1 => const Color(0xFFD32F2F),
    2 => const Color(0xFFE64A19),
    3 => const Color(0xFFF57C00),
    4 => const Color(0xFFFFA000),
    5 => const Color(0xFFCDDC39),
    6 => const Color(0xFF8BC34A),
    7 => const Color(0xFF4CAF50),
    8 => const Color(0xFF2E7D32),
    _ => const Color(0xFF9E9E9E),
  };
}

/// Returns a readable foreground color (black or white) for a given Q-level background.
Color quantizationForegroundColor(int? level) {
  return switch (level) {
    1 || 2 || 7 || 8 => const Color(0xFFFFFFFF),
    _ => const Color(0xFF000000),
  };
}
