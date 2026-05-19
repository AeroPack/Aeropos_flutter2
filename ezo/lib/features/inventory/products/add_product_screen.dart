import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/widgets/pos_data_form.dart';
import 'package:aeropos/core/widgets/pos_toast.dart';
import 'package:aeropos/core/widgets/category_form_dialog.dart';
import 'package:aeropos/core/widgets/brand_form_dialog.dart';
import 'package:aeropos/core/widgets/unit_form_dialog.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/viewModel/product_view_model.dart';
import 'package:aeropos/core/models/category.dart';
import 'package:aeropos/core/models/unit.dart';
import 'package:aeropos/core/models/brand.dart';
import 'package:drift/drift.dart' as drift;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';

class _ProductUnitEntry {
  int? id;
  int? unitId;
  double conversionFactor;
  double? sellingPrice;
  String? barcode;
  bool isDefault;
  String? unitName;
  String? unitSymbol;

  _ProductUnitEntry({
    this.id,
    this.unitId,
    this.conversionFactor = 1.0,
    this.sellingPrice,
    this.barcode,
    this.isDefault = false,
    this.unitName,
    this.unitSymbol,
  });
}

class AddItemScreen extends StatefulWidget {
  final ProductEntity? product;

  const AddItemScreen({super.key, this.product});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  // Removed _stockController - quantity field removed from form
  final _descController = TextEditingController();
  final _hsnController = TextEditingController();
  final _discountController = TextEditingController(text: '0.0');
  bool _isPercentDiscount = false;

  int? _selectedCategoryId;
  int? _selectedUnitId;
  int? _selectedBrandId;
  String? _selectedGstType;
  String? _selectedGstRate;
  bool _isLoading = false;
  static const List<String> _gstRates = ['0%', '5%', '12%', '18%', '28%'];
  static const List<String> _gstTypes = ['Inclusive', 'Exclusive'];
  static const int _maxImageBytes = 1 * 1024 * 1024;

  List<_ProductUnitEntry> _productUnits = [];
  bool _unitsExpanded = false;

  final _imagePicker = ImagePicker();
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes; // for web preview
  String? _currentLocalPath;
  String? _imageUrl;

  late final ProductViewModel _viewModel =
      ServiceLocator.instance.productViewModel;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.name;
      _skuController.text = p.sku ?? '';
      _priceController.text = p.price.toString();
      _costController.text = p.cost?.toString() ?? '';
      _descController.text = '';
      _selectedBrandId = p.brandId;
      _selectedCategoryId = p.categoryId;
      _selectedUnitId = p.unitId;
      _selectedGstType = p.gstType;
      _selectedGstRate = p.gstRate;
      _hsnController.text = p.hsn ?? '';
      _currentLocalPath = p.localPath;
      _imageUrl = p.imageUrl;
      _discountController.text = p.discount.toString();
      _isPercentDiscount = p.isPercentDiscount;

