import 'dart:typed_data';
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
