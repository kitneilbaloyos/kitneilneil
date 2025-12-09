import 'dart:io';
import 'dart:typed_data';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'pptx_to_text.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as ml;
import 'package:flutter/material.dart';

class TextExtractor {
  static const int maxTokens = 8000; // Approximate token limit for Groq
  
  /// Extract text from various file formats
  static Future<String> extractText(String filePath, {Uint8List? fileBytes}) async {
    final extension = filePath.toLowerCase().split('.').last;
    
    // For images on mobile, always use file path (not bytes) to avoid ML Kit issues
    if (['jpg', 'jpeg', 'png', 'bmp', 'gif'].contains(extension)) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      return await _extractFromImage(filePath);
    }
    
    // For other files, use bytes if available (web) or file path (mobile)
    if (fileBytes != null) {
      return await _extractFromBytes(fileBytes, filePath);
    }
    
    // Otherwise, use file path (mobile/desktop)
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    
    switch (extension) {
      case 'docx':
        return await _extractFromDocx(filePath);
      case 'txt':
        return await _extractFromTxt(filePath);
      case 'pdf':
        return await _extractFromPdf(filePath);
      case 'pptx':
        final bytes = await File(filePath).readAsBytes();
        return _cleanText(PptxToText.extractText(bytes));
      default:
        throw Exception('Unsupported file format: $extension');
    }
  }

  /// Extract text from file bytes (for web)
  static Future<String> _extractFromBytes(Uint8List bytes, String filePath) async {
    final extension = filePath.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'docx':
        return _extractFromDocxBytes(bytes);
      case 'txt':
        return _extractFromTxtBytes(bytes);
      case 'pdf':
        return _extractFromPdfBytes(bytes);
      case 'pptx':
        return _cleanText(PptxToText.extractText(bytes));
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'gif':
        return await _extractFromImageBytes(bytes);
      default:
        throw Exception('Unsupported file format: $extension');
    }
  }

  /// Extract text from DOCX files
  static Future<String> _extractFromDocx(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return _extractFromDocxBytes(bytes);
    } catch (e) {
      throw Exception('Failed to extract text from DOCX: $e');
    }
  }

  /// Extract text from DOCX bytes
  static String _extractFromDocxBytes(Uint8List bytes) {
    try {
      final text = docxToText(bytes);
      return _cleanText(text);
    } catch (e) {
      throw Exception('Failed to extract text from DOCX bytes: $e');
    }
  }

  /// Extract text from TXT files
  static Future<String> _extractFromTxt(String filePath) async {
    try {
      final file = File(filePath);
      final text = await file.readAsString();
      return _cleanText(text);
    } catch (e) {
      throw Exception('Failed to extract text from TXT: $e');
    }
  }

  /// Extract text from TXT bytes
  static String _extractFromTxtBytes(Uint8List bytes) {
    try {
      final text = String.fromCharCodes(bytes);
      return _cleanText(text);
    } catch (e) {
      throw Exception('Failed to extract text from TXT bytes: $e');
    }
  }

  /// Extract text from PDF file path
  static Future<String> _extractFromPdf(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return _extractFromPdfBytes(bytes);
    } catch (e) {
      throw Exception('Failed to read PDF: $e');
    }
  }

  /// Extract text from PDF bytes using Syncfusion
  static String _extractFromPdfBytes(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        final pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText.trim());
          buffer.writeln();
        }
      }
      document.dispose();
      return _cleanText(buffer.toString());
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  // Deprecated simplified PPTX method removed. Using PptxToText instead.

  /// Extract text from PPTX bytes with slide selection
  static String _extractFromPptxBytesWithSlides(Uint8List bytes, {int? maxSlides}) {
    try {
      final text = String.fromCharCodes(bytes);
      final cleanText = text.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '');
      
      // If maxSlides is specified, try to limit the content
      if (maxSlides != null && maxSlides > 0) {
        // This is a simplified approach - in a real implementation, 
        // you'd parse the PPTX structure to identify slide boundaries
        final words = cleanText.split(' ');
        final wordsPerSlide = words.length ~/ 10; // Rough estimate: 10 slides
        final maxWords = wordsPerSlide * maxSlides;
        
        if (words.length > maxWords) {
          final limitedWords = words.take(maxWords).join(' ');
          return _cleanText('$limitedWords\n\n[Note: Content limited to approximately $maxSlides slides due to size constraints]');
        }
      }
      
      return _cleanText(cleanText);
    } catch (e) {
      throw Exception('PPTX text extraction is not fully supported. Please convert to DOCX or TXT format.');
    }
  }

  /// Extract text from images using ML Kit OCR
  static Future<String> _extractFromImage(String filePath) async {
    try {
      final inputImage = ml.InputImage.fromFilePath(filePath);
      final textRecognizer = ml.TextRecognizer();
      
      final ml.RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String extractedText = '';
      for (ml.TextBlock block in recognizedText.blocks) {
        for (ml.TextLine line in block.lines) {
          extractedText = '$extractedText${line.text}\n';
        }
      }
      
      await textRecognizer.close();
      return _cleanText(extractedText);
    } catch (e) {
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract text from image bytes using ML Kit OCR
  static Future<String> _extractFromImageBytes(Uint8List bytes) async {
    try {
      // For mobile platforms, we need to use the file path approach instead of bytes
      // because ML Kit requires proper image metadata
      throw Exception('Image processing from bytes is not supported on mobile. Please use file path instead.');
    } catch (e) {
      throw Exception('Failed to extract text from image bytes: $e');
    }
  }

  /// Clean and format extracted text
  static String _cleanText(String text) {
    if (text.isEmpty) return '';
    
    // Remove excessive whitespace and normalize line breaks
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    text = text.trim();
    
    return text;
  }

  /// Chunk text into smaller pieces if it exceeds token limit
  static List<String> chunkText(String text, {int maxTokens = maxTokens}) {
    if (text.length <= maxTokens * 4) { // Rough estimation: 1 token ≈ 4 characters
      return [text];
    }
    
    final chunks = <String>[];
    final words = text.split(' ');
    String currentChunk = '';
    
    for (final word in words) {
      if ((currentChunk + word).length > maxTokens * 4) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
          currentChunk = word;
        }
      } else {
        currentChunk += (currentChunk.isEmpty ? '' : ' ') + word;
      }
    }
    
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }
    
    return chunks;
  }

  /// Process large files with automatic chunking
  static Future<String> processLargeFile(String filePath, {Uint8List? fileBytes, int? maxSlides}) async {
    try {
      // Extract text first
      String extractedText;
      
      if (fileBytes != null) {
        final extension = filePath.toLowerCase().split('.').last;
        if (extension == 'pptx' && maxSlides != null) {
          extractedText = _extractFromPptxBytesWithSlides(fileBytes, maxSlides: maxSlides);
        } else {
          extractedText = await _extractFromBytes(fileBytes, filePath);
        }
      } else {
        extractedText = await extractText(filePath);
      }
      
      // Check if text is too large and needs chunking
      if (extractedText.length > maxTokens * 4) {
        final chunks = chunkText(extractedText);
        if (chunks.length > 1) {
          // Use the first chunk for quiz generation
          return '${chunks.first}\n\n[Note: Large file detected. Using first portion (${chunks.length} total chunks) for quiz generation.]';
        }
      }
      
      return extractedText;
    } catch (e) {
      throw Exception('Failed to process large file: $e');
    }
  }

  /// Get file size in MB
  static Future<double> getFileSizeInMB(String filePath) async {
    final file = File(filePath);
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Check if file format is supported
  static bool isSupportedFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    const supportedFormats = ['docx', 'pptx', 'pdf', 'txt', 'jpg', 'jpeg', 'png', 'bmp', 'gif'];
    return supportedFormats.contains(extension);
  }
}
