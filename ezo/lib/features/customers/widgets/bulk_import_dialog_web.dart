// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert' as convert;
import 'dart:html' as html;

/// Downloads a file in the browser using multiple fallback methods.
///
/// Production-grade version that:
/// 1. Uses anchor.click() first
/// 2. Falls back to window.open() which works even when anchor fails
/// 3. Final fallback to data URI via window.open()
void downloadBlobAsFile(List<int> bytes, String fileName, String mimeType) {
  try {
    // Method 1: Create Blob URL
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create and click anchor
    final anchor = html.document.createElement('a');
    anchor.setAttribute('href', url);
    anchor.setAttribute('download', fileName);
    anchor.style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // Method 2: Also try window.open as additional trigger
    html.window.open(url, '_blank');

    // Revoke after delay - use Future.delayed instead of setTimeout
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  } catch (e) {
    // Method 3: Fallback to data URI via window.open
    _downloadUsingDataUri(bytes, fileName, mimeType);
  }
}

/// Fallback: Data URI method via window.open (most reliable)
void _downloadUsingDataUri(List<int> bytes, String fileName, String mimeType) {
  try {
    final base64 = convert.base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$base64';

    // window.open with data URL triggers download in new tab
    html.window.open(dataUrl, '_blank');
  } catch (e) {
    // Silently fail
  }
}

// Legacy fallback for compatibility
void downloadBlobAsFileFallback(
  List<int> bytes,
  String fileName,
  String mimeType,
) {
  try {
    _downloadUsingDataUri(bytes, fileName, mimeType);
  } catch (e) {
    // Silently fail
  }
}
