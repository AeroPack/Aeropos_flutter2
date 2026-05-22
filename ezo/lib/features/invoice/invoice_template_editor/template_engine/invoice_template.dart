import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models.dart';

abstract class InvoiceTemplate {
  String get id;
  String get name;
  String get industry;
  String get format;
  String get styleName;
  String get previewImagePath;
  Color get badgeColor;
  String get metadata;
  String? get tag;
  bool get isThermal => format.toUpperCase() == 'THERMAL';
  bool get supportsTableNumbers => false;
  bool get supportsShipping => false;
  bool get supportsDiscounts => false;
  bool get supportsTaxBreakdown => false;

  pw.Document buildPdf(InvoiceData data);

  Widget buildFlutterPreview(InvoiceData data);

  InvoiceData getDefaultData();

  pw.MemoryImage? getLogoImage(InvoiceData data) {
    if (data.showLogo && data.logoBytes != null) {
      return pw.MemoryImage(data.logoBytes!);
    }
    return null;
  }

  Widget buildLogoWidget(InvoiceData data, {double size = 60}) {
    if (!data.showLogo) return const SizedBox();

    if (data.logoBytes != null) {
      return Image.memory(data.logoBytes!, height: size, width: size);
    }

    if (data.logoPath != null && data.logoPath!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: data.logoPath!, height: size, width: size);
    }

    return const SizedBox();
  }

  pw.Font? resolvePdfFont(String fontFamily) {
    final lower = fontFamily.toLowerCase();
    if (lower.contains('mono') || lower.contains('courier')) {
      return pw.Font.courier();
    }
    if (lower.contains('playfair') || lower.contains('times')) {
      return pw.Font.times();
    }
    return null;
  }

  pw.Widget wrapWithFont(pw.Widget child, InvoiceData data) {
    final font = resolvePdfFont(data.fontFamily);
    if (font == null) return child;
    return pw.DefaultTextStyle(
      style: pw.TextStyle(font: font),
      child: child,
    );
  }
}
