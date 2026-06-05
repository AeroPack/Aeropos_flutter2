import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/profile_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../invoice/invoice_template_editor/template_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for company profile fields
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // Read-only

  // Image handling (Reusing profile image as Company Logo for now)
  File? _selectedImage;
  Uint8List? _imageBytes; // for web
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  // ── Invoice settings ──────────────────────────────────────────────────────
  final _taxLabelController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _termsController = TextEditingController();
  final _signatoryController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNoController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _upiIdController = TextEditingController();

  bool _showTaxBreakdown = true;
  bool _showFooter = true;
  bool _showBankDetails = false;
  bool _showUpiQr = false;
  String _activeTemplateId = 'default_a4';
  bool _isSavingInvoiceSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider.notifier).loadProfile();
      _loadInvoiceSettings();
    });
  }

  Future<void> _loadInvoiceSettings() async {
    try {
      final companyId = ref.read(companyIdProvider);
      final repo = ref.read(invoiceTemplateRepositoryProvider);
      final result = await repo.getHydratedInvoiceData(companyId, null);
      final d = result.data;
      _activeTemplateId = result.templateId;
      if (!mounted) return;
      setState(() {
        _showTaxBreakdown = d.showTaxBreakdown;
        _showFooter = d.showNotes;
        _showBankDetails = d.showBankDetails;
        _showUpiQr = d.showUpiQr;
        _taxLabelController.text = d.taxLabel;
        _taxRateController.text = d.taxRate > 0 ? d.taxRate.toString() : '';
        _termsController.text = d.termsAndConditions;
        _signatoryController.text = d.authorizedSignatory;
        _bankNameController.text = d.bankName;
        _bankAccountNoController.text = d.bankAccountNo;
        _bankIfscController.text = d.bankIfsc;
        _upiIdController.text = d.upiId;
      });
    } catch (_) {}
  }

  Future<void> _saveInvoiceSettings() async {
    setState(() => _isSavingInvoiceSettings = true);
    try {
      final companyId = ref.read(companyIdProvider);
      final repo = ref.read(invoiceTemplateRepositoryProvider);
      await repo.saveTemplateSelection(
        companyId: companyId,
        templateId: _activeTemplateId,
        taxLabel: _taxLabelController.text.trim(),
        taxRate: double.tryParse(_taxRateController.text) ?? 0.0,
        showTaxBreakdown: _showTaxBreakdown,
        termsAndConditions: _termsController.text.trim(),
        authorizedSignatory: _signatoryController.text.trim(),
        showFooter: _showFooter,
        bankName: _bankNameController.text.trim(),
        bankAccountNo: _bankAccountNoController.text.trim(),
        bankIfsc: _bankIfscController.text.trim(),
        upiId: _upiIdController.text.trim(),
        showBankDetails: _showBankDetails,
        showUpiQr: _showUpiQr,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invoice settings saved'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSavingInvoiceSettings = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxLabelController.dispose();
    _taxRateController.dispose();
    _termsController.dispose();
    _signatoryController.dispose();
    _bankNameController.dispose();
    _bankAccountNoController.dispose();
    _bankIfscController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadProfileData(Map<String, dynamic>? profile) {
    if (profile == null || !mounted) return;

    // Update text controllers with profile data
    _businessNameController.text =
        profile['businessName'] ?? profile['companyName'] ?? '';
    _businessAddressController.text = profile['businessAddress'] ?? '';
    _taxIdController.text = profile['taxId'] ?? '';
    _phoneController.text = profile['companyPhone'] ?? '';
    _emailController.text = profile['companyEmail'] ?? '';

    // Update profile image URL (Logo) - Use logoUrl prioritized for company profile
    _profileImageUrl = profile['logoUrl'] ?? profile['profileImage'] ?? profile['imageUrl'];
    // Force rebuild only if not already rebuilding (safety check, though ref.listen runs post-build usually)
    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Prepare profile data
      final profileData = {
        'businessName': _businessNameController.text,
        'businessAddress': _businessAddressController.text,
        'taxId': _taxIdController.text,
        'companyPhone': _phoneController.text,
        'companyEmail': _emailController.text,
      };

      final success = await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(
            profileData,
            imageFile: _selectedImage,
            imageBytes: _imageBytes,
            uploadType: 'logo',
          );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear selected image after successful save
          setState(() {
            _selectedImage = null;
            _imageBytes = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.read(profileControllerProvider).errorMessage ??
                    'Failed to update profile',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for profile changes to update local state
    ref.listen<ProfileState>(profileControllerProvider, (previous, next) {
      if (next.profile != null && next.profile != previous?.profile) {
        _loadProfileData(next.profile);
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isEditable = authState.user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Company Profile",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Company Details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            Icons.business,
                            "Company Information",
                          ),
                          const SizedBox(height: 20),

                          // Logo Upload Section
                          if (isEditable)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _imageBytes != null
                                      ? Image.memory(
                                          _imageBytes!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : _profileImageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: _profileImageUrl!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => const SizedBox(width: 100, height: 100),
                                          errorWidget: (_, _, _) => Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey.shade300,
                                            child: const Icon(
                                              Icons.business,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.business,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _pickImage,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade400,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: const Text("Upload Logo"),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Upload logo below 2 MB, JPG/PNG",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            // Read-only logo view
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _profileImageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: _profileImageUrl!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => const SizedBox(width: 100, height: 100),
                                          errorWidget: (_, _, _) => Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey.shade300,
                                            child: const Icon(
                                              Icons.business,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.business,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 32),

                          // Responsive Form Layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              bool useSingleColumn = constraints.maxWidth < 600;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Company Name and Tax ID
                                  useSingleColumn
                                      ? Column(
                                          children: [
                                            _buildField(
                                              "Company Name *",
                                              _businessNameController,
                                              readOnly: !isEditable,
                                            ),
                                            const SizedBox(height: 20),
                                            _buildField(
                                              "Tax ID / GSTIN",
                                              _taxIdController,
                                              readOnly: !isEditable,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: _buildField(
                                                "Company Name *",
                                                _businessNameController,
                                                readOnly: !isEditable,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: _buildField(
                                                "Tax ID / GSTIN",
                                                _taxIdController,
                                                readOnly: !isEditable,
                                              ),
                                            ),
                                          ],
                                        ),
                                  const SizedBox(height: 20),

                                  // Business Address (Always full width)
                                  _buildField(
                                    "Business Address",
                                    _businessAddressController,
                                    readOnly: !isEditable,
                                  ),
                                  const SizedBox(height: 20),

                                  // Phone and Email
                                  useSingleColumn
                                      ? Column(
                                          children: [
                                            _buildField(
                                              "Phone Number",
                                              _phoneController,
                                              readOnly: !isEditable,
                                            ),
                                            const SizedBox(height: 20),
                                            _buildField(
                                              "Email (Read Only)",
                                              _emailController,
                                              readOnly: true,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: _buildField(
                                                "Phone Number",
                                                _phoneController,
                                                readOnly: !isEditable,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: _buildField(
                                                "Email (Read Only)",
                                                _emailController,
                                                readOnly: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 32),
                          // Action Buttons
                          if (isEditable)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Reload to cancel
                                    ref
                                        .read(
                                          profileControllerProvider.notifier,
                                        )
                                        .loadProfile();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text("Cancel"),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade400,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text("Save Changes"),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tax settings ───────────────────────────────────────────────
            const SizedBox(height: 24),
            _buildInvoiceSection(
              icon: Icons.percent,
              title: 'Tax Settings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Tax Breakdown on Invoice',
                          style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _showTaxBreakdown,
                        onChanged: (v) => setState(() => _showTaxBreakdown = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField('Tax Label (e.g. GST, VAT)', _taxLabelController),
                  const SizedBox(height: 8),
                  Text(
                    'Tax rates are set per product (GST %). Edit a product to set its rate.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  _buildSaveButton('Save Tax Settings', _saveInvoiceSettings),
                ],
              ),
            ),

            // ── Footer / Terms ──────────────────────────────────────────────
            const SizedBox(height: 16),
            _buildInvoiceSection(
              icon: Icons.description_outlined,
              title: 'Footer & Terms',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Footer on Invoice',
                          style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _showFooter,
                        onChanged: (v) => setState(() => _showFooter = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                      'Terms & Conditions / Thank-you message', _termsController,
                      maxLines: 3),
                  const SizedBox(height: 12),
                  _buildField('Authorized Signatory', _signatoryController),
                  const SizedBox(height: 16),
                  _buildSaveButton('Save Footer Settings', _saveInvoiceSettings),
                ],
              ),
            ),

            // ── Payment / Bank details ──────────────────────────────────────
            const SizedBox(height: 16),
            _buildInvoiceSection(
              icon: Icons.account_balance_outlined,
              title: 'Payment Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Bank Details', style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _showBankDetails,
                        onChanged: (v) => setState(() => _showBankDetails = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField('Bank Name', _bankNameController),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _buildField(
                              'Account Number', _bankAccountNoController,
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField('IFSC Code', _bankIfscController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show UPI QR Code', style: TextStyle(fontSize: 13)),
                      Switch(
                        value: _showUpiQr,
                        onChanged: (v) => setState(() => _showUpiQr = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField('UPI ID', _upiIdController),
                  const SizedBox(height: 16),
                  _buildSaveButton('Save Payment Settings', _saveInvoiceSettings),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(String label, VoidCallback? onPressed) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: _isSavingInvoiceSettings ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _isSavingInvoiceSettings
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange.shade400),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.shade100 : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            suffixIcon: isPassword
                ? const Icon(Icons.visibility_off_outlined, size: 20)
                : null,
          ),
        ),
      ],
    );
  }
}
