import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class PptxToText {
  static String extractText(Uint8List bytes, {int? maxSlides}) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    // Collect slide files: ppt/slides/slideN.xml
    final slideFiles = archive.files
        .where((f) => f.isFile && f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final buffer = StringBuffer();
    int processed = 0;
    for (final file in slideFiles) {
      if (maxSlides != null && processed >= maxSlides) break;
      final data = file.content as List<int>;
      final xmlStr = utf8.decode(data, allowMalformed: true);
      final doc = XmlDocument.parse(xmlStr);
      // Extract all <a:t> text nodes (PowerPoint text runs)
      final texts = doc.findAllElements('a:t');
      final slideText = texts.map((e) => e.text).where((t) => t.trim().isNotEmpty).join(' ');
      if (slideText.isNotEmpty) {
        buffer.writeln(slideText.trim());
        buffer.writeln();
      }
      processed++;
    }

    return buffer.toString().trim();
  }
}


