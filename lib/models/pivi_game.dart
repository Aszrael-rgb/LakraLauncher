class PiviGame {
  const PiviGame({
    required this.title,
    required this.link,
    this.featuredImageUrl,
  });

  final String title;
  final Uri link;
  final Uri? featuredImageUrl;

  factory PiviGame.fromJson(Map<String, dynamic> json) {
    final titleObject = json['title'];
    final rawTitle = titleObject is Map<String, dynamic>
        ? titleObject['rendered'] as String? ?? ''
        : '';
    final title = decodeHtmlEntities(
      rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
    );

    final rawLink = json['link'] as String? ?? '';
    final link = Uri.tryParse(rawLink);
    if (link == null || !link.hasScheme) {
      throw const FormatException(
        'La entrada de WordPress no contiene un enlace válido.',
      );
    }

    Uri? featuredImageUrl;
    final embedded = json['_embedded'];
    if (embedded is Map<String, dynamic>) {
      final media = embedded['wp:featuredmedia'];
      if (media is List &&
          media.isNotEmpty &&
          media.first is Map<String, dynamic>) {
        final source = (media.first as Map<String, dynamic>)['source_url'];
        if (source is String) featuredImageUrl = Uri.tryParse(source);
      }
    }

    return PiviGame(
      title: title.isEmpty ? 'Entrada sin título' : title,
      link: link,
      featuredImageUrl: featuredImageUrl,
    );
  }
}

String decodeHtmlEntities(String value) {
  const named = {
    '&amp;': '&',
    '&quot;': '"',
    '&#039;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };
  var result = value;
  for (final entry in named.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (match) {
    final code = match[1]!;
    final value = code.startsWith('x')
        ? int.tryParse(code.substring(1), radix: 16)
        : int.tryParse(code);
    return value == null ? match[0]! : String.fromCharCode(value);
  });
}