      _loadProductUnits(p.id);
    }
  }

  Future<void> _loadProductUnits(int productId) async {
    final units = await _viewModel.getProductUnits(productId);
    final allUnits = await _viewModel.database
        .select(_viewModel.database.units)
        .get();
    final unitMap = {for (var u in allUnits) u.id: u};

    setState(() {
      _productUnits = units.map((pu) {
        final u = unitMap[pu.unitId];
        return _ProductUnitEntry(
          id: pu.id,
          unitId: pu.unitId,
          conversionFactor: pu.conversionFactor,
          sellingPrice: pu.sellingPrice,
          barcode: pu.barcode,
          isDefault: pu.isDefault,
          unitName: u?.name,
          unitSymbol: u?.symbol,
        );
      }).toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    // Removed stockController disposal
    _descController.dispose();
    _hsnController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      PosToast.showError(context, "Name and Price are required");
      return;
    }

    if (_selectedCategoryId == null) {
      PosToast.showError(context, "Category is required");
      return;
    }

    if (_selectedUnitId == null) {
      PosToast.showError(context, "Unit is required");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check Name uniqueness (case-insensitive, trimmed)
      final normalizedName = _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final isNameUnique = await _viewModel.isNameUnique(
        normalizedName,
        excludeId: widget.product?.id,
      );
      if (!isNameUnique) {
        if (!mounted) return;
        PosToast.showError(
          context,
          "Product name already exists. Please use a unique name.",
        );
        return;
      }

      // Check HSN format and uniqueness
      final hsn = _hsnController.text.trim();
      if (hsn.isNotEmpty) {
        if (!RegExp(r'^\d{4,10}$').hasMatch(hsn)) {
          if (!mounted) return;
          PosToast.showError(
            context,
            "HSN must be 4-10 numeric digits",
          );
          return;
        }
        final isHsnUnique = await _viewModel.isHsnUnique(
          hsn,
          excludeId: widget.product?.id,
        );
        if (!isHsnUnique) {
          if (!mounted) return;
          PosToast.showError(context, "HSN code already in use");
          return;
        }
      }
      String? localPathToSave = _currentLocalPath;
      String? imageUrlToSave =
          _imageUrl; // preserve existing imageUrl by default

      if (kIsWeb) {
        // On web: File/path_provider are not available.
        // Convert the picked image bytes to a Base64 data URI and store in imageUrl.
        if (_selectedImageBytes != null) {
          final base64Str = base64Encode(_selectedImageBytes!);
          imageUrlToSave = 'data:image/jpeg;base64,$base64Str';
          localPathToSave = null; // Not applicable on web
        }
        // If URL was entered directly, imageUrlToSave already holds the URL
      } else {
        // On native: download URL to file if needed, then copy/compress
        if (_imageUrl != null && _selectedImageFile == null) {
          try {
            final response = await ServiceLocator.instance.dio.get<List<int>>(
              _imageUrl!,
              options: Options(responseType: ResponseType.bytes),
            );
            if (response.statusCode == 200 && response.data != null) {
              if (response.data!.length > _maxImageBytes) {
                throw Exception('Image exceeds 1 MB limit. Please use a smaller image.');
              }
              final tempDir = await getApplicationDocumentsDirectory();
              final fileName =
                  'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final tempPath = path.join(tempDir.path, fileName);
              final tempFile = File(tempPath);
              await tempFile.writeAsBytes(response.data!);
              _selectedImageFile = XFile(tempPath);
            } else {
              throw Exception(
                'Failed to download image: ${response.statusCode}',
              );
            }
          } catch (e) {
            if (mounted) {
              PosToast.showError(
                context,
                "Failed to download image from URL: $e",
              );
              setState(() => _isLoading = false);
              return;
            }
          }
        }

        if (_selectedImageFile != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName =
              'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = path.join(appDir.path, fileName);

          if (Platform.isAndroid || Platform.isIOS) {
            try {
              final result = await FlutterImageCompress.compressAndGetFile(
                _selectedImageFile!.path,
                targetPath,
                quality: 80,
                format: CompressFormat.jpeg,
              );
              if (result != null) {
                localPathToSave = result.path;
              } else {
                final savedImage = await File(
                  _selectedImageFile!.path,
                ).copy(targetPath);
                localPathToSave = savedImage.path;
              }
            } catch (e) {
              final savedImage = await File(
                _selectedImageFile!.path,
              ).copy(targetPath);
              localPathToSave = savedImage.path;
            }
          } else {
            final savedImage = await File(
              _selectedImageFile!.path,
            ).copy(targetPath);
            localPathToSave = savedImage.path;
          }
        }
      }

      if (localPathToSave != null && !kIsWeb) {
        final fileSize = await File(localPathToSave).length();
        if (fileSize > _maxImageBytes) {
          if (mounted) {
            PosToast.showError(
              context,
              'Image must not exceed 1 MB. Please choose a smaller image.',
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      double price = double.tryParse(_priceController.text) ?? 0.0;
      double discount = double.tryParse(_discountController.text) ?? 0.0;

      if (_isPercentDiscount) {
        if (discount > 100) discount = 100;
      } else {
        if (discount > price) discount = price;
      }
      if (discount < 0) discount = 0;

      int? productId;

      if (widget.product == null) {
        await _viewModel.addProduct(
          name: _nameController.text,
          sku: _skuController.text.isNotEmpty ? _skuController.text : null,
          price: price,
          cost: double.tryParse(_costController.text) ?? 0.0,
          stockQuantity: 0.0,
          categoryId: _selectedCategoryId,
          unitId: _selectedUnitId,
          brandId: _selectedBrandId,
          gstType: _selectedGstType,
          gstRate: _selectedGstRate,
          hsn: hsn.isNotEmpty ? hsn : null,
          description: _descController.text,
          localPath: localPathToSave,
          imageUrl: imageUrlToSave,
          discount: discount,
          isPercentDiscount: _isPercentDiscount,
        );

        final newProduct = await (_viewModel.database.select(
          _viewModel.database.products,
        )..where((t) => t.name.equals(_nameController.text.trim()))).getSingleOrNull();
        productId = newProduct?.id;
      } else {
        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text,
          sku: drift.Value(_skuController.text.isNotEmpty ? _skuController.text : null),
          price: double.tryParse(_priceController.text) ?? 0.0,
          cost: drift.Value(double.tryParse(_costController.text)),
          categoryId: drift.Value(_selectedCategoryId),
          unitId: drift.Value(_selectedUnitId),
          brandId: drift.Value(_selectedBrandId),
          syncStatus: 1,
          gstType: drift.Value(_selectedGstType),
          gstRate: drift.Value(_selectedGstRate),
          hsn: drift.Value(hsn.isNotEmpty ? hsn : null),
          description: drift.Value(_descController.text),
          localPath: drift.Value(localPathToSave),
          imageUrl: drift.Value(imageUrlToSave),
          discount: discount,
          isPercentDiscount: _isPercentDiscount,
          updatedAt: DateTime.now(),
        );
        await _viewModel.updateProduct(updatedProduct);
        productId = widget.product!.id;
      }

      if (productId != null) {
        await _viewModel.deleteProductUnits(productId);

        int? defaultUnitId;
        for (final unit in _productUnits) {
          if (unit.unitId != null) {
            await _viewModel.saveProductUnit(
              ProductUnitsCompanion.insert(
                productId: productId,
                unitId: unit.unitId!,
                conversionFactor: unit.conversionFactor,
                sellingPrice: drift.Value(unit.sellingPrice),
                barcode: drift.Value(unit.barcode),
                isDefault: drift.Value(unit.isDefault),
                tenantId: 1,
              ),
            );
            if (unit.isDefault) {
              defaultUnitId = unit.unitId;
            }
          }
        }

        final pid = productId;
        if (defaultUnitId != null) {
          await (_viewModel.database.update(
            _viewModel.database.products,
          )..where((t) => t.id.equals(pid))).write(
            ProductsCompanion(
              baseUnitId: drift.Value(defaultUnitId),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
        }
      }

      if (mounted) {
        PosToast.showSuccess(
          context,
          widget.product == null
              ? 'Product Added Successfully'
              : 'Product Updated Successfully',
        );
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          if (widget.product == null) {
            _clearForm();
          } else {
            if (context.canPop()) {
              context.pop();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        PosToast.showError(context, "Error: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _skuController.clear();
    _priceController.clear();
    _costController.clear();
    _descController.clear();
    _hsnController.clear();
    _discountController.text = '0.0';
    setState(() {
      _selectedCategoryId = null;
      _selectedUnitId = null;
      _selectedBrandId = null;
      _selectedGstType = null;
      _selectedGstRate = null;
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _imageUrl = null;
      _currentLocalPath = null;
      _isPercentDiscount = false;
      _productUnits = [];
      _unitsExpanded = false;
    });
  }

  /// Builds an image widget from a URL string.
  /// Handles both Base64 data URIs (saved on web) and regular http/https URLs.
  Widget _buildImageFromUrl(String url) {
    if (url.startsWith('data:')) {
      // Base64 data URI — decode and display with Image.memory
      try {
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = url.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      } catch (_) {}
      return const Icon(Icons.broken_image, color: Colors.red);
    }
    // Regular HTTP/HTTPS URL
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          const Center(child: Icon(Icons.error_outline, color: Colors.red)),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Image Source',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: PosColors.blue,
                size: 28,
              ),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: PosColors.blue,
                size: 28,
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from device'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: PosColors.blue, size: 28),
              title: const Text('From URL'),
              subtitle: const Text('Enter image URL'),
              onTap: () {
                Navigator.pop(context);
                _pickFromUrl();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = bytes;
          _imageUrl = null;
        });
      } else {
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = null;
          _imageUrl = null;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = bytes;
          _imageUrl = null;
        });
      } else {
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = null;
          _imageUrl = null;
        });
      }
    }
  }

  Future<void> _pickFromUrl() async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a valid image URL',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                if (!url.startsWith('https://') && !url.startsWith('http://')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL must start with http:// or https://'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, url);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _imageUrl = result;
        _selectedImageFile = null;
      });
    }
  }

  void _showAddCategoryDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => CategoryFormDialog(
        onSubmit: (name, description) async {
          final db = ServiceLocator.instance.database;
          final uuid = DateTime.now().millisecondsSinceEpoch.toString();
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  uuid: uuid,
                  name: name,
                  tenantId: 1,
                  description: drift.Value(
                    description.isNotEmpty ? description : null,
                  ),
                ),
              );
          if (context.mounted) {
            PosToast.showSuccess(context, "Category added successfully");
          }
        },
      ),
    );
  }

  void _showAddBrandDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BrandFormDialog(
        onSubmit: (name, description) async {
          final db = ServiceLocator.instance.database;
          final uuid = DateTime.now().millisecondsSinceEpoch.toString();
          await db
              .into(db.brands)
              .insert(
                BrandsCompanion.insert(
                  uuid: uuid,
                  name: name,
                  tenantId: 1,
                  description: drift.Value(
                    description.isNotEmpty ? description : null,
                  ),
                ),
              );
          if (context.mounted) {
            PosToast.showSuccess(context, "Brand added successfully");
          }
        },
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => UnitFormDialog(
        onSubmit: (name, symbol) async {
          final db = ServiceLocator.instance.database;
          final uuid = DateTime.now().millisecondsSinceEpoch.toString();
          await db
              .into(db.units)
              .insert(
                UnitsCompanion.insert(
                  uuid: uuid,
                  name: name,
                  symbol: symbol,
                  tenantId: 1,
                ),
              );
          if (context.mounted) {
            PosToast.showSuccess(context, "Unit added successfully");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: _viewModel.allCategories,
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? [];

        return StreamBuilder<List<Unit>>(
          stream: _viewModel.allUnits,
          builder: (context, unitSnapshot) {
            final units = unitSnapshot.data ?? [];

            return StreamBuilder<List<Brand>>(
              stream: _viewModel.allBrands,
              builder: (context, brandSnapshot) {
                final brands = brandSnapshot.data ?? [];

                return PosDataForm(
                  title: widget.product == null
                      ? "Add New Product"
                      : "Edit Product",
                  subTitle: widget.product == null
                      ? "Create new item in inventory"
                      : "Update existing product details",
                  formTitle: "Product Information",
                  submitLabel: widget.product == null
                      ? "Create Product"
                      : "Update Product",
                  isLoading: _isLoading,
                  onBack: () => context.pop(),
                  onSubmit: _handleSubmit,

                  fields: [
                    PosTextInput(
                      label: "Product Name",
                      isRequired: true,
                      controller: _nameController,
                      placeholder: "e.g. Wireless Mouse",
                    ),
                    PosTextInput(
                      label: "SKU / Barcode",
                      isRequired: false,
                      controller: _skuController,
                      placeholder: "Enter SKU manually",
                      readOnly: false,
                      suffix: null,
                    ),

                    // CATEGORY DROPDOWN (Real Data)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PosDropdown<int>(
                            label: "Category",
                            isRequired: true,
                            value: _selectedCategoryId,
                            hint: "Select Category",
                            items: (categories)
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCategoryId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextButton.icon(
                            onPressed: () => _showAddCategoryDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add"),
                            style: TextButton.styleFrom(
                              foregroundColor: PosColors.blue,
                              backgroundColor: PosColors.blue.withValues(
                                alpha: 0.1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // BRAND DROPDOWN (Real Data)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PosDropdown<int>(
                            label: "Brand",
                            value: _selectedBrandId,
                            hint: "Select Brand",
                            items: brands
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedBrandId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextButton.icon(
                            onPressed: () => _showAddBrandDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add"),
                            style: TextButton.styleFrom(
                              foregroundColor: PosColors.blue,
                              backgroundColor: PosColors.blue.withValues(
                                alpha: 0.1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    PosTextInput(
                      label: "Sale Rate (\$)",
                      isRequired: true,
                      controller: _priceController,
                      placeholder: "0.00",
                    ),
                    PosTextInput(
                      label: "Purchase Rate (\$)",
                      isRequired: false,
                      controller: _costController,
                      placeholder: "0.00",
                    ),

                    // UNIT DROPDOWN (Real Data)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PosDropdown<int>(
                            label: "Unit",
                            isRequired: true,
                            hint: "Select Unit",
                            items: units
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text(u.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedUnitId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextButton.icon(
                            onPressed: () => _showAddUnitDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Add"),
                            style: TextButton.styleFrom(
                              foregroundColor: PosColors.blue,
                              backgroundColor: PosColors.blue.withValues(
                                alpha: 0.1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    PosDropdown<String>(
                      label: "Gst Type",
                      value: _selectedGstType,
                      items: _gstTypes
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedGstType = val),
                    ),
                    PosDropdown<String>(
                      label: "Gst Rate",
                      value: _selectedGstRate,
                      items: (_gstRates)
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedGstRate = val),
                    ),
                    PosTextInput(
                      label: "HSN Code",
                      isRequired: false,
                      controller: _hsnController,
                      placeholder: "e.g. 12345678",
                    ),
                    PosTextInput(
                      label: "Default Discount",
                      controller: _discountController,
                      placeholder: "0.00",
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _isPercentDiscount = false),
                            style: TextButton.styleFrom(
                              backgroundColor: !_isPercentDiscount
                                  ? PosColors.blue.withValues(alpha: 0.1)
                                  : null,
                              foregroundColor: !_isPercentDiscount
                                  ? PosColors.blue
                                  : Colors.grey,
                            ),
                            child: const Text("Rs"),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _isPercentDiscount = true),
                            style: TextButton.styleFrom(
                              backgroundColor: _isPercentDiscount
                                  ? PosColors.blue.withValues(alpha: 0.1)
                                  : null,
                              foregroundColor: _isPercentDiscount
                                  ? PosColors.blue
                                  : Colors.grey,
                            ),
                            child: const Text("%"),
                          ),
                        ],
                      ),
                    ),
                  ],

                  extraSections: [
                    PosContentCard(
                      title: "Product Image",
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Show existing image as square thumbnail
                          if (_selectedImageFile != null ||
                              _imageUrl != null ||
                              _currentLocalPath != null)
                            Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: PosColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _selectedImageFile != null
                                        ? (_selectedImageBytes != null
                                              ? Image.memory(
                                                  _selectedImageBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(
                                                    _selectedImageFile!.path,
                                                  ),
                                                  fit: BoxFit.cover,
                                                ))
                                        : _imageUrl != null
                                        ? _buildImageFromUrl(_imageUrl!)
                                        : _currentLocalPath != null
                                        ? (kIsWeb
                                      ? CachedNetworkImage(
                                          imageUrl: _currentLocalPath!,
                                          fit: BoxFit.cover,
                                        )
                                              : Image.file(
                                                  File(_currentLocalPath!),
                                                  fit: BoxFit.cover,
                                                ))
                                        : const SizedBox(),
                                  ),
                                ),
                                // Remove button
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImageFile = null;
                                        _selectedImageBytes = null;
                                        _imageUrl = null;
                                        _currentLocalPath = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          // Add image button
                          InkWell(
                            onTap: _showImageSourceOptions,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: PosColors.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 32,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Add Image",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    PosContentCard(
                      title: "Description",
                      child: TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Enter detailed product description...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: PosColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: PosColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),

                    _buildProductUnitsSection(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductUnitsSection() {
    return StreamBuilder<List<UnitEntity>>(
      stream: _viewModel.database.select(_viewModel.database.units).watch(),
      builder: (context, snapshot) {
        final units = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 252, 252, 252),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _unitsExpanded = !_unitsExpanded),
                child: Row(
                  children: [
                    Icon(Icons.scale, color: PosColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Product Units",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _unitsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
              const Divider(height: 32, color: PosColors.border),
              _unitsExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_productUnits.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "No units added. Add units to enable multi-unit pricing.",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        else
                          ...List.generate(_productUnits.length, (index) {
                            final entry = _productUnits[index];
                            return _buildProductUnitRow(entry, index, units);
                          }),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _addProductUnit(units),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Unit"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PosColors.blue,
                            side: const BorderSide(color: PosColors.blue),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductUnitRow(
    _ProductUnitEntry entry,
    int index,
    List<UnitEntity> allUnits,
  ) {
    final usedUnitIds = _productUnits.map((e) => e.unitId).toSet();
    final availableUnits = allUnits
        .where((u) => !usedUnitIds.contains(u.id) || u.id == entry.unitId)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: PosColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: entry.unitId,
                  decoration: InputDecoration(
                    labelText: "Unit",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  items: availableUnits
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text("${u.name} (${u.symbol})"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      entry.unitId = val;
                      final u = allUnits.firstWhere((x) => x.id == val);
                      entry.unitName = u.name;
                      entry.unitSymbol = u.symbol;
                      _suggestRelatedUnits(entry, allUnits);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: entry.conversionFactor.toString(),
                  decoration: InputDecoration(
                    labelText: "Factor",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    entry.conversionFactor = double.tryParse(val) ?? 1.0;
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() => _productUnits.removeAt(index));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: entry.sellingPrice?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: "Selling Price",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    entry.sellingPrice = double.tryParse(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: entry.barcode ?? '',
                  decoration: InputDecoration(
                    labelText: "Barcode",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onChanged: (val) {
                    entry.barcode = val.isEmpty ? null : val;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  const Text("Default"),
                  Checkbox(
                    value: entry.isDefault,
                    onChanged: (val) {
                      setState(() {
                        for (var e in _productUnits) {
                          e.isDefault = false;
                        }
                        entry.isDefault = true;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addProductUnit(List<UnitEntity> allUnits) {
    final usedUnitIds = _productUnits
        .map((e) => e.unitId)
        .whereType<int>()
        .toSet();
    final availableUnits = allUnits
        .where((u) => !usedUnitIds.contains(u.id))
        .toList();

    if (availableUnits.isEmpty) {
      PosToast.showInfo(
        context,
        "No more units available. Add new units first.",
      );
      return;
    }

    setState(() {
      final entry = _ProductUnitEntry(
        unitId: availableUnits.first.id,
        unitName: availableUnits.first.name,
        unitSymbol: availableUnits.first.symbol,
        conversionFactor: 1.0,
        isDefault: _productUnits.isEmpty,
      );
      _productUnits.add(entry);
      _suggestRelatedUnits(entry, allUnits);
    });
  }

  void _suggestRelatedUnits(
    _ProductUnitEntry entry,
    List<UnitEntity> allUnits,
  ) {
    if (entry.unitName == null) return;

    final unitLower = entry.unitName!.toLowerCase();
    List<UnitEntity> relatedUnits = [];

    if (unitLower.contains('gram') || unitLower == 'g') {
      relatedUnits = allUnits
          .where(
            (u) =>
                (u.name.toLowerCase().contains('kilogram') ||
                    u.name.toLowerCase() == 'kg') &&
                !_productUnits.any((e) => e.unitId == u.id),
          )
          .toList();
    } else if (unitLower.contains('kilogram') || unitLower == 'kg') {
      relatedUnits = allUnits
          .where(
            (u) =>
                (u.name.toLowerCase().contains('gram') ||
                    u.name.toLowerCase() == 'g') &&
                !_productUnits.any((e) => e.unitId == u.id),
          )
          .toList();
    } else if (unitLower.contains('piece') ||
        unitLower == 'pc' ||
        unitLower == 'piece') {
      relatedUnits = allUnits
          .where(
            (u) =>
                (u.name.toLowerCase().contains('packet') ||
                    u.name.toLowerCase().contains('pack')) &&
                !_productUnits.any((e) => e.unitId == u.id),
          )
          .toList();
    } else if (unitLower.contains('packet') || unitLower.contains('pack')) {
      relatedUnits = allUnits
          .where(
            (u) =>
                (u.name.toLowerCase().contains('piece') ||
                    u.name.toLowerCase() == 'pc') &&
                !_productUnits.any((e) => e.unitId == u.id),
          )
          .toList();
    }

    if (relatedUnits.isNotEmpty && _productUnits.length == 1) {
      final related = relatedUnits.first;
      final conversionFactor =
          (entry.unitName?.toLowerCase().contains('gram') ?? false)
          ? 1000.0
          : 30.0;
      final basePrice =
          entry.sellingPrice ?? double.tryParse(_priceController.text) ?? 0;

      setState(() {
        _productUnits.add(
          _ProductUnitEntry(
            unitId: related.id,
            unitName: related.name,
            unitSymbol: related.symbol,
            conversionFactor: conversionFactor,
            sellingPrice: basePrice > 0 ? basePrice : null,
            isDefault: false,
          ),
        );
      });
    }
  }
}
