import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'download_helper.dart';

Future<Uint8List> _generateCsv({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  String? shopName,
  String? shopAddress,
}) async {
  final buf = StringBuffer();

  String esc(String s) => '"${s.replaceAll('"', '""')}"';

  if (shopName != null && shopName.isNotEmpty) {
    buf.writeln(esc(shopName));
    if (shopAddress != null && shopAddress.isNotEmpty) {
      buf.writeln(esc(shopAddress));
    }
    buf.writeln();
  }

  buf.writeln(esc(title));
  buf.writeln();
  buf.writeln(headers.map(esc).join(','));
  for (final row in rows) {
    buf.writeln(row.map(esc).join(','));
  }

  return Uint8List.fromList(utf8.encode(buf.toString()));
}

Future<Uint8List> _generatePdf({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  String? shopName,
  String? shopAddress,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      header: (context) {
        if (shopName == null || shopName.isEmpty) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(shopName,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Text(shopAddress,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            pw.Divider(),
          ],
        );
      },
      footer: (context) => pw.Text(
        'Generated ${DateTime.now().toString().substring(0, 19)}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
        textAlign: pw.TextAlign.center,
      ),
      build: (context) => [
        pw.Center(
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColors.indigo)),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            for (var i = 0; i < headers.length; i++)
              i: pw.Alignment.centerLeft,
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            verticalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            top: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            left: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            right: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

Future<void> showExportDialog(
  BuildContext context, {
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  String? shopName,
  String? shopAddress,
}) async {
  final format = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Export Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_chart, color: Colors.green),
            ),
            title: const Text('CSV (Excel-compatible)'),
            subtitle: const Text('Open in any spreadsheet app'),
            onTap: () => Navigator.pop(context, 'csv'),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red),
            ),
            title: const Text('PDF'),
            subtitle: const Text('View or share as document'),
            onTap: () => Navigator.pop(context, 'pdf'),
          ),
        ],
      ),
    ),
  );

  if (format == null || context.mounted == false) return;

  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final Uint8List bytes;
    final String ext;

    if (format == 'csv') {
      bytes = await _generateCsv(
        title: title,
        headers: headers,
        rows: rows,
        shopName: shopName,
        shopAddress: shopAddress,
      );
      ext = 'csv';
    } else {
      bytes = await _generatePdf(
        title: title,
        headers: headers,
        rows: rows,
        shopName: shopName,
        shopAddress: shopAddress,
      );
      ext = 'pdf';
    }

    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    final safeName =
        title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');

    if (kIsWeb) {
      await downloadBytes('$safeName.$ext', bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Download started'), backgroundColor: Colors.green),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeName.$ext');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              format == 'csv' ? Icons.table_chart : Icons.picture_as_pdf,
              color: format == 'csv' ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Export Successful'),
          ],
        ),
        content: Text('${format.toUpperCase()} saved:\n${file.path}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(file.path)], text: title);
            },
            child: const Text('Share'),
          ),
          if (!kIsWeb)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                OpenFilex.open(file.path);
              },
              child: const Text('Open'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}
