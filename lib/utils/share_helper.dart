import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Helper class for sharing text as beautiful images
class ShareHelper {
  static Future<void> shareTextAsImage({
    required BuildContext context,
    required String text,
    required String source,
    required bool isArabic,
    Color? backgroundColor,
  }) async {
    final controller = ScreenshotController();
    final sepiaColor = backgroundColor ?? const Color(0xFFF4ECD8);
    final width = MediaQuery.of(context).size.width * 0.9;
    
    final widget = Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: sepiaColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.brown.shade400,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quote icon
            Icon(
              Icons.format_quote_rounded,
              color: Colors.brown.shade700,
              size: 40,
            ),
            const SizedBox(height: 20),
            // Quote text
            Text(
              text,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                height: 1.6,
                color: Colors.brown.shade900,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 30),
            // Attribution
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isArabic
                    ? '- $source -\nفيودور دوستويفسكي'
                    : '- $source -\nFyodor Dostoyevsky',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  color: Colors.brown.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final image = await controller.captureFromWidget(
        widget,
        pixelRatio: 2.0,
      );

      if (image.isNotEmpty) {
        final tempPath = await _saveImageToTemp(image);
        if (tempPath != null) {
          await Share.shareXFiles(
            [XFile(tempPath)],
            text: isArabic ? 'اقتباس من $source' : 'Quote from $source',
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating image: $e');
    }
  }

  static Future<String?> _saveImageToTemp(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }
}

