import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../features/categories/data/categories_notifier.dart';
import '../features/products/data/products_notifier.dart';
import '../features/suppliers/data/suppliers_notifier.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';

import '../widgets/gooey_hover_button.dart';
class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;

  const AddEditProductScreen({
    super.key,
    this.productToEdit,
  });

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _brandController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _categoryController;
  late TextEditingController _descController;
  late TextEditingController _shelfLocationController;

  String? _imagePath;
  String _selectedSupplier = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _costPriceController = TextEditingController(
      text: p != null ? p.costPrice.toStringAsFixed(0) : '',
    );
    _sellingPriceController = TextEditingController(
      text: p != null ? p.sellingPrice.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.currentStock.toString() : '5',
    );
    _minStockController = TextEditingController(
      text: p != null ? p.minStock.toString() : '3',
    );
    _categoryController = TextEditingController(
      text: p?.category ?? 'Brakes',
    );
    _descController = TextEditingController(text: p?.description ?? '');
    _shelfLocationController = TextEditingController(text: p?.shelfLocation ?? '');

    _imagePath = p?.imageUrl;
    _selectedSupplier = p?.supplierName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _categoryController.dispose();
    _descController.dispose();
    _shelfLocationController.dispose();
    super.dispose();
  }

  double get _currentMargin {
    final cost = double.tryParse(_costPriceController.text) ?? 0;
    final sell = double.tryParse(_sellingPriceController.text) ?? 0;
    if (sell <= 0) return 0;
    return ((sell - cost) / sell) * 100;
  }

  void _generateBarcode() {
    final randomDigits = DateTime.now().millisecondsSinceEpoch.toString();
    final generated = '890${randomDigits.substring(randomDigits.length - 9)}';
    setState(() {
      _barcodeController.text = generated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-generated barcode: $generated'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "$category"? Products using it will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await ref.read(categoriesProvider.notifier).deleteCategory(category);
      if (!mounted) return;
      if (_categoryController.text.trim() == category) {
        _categoryController.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$category" category deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete "$category": $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        var savedPath = picked.path;
        if (!kIsWeb) {
          final documentsDirectory = await getApplicationDocumentsDirectory();
          final imageDirectory = Directory('${documentsDirectory.path}/product-images');
          await imageDirectory.create(recursive: true);
          final extension = RegExp(r'\.[a-zA-Z0-9]+$').firstMatch(picked.name)?.group(0) ?? '.jpg';
          final savedFile = await File(picked.path).copy(
            '${imageDirectory.path}/${const Uuid().v4()}$extension',
          );
          savedPath = savedFile.path;
        }
        if (!mounted) return;
        setState(() {
          _imagePath = savedPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera/gallery: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:  Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:  Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null && _imagePath!.isNotEmpty)
              ListTile(
                leading:  Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title:  Text('Remove Photo', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera permission required to scan barcodes'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                title: const Text(
                  'Scan Part Barcode',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      final fallback = '890${DateTime.now().millisecondsSinceEpoch % 1000000000}';
                      Navigator.pop(context, fallback);
                    },
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                    label: const Text('Auto-Number', style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final raw = barcodes.first.rawValue;
                      if (raw != null && raw.trim().isNotEmpty) {
                        Navigator.pop(context, raw.trim());
                      }
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Point camera at the barcode on the bicycle part or packaging',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode captured: $scannedCode'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final cost = double.tryParse(_costPriceController.text) ?? 0;
    final sell = double.tryParse(_sellingPriceController.text) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final minStock = int.tryParse(_minStockController.text) ?? 0;

    var barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      barcode = '890${DateTime.now().millisecondsSinceEpoch % 1000000000}';
    }

    final category = _categoryController.text.trim().isNotEmpty
        ? _categoryController.text.trim()
        : 'Accessories';

    // Persist new category if entered
    await ref.read(categoriesProvider.notifier).addCategory(category);

    final sku = barcode; // Simplify: SKU defaults directly to barcode

    try {
      if (widget.productToEdit != null) {
        final updated = widget.productToEdit!.copyWith(
          name: _nameController.text.trim(),
          sku: widget.productToEdit!.sku.isNotEmpty ? widget.productToEdit!.sku : sku,
          barcode: barcode,
          category: category,
          brand: _brandController.text.trim(),
          costPrice: cost,
          sellingPrice: sell,
          currentStock: stock,
          minStock: minStock,
          shelfLocation: _shelfLocationController.text.trim(),
          supplierName: _selectedSupplier,
          description: _descController.text.trim(),
          imageUrl: _imagePath,
        );

        await ref.read(productsProvider.notifier).updateProduct(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text('Part updated successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        await ref.read(productsProvider.notifier).addProduct(
          name: _nameController.text.trim(),
          sku: sku,
          barcode: barcode,
          category: category,
          brand: _brandController.text.trim().isEmpty ? 'General' : _brandController.text.trim(),
          costPrice: cost,
          sellingPrice: sell,
          currentStock: stock,
          minStock: minStock,
          shelfLocation: _shelfLocationController.text.trim(),
          supplierName: _selectedSupplier,
          description: _descController.text.trim(),
          imageUrl: _imagePath,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text('New part saved to catalog!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving part: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPhotoPreview() {
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: ProductImage(
                source: _imagePath,
                width: double.infinity,
                height: 180,
                borderRadius: 12,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                tooltip: 'Change Photo',
                onPressed: _showPhotoOptions,
              ),
            ),
          ),
        ],
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return InkWell(
      onTap: _showPhotoOptions,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryFixed.withAlpha(140),
                shape: BoxShape.circle,
              ),
              child:  Icon(Icons.photo_camera, color: Theme.of(context).colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 10),
             Text(
              'Add Part Photo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
             Text(
              'Take a photo with camera or choose from gallery',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productToEdit != null;
    final suppliersAsync = ref.watch(suppliersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Part' : 'Add New Part',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHigh)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: GooeyHoverButton(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GooeyHoverButton(child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(isEdit ? 'Update Part' : 'Save & Add to Catalog'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _saveProduct,
                )),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo section
               Text(
                'Product Photo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _buildPhotoPreview(),
              const SizedBox(height: 16),

              // Product Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    const Text('Part Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter part name' : null,
                      decoration:  InputDecoration(
                        hintText: 'e.g. Shimano Brake Pads / KMC Chain',
                        prefixIcon: Icon(Icons.pedal_bike, size: 20, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Barcode with Scan & Auto-generate
                    const Text('Barcode *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration:  InputDecoration(
                              hintText: 'Scan or auto-generate barcode',
                              prefixIcon: Icon(Icons.qr_code_2, size: 20, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _scanBarcode,
                          tooltip: 'Scan Barcode',
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          onPressed: _generateBarcode,
                          tooltip: 'Generate Barcode Number',
                          icon: const Icon(Icons.auto_awesome, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Category with extensible autocomplete
                    const Text('Category * (select, type, or long-press to delete)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    categoriesAsync.when(
                      loading: () => TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(hintText: 'e.g. Brakes, Chains'),
                      ),
                      error: (err, stack) => TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(hintText: 'e.g. Brakes, Chains'),
                      ),
                      data: (catList) {
                        TextEditingController? categoryFieldController;
                        return Autocomplete<String>(
                          initialValue: TextEditingValue(text: _categoryController.text),
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return catList;
                            }
                            return catList.where((cat) => cat
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) {
                            setState(() {
                              _categoryController.text = selection;
                            });
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final categories = options.toList();
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: categories.length,
                                    itemBuilder: (context, index) {
                                      final category = categories[index];
                                      return ListTile(
                                        title: Text(category),
                                        onTap: () => onSelected(category),
                                        onLongPress: () async {
                                          await _confirmDeleteCategory(category);
                                          if (categoryFieldController?.text
                                                  .trim() ==
                                              category) {
                                            categoryFieldController?.clear();
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                            categoryFieldController = textController;
                            // Sync autocomplete controller with our _categoryController
                            textController.addListener(() {
                              _categoryController.text = textController.text;
                            });
                            return TextFormField(
                              controller: textController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Type category or select from list',
                                prefixIcon:  Icon(Icons.category, size: 20, color: Theme.of(context).colorScheme.secondary),
                                suffixIcon: PopupMenuButton<String>(
                                  icon:  Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.secondary),
                                  onSelected: (val) {
                                    textController.text = val;
                                    _categoryController.text = val;
                                  },
                                  itemBuilder: (context) => catList
                                      .map((c) => PopupMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Brand
                    const Text('Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _brandController,
                      decoration:  InputDecoration(
                        hintText: 'e.g. Shimano, Hero, KMC, Firefox',
                        prefixIcon: Icon(Icons.verified, size: 20, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pricing & Stock Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      'PRICING & STOCK LEVELS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cost Price (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _costPriceController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.currency_rupee, size: 16)),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selling Price (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _sellingPriceController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.currency_rupee, size: 16)),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                         Text('Profit Margin: ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                        Text(
                          '${_currentMargin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _currentMargin > 15 ? AppStatusColors.of(context).success : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Min Alert Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minStockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.warning_amber_rounded, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Supplier, shelf location, and notes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shelf / Bin Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _shelfLocationController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Aisle 2, Bin B4',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Supplier / Vendor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    suppliersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading suppliers: $e'),
                      data: (suppliers) {
                        if (suppliers.isEmpty) {
                          return  Text(
                            'No suppliers registered yet. (Optional)',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                          );
                        }

                        // Ensure current selected supplier exists, or set to first or empty
                        final supplierNames = suppliers.map((s) => s.name).toList();
                        if (!supplierNames.contains(_selectedSupplier)) {
                          _selectedSupplier = supplierNames.first;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedSupplier,
                          items: supplierNames
                              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSupplier = val);
                          },
                          decoration:  InputDecoration(
                            prefixIcon: Icon(Icons.storefront, size: 20, color: Theme.of(context).colorScheme.secondary),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Item Notes / Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Optional notes (e.g. size, compatibility, fitment)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
