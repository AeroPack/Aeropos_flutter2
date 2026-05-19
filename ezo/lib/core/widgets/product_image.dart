import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/config/app_config.dart';

class ProductImage extends StatelessWidget {
  final ProductEntity product;
  final double size;
  final double borderRadius;

  const ProductImage({
    super.key,
    required this.product,
    this.size = 80,
    this.borderRadius = 8,
  });

  // Returns null for data URIs — those are rendered via Image.memory.
  String? get _resolvedNetworkUrl {
    final rawUrl = product.imageUrl;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('data:')) return null;
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
  }

  bool get _isDataUri {
    final rawUrl = product.imageUrl;
    return rawUrl != null && rawUrl.startsWith('data:');
  }

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (kIsWeb) {
      if (product.localPath != null && product.localPath!.isNotEmpty) {
        image = CachedNetworkImage(
          imageUrl: product.localPath!,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _imageUrlWidget(),
        );
      } else {
        image = _imageUrlWidget();
      }
    } else {
      // Skip existsSync() — OS filesystem cache lag can cause false negatives
      // immediately after a file write. Let Image.file's async reader decide.
      if (product.localPath != null && product.localPath!.isNotEmpty) {
        image = Image.file(
          File(product.localPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, error, _) {
            debugPrint('[ProductImage] local file load failed: $error | path=${product.localPath}');
            return _imageUrlWidget();
          },
        );
      } else {
        image = _imageUrlWidget();
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: image,
      ),
    );
  }

  /// Renders imageUrl: base64 data URI → Image.memory, HTTP URL → CachedNetworkImage.
  Widget _imageUrlWidget() {
    if (_isDataUri) return _buildBase64Image(product.imageUrl!);
    final url = _resolvedNetworkUrl;
    if (url == null) return _buildFallback();
    debugPrint('[ProductImage] loading network image: $url');
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, error, _) {
        debugPrint('[ProductImage] network load failed: $error | url=$url');
        return _buildFallback();
      },
    );
  }

  Widget _buildBase64Image(String dataUri) {
    try {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) return _buildFallback();
      final bytes = base64Decode(dataUri.substring(commaIndex + 1));
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, error, _) {
          debugPrint('[ProductImage] base64 render failed: $error');
          return _buildFallback();
        },
      );
    } catch (e) {
      debugPrint('[ProductImage] base64 parse error: $e');
      return _buildFallback();
    }
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.grey.shade400,
        size: size * 0.5,
      ),
    );
  }
}
