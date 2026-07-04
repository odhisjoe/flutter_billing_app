// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void browserPrint(String text) {
  final content = '''
<!DOCTYPE html>
<html>
<head>
  <title>Receipt</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      font-size: 13px;
      width: 80mm;
      margin: 0 auto;
      padding: 16px;
    }
    pre {
      white-space: pre-wrap;
      font-family: 'Courier New', monospace;
      font-size: 13px;
      margin: 0;
    }
    @media print {
      @page { margin: 0; size: 80mm auto; }
      body { padding: 8mm; }
    }
  </style>
</head>
<body>
  <pre>$text</pre>
  <script>window.print();</script>
</body>
</html>''';

  final uri = Uri.dataFromString(content, mimeType: 'text/html');
  html.window.open(uri.toString(), '_blank');
}
