import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes(String filename, Uint8List bytes) async {
  final mime = filename.endsWith('.pdf')
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrl(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
