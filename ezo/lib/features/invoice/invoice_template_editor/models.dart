import 'dart:typed_data';
import 'package:flutter/material.dart';
// --- Models ---

class Template {
  final String id;
  final String name;
  final String industry;
  final String format;
  final String style;
  final String image;
  final String metadata;
  final String? tag;
  final Color? styleColor;

  Template({
    required this.id,
    required this.name,
    required this.industry,
    required this.format,
    required this.style,
    required this.image,
    required this.metadata,
    this.tag,
    this.styleColor,
  });
}

class InvoiceItem {
  String id;
  String desc;
  String details;
  double qty;
  double rate;
  String hsnCode;
  double cgstRate;
  double sgstRate;
  double igstRate;
  double discount;

  InvoiceItem({
    required this.id,
    required this.desc,
    required this.details,
    required this.qty,
    required this.rate,
    this.hsnCode = '',
    this.cgstRate = 0.0,
    this.sgstRate = 0.0,
    this.igstRate = 0.0,
    this.discount = 0.0,
  });

  double get amount => qty * rate;
  double get taxableValue => amount - discount;
  double get cgstAmount => taxableValue * (cgstRate / 100);
  double get sgstAmount => taxableValue * (sgstRate / 100);
  double get igstAmount => taxableValue * (igstRate / 100);
}

class InvoiceData {
  String businessName;
  String businessEmail;
  String businessPhone;
  String businessAddress;
  String gstin;
  String clientName;
  String clientAddress;
  String clientPhone;
  String clientEmail;
  String clientGstin;
  String taxLabel;
  double taxRate;
  int themeColorArgb;
  String fontFamily;
  List<InvoiceItem> items;
  String notes;
  bool isThermal;
  int thermalWidth;
  bool showTaxBreakdown;
  bool showLogo;
  bool showBusinessAddress;
  bool showClientContact;
  bool showNotes;
  bool showBankDetails;
  bool showUpiQr;
  String? logoLocalPath;
  String? logoPath;
  Uint8List? logoBytes;
  String? paymentMethod;
  String paymentStatus;
  String invoiceNumber;
  DateTime invoiceDate;
  DateTime? dueDate;
  double totalDiscount;
  String totalDiscountLabel;
  double roundOff;
  String amountInWords;
  String bankName;
  String bankAccountNo;
  String bankIfsc;
  String upiId;
  String termsAndConditions;
  String authorizedSignatory;
  String? tableNumber;
  String? shippingAddress;
  double discountAmount;

  InvoiceData({
    required this.businessName,
    required this.businessEmail,
    required this.businessPhone,
    required this.businessAddress,
    required this.gstin,
    required this.clientName,
    required this.clientAddress,
    this.clientPhone = '',
    this.clientEmail = '',
    this.clientGstin = '',
    required this.taxLabel,
    required this.taxRate,
    required this.themeColorArgb,
    required this.fontFamily,
    required this.items,
    required this.notes,
    required this.isThermal,
    this.thermalWidth = 80,
    this.showTaxBreakdown = true,
    this.showLogo = true,
    this.showBusinessAddress = true,
    this.showClientContact = false,
    this.showNotes = true,
    this.showBankDetails = false,
    this.showUpiQr = false,
    this.logoPath,
    this.logoBytes,
    this.paymentMethod,
    this.paymentStatus = 'COMPLETED',
    this.invoiceNumber = '',
    DateTime? invoiceDate,
    this.dueDate,
    this.totalDiscount = 0.0,
    this.totalDiscountLabel = 'Discount',
    this.roundOff = 0.0,
    this.amountInWords = '',
    this.bankName = '',
    this.bankAccountNo = '',
    this.bankIfsc = '',
    this.upiId = '',
    this.termsAndConditions = '',
    this.authorizedSignatory = '',
    this.tableNumber,
    this.shippingAddress,
    this.discountAmount = 0.0,
  }) : invoiceDate = invoiceDate ?? DateTime.now();

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.amount);
  double get taxAmount {
    final itemTax = cgstTotal + sgstTotal + igstTotal;
    // Use per-item GST when products have rates set; fall back to company-level rate.
    return itemTax > 0 ? itemTax : subtotal * (taxRate / 100);
  }
  double get total => subtotal + taxAmount;
  double get cgstTotal => items.fold(0.0, (sum, item) => sum + item.cgstAmount);
  double get sgstTotal => items.fold(0.0, (sum, item) => sum + item.sgstAmount);
  double get igstTotal => items.fold(0.0, (sum, item) => sum + item.igstAmount);
  double get grandTotal => total + roundOff;

  /// For Flutter UI code that needs the Color object.
  Color get themeColor => Color(themeColorArgb);
}

// --- Mapper Extensions ---
extension SaleMapper on InvoiceData {
  void updateWithSale(dynamic sale) {
    // We'll use dynamic because Sale import might create circular dependencies
    // Alternatively, we just map everything manually in the Checkout flow.
  }
}
