/// Splits source instructions only where the source itself supplies a newline.
/// It intentionally does not infer sentence boundaries or rewrite numbering.
List<String> instructionSteps(String? source) {
  if (source == null || source.trim().isEmpty) return const <String>[];
  return List<String>.unmodifiable(
    source
        .split(RegExp(r'\r\n|\n|\r'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty),
  );
}
