// Keep rotation on the Markdown reference, leaving the source photo intact.
final _rotationSuffix = RegExp(r'#lunarix-turn=([1-3])$');

int noteImageTurns(String uri) =>
    int.tryParse(_rotationSuffix.firstMatch(uri)?.group(1) ?? '') ?? 0;

String noteImageSource(String uri) => uri.replaceFirst(_rotationSuffix, '');

String rotateNoteImage(String uri, int delta) {
  final turns = (noteImageTurns(uri) + delta) % 4;
  final source = noteImageSource(uri);
  return turns == 0 ? source : '$source#lunarix-turn=$turns';
}
