import 'package:aeropos/features/invoice/invoice_template_editor/models.dart';

/// Describes a single missing or blank field on the invoice.
class InvoiceFieldGap {
  final String key;
  final String label;
  final String category; // 'seller' | 'tax' | 'footer' | 'payment'
  /// Which InvoiceSettings boolean to flip to hide this section entirely.
  /// Null if the field cannot be disabled (e.g., businessName is mandatory).
  final String? disableToggle;
  /// Where to navigate to fill this in.
  /// 'profile' → company profile screen, 'invoice_settings' → invoice settings.
  final String editRoute;

  const InvoiceFieldGap({
    required this.key,
    required this.label,
    required this.category,
    this.disableToggle,
    required this.editRoute,
  });
}

/// Inspects a fully hydrated [InvoiceData] and returns every field that is
/// both visible on the invoice AND currently empty, so the POS screen can
/// warn the shopkeeper before printing.
List<InvoiceFieldGap> checkInvoiceCompleteness(InvoiceData data) {
  final gaps = <InvoiceFieldGap>[];

  // ── Seller details ───────────────────────────────────────────────────────
  if (data.businessName.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'businessName',
      label: 'Business Name',
      category: 'seller',
      disableToggle: null, // mandatory — cannot be disabled
      editRoute: 'company_profile',
    ));
  }

  if (data.showBusinessAddress && data.businessAddress.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'businessAddress',
      label: 'Business Address',
      category: 'seller',
      disableToggle: 'showAddress',
      editRoute: 'company_profile',
    ));
  }

  if (data.businessPhone.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'businessPhone',
      label: 'Business Phone',
      category: 'seller',
      disableToggle: 'showAddress',
      editRoute: 'company_profile',
    ));
  }

  if (data.businessEmail.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'businessEmail',
      label: 'Business Email',
      category: 'seller',
      disableToggle: 'showAddress',
      editRoute: 'company_profile',
    ));
  }

  if (data.gstin.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'gstin',
      label: 'GSTIN / Tax ID',
      category: 'seller',
      disableToggle: 'showTaxBreakdown',
      editRoute: 'company_profile',
    ));
  }

  // ── Tax ──────────────────────────────────────────────────────────────────
  if (data.showTaxBreakdown) {
    if (data.taxLabel.trim().isEmpty) {
      gaps.add(const InvoiceFieldGap(
        key: 'taxLabel',
        label: 'Tax Label (e.g. GST, VAT)',
        category: 'tax',
        disableToggle: 'showTaxBreakdown',
        editRoute: 'company_profile',
      ));
    }
    // Tax rate is per-product (gstRate on each product), not a company setting.
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  if (data.showNotes && data.termsAndConditions.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'termsAndConditions',
      label: 'Terms / Thank-you message',
      category: 'footer',
      disableToggle: 'showFooter',
      editRoute: 'company_profile',
    ));
  }

  if (data.showNotes && data.authorizedSignatory.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'authorizedSignatory',
      label: 'Authorized Signatory',
      category: 'footer',
      disableToggle: 'showFooter',
      editRoute: 'company_profile',
    ));
  }

  // ── Bank / payment ────────────────────────────────────────────────────────
  if (data.showBankDetails) {
    if (data.bankName.trim().isEmpty) {
      gaps.add(const InvoiceFieldGap(
        key: 'bankName',
        label: 'Bank Name',
        category: 'payment',
        disableToggle: 'showBankDetails',
        editRoute: 'company_profile',
      ));
    }
    if (data.bankAccountNo.trim().isEmpty) {
      gaps.add(const InvoiceFieldGap(
        key: 'bankAccountNo',
        label: 'Bank Account Number',
        category: 'payment',
        disableToggle: 'showBankDetails',
        editRoute: 'company_profile',
      ));
    }
    if (data.bankIfsc.trim().isEmpty) {
      gaps.add(const InvoiceFieldGap(
        key: 'bankIfsc',
        label: 'IFSC Code',
        category: 'payment',
        disableToggle: 'showBankDetails',
        editRoute: 'company_profile',
      ));
    }
  }

  if (data.showUpiQr && data.upiId.trim().isEmpty) {
    gaps.add(const InvoiceFieldGap(
      key: 'upiId',
      label: 'UPI ID',
      category: 'payment',
      disableToggle: 'showUpiQr',
      editRoute: 'company_profile',
    ));
  }

  return gaps;
}

/// Category display names used in the warning sheet.
String gapCategoryLabel(String category) {
  switch (category) {
    case 'seller':
      return 'Seller / Business';
    case 'tax':
      return 'Tax';
    case 'footer':
      return 'Footer';
    case 'payment':
      return 'Payment Details';
    default:
      return category;
  }
}
