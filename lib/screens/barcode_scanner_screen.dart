import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/products/data/products_notifier.dart';
import '../features/stock/data/stock_notifier.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

import '../widgets/gooey_hover_button.dart';
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  late final MobileScannerController _scannerController;

  bool _isTorchOn = false;
  bool _hasPermission = false;
  bool _isProcessing = false;
  Product? _detectedProduct;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    if (kIsWeb) {
      if (mounted) setState(() => _hasPermission = true);
      return;
    }
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String code) async {
    if (_isProcessing || code.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final product = await ref.read(productsProvider.notifier).getByBarcode(code);

      if (product != null) {
        if (mounted) {
          setState(() => _detectedProduct = product);
        }
        return;
      }

      // Fallback: search by SKU
      final productsAsync = ref.read(productsProvider);
      final products = productsAsync.valueOrNull ?? [];
      final productBySku = products.where((p) => p.sku == code).firstOrNull;

      if (productBySku != null) {
        if (mounted) {
          setState(() => _detectedProduct = productBySku);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unrecognized barcode: $code. Try manual SKU search.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  void _showManualEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manual SKU or Barcode Lookup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualInputController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type SKU e.g. BRK-SH-005 or barcode',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (val) {
                  Navigator.pop(context);
                  _onBarcodeDetected(val.trim());
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GooeyHoverButton(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _onBarcodeDetected(_manualInputController.text.trim());
                  },
                  child: const Text('Search & Locate Part'),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white70,
            ),
            tooltip: 'Flashlight',
            onPressed: _hasPermission ? _toggleTorch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard, color: Colors.white70),
            tooltip: 'Manual Entry',
            onPressed: _showManualEntrySheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera / permission fallback ──────────────────────────────
          if (!_hasPermission)
            _buildPermissionDeniedView()
          else
            _buildCameraView(),

          // ── Viewfinder overlay ────────────────────────────────────────
          if (_hasPermission) _buildViewfinderOverlay(),

          // ── Detected product card ─────────────────────────────────────
          if (_detectedProduct != null) _buildDetectedCard(),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 20),
            const Text(
              'Camera permission required',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'GearStock needs camera access to scan barcodes on bicycle parts.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GooeyHoverButton(child: ElevatedButton.icon(
              onPressed: () async {
                final opened = await openAppSettings();
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open settings. Please grant camera permission manually.')),
                  );
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            )),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _requestCameraPermission,
              child: const Text('Try Again', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: (capture) {
        final barcodes = capture.barcodes;
        if (barcodes.isNotEmpty) {
          final code = barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            _onBarcodeDetected(code);
          }
        }
      },
    );
  }

  Widget _buildViewfinderOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Stack(
              children: [
                // Corner brackets
                ..._buildCorners(context),

                // Animated laser line
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    return Positioned(
                      top: 20 + (_laserController.value * 230),
                      left: 15,
                      right: 15,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withAlpha(200),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Centre reticle
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12, width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white30),
                  ),
                ),

                // Processing indicator
                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Align bicycle part barcode inside square',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedCard() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _detectedProduct!.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SKU: ${_detectedProduct!.sku} • Stock: ${_detectedProduct!.currentStock} left',
                        style:  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _detectedProduct = null),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GooeyHoverButton(child: OutlinedButton(
                    onPressed: () {
                      final p = _detectedProduct!;
                      setState(() => _detectedProduct = null);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(productId: p.id),
                        ),
                      );
                    },
                    child: const Text('View Part'),
                  )),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GooeyHoverButton(child: ElevatedButton(
                    onPressed: () async {
                      final p = _detectedProduct!;
                      final messenger = ScaffoldMessenger.of(context);
                      final primaryColor = Theme.of(
                        context,
                      ).colorScheme.primary;
                      await ref.read(stockProvider.notifier).addStockIn(
                        productId: p.id,
                        quantity: 1,
                        unitPrice: p.costPrice,
                        note: 'Quick barcode stock in',
                      );
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('+1 logged for ${p.name}'),
                            backgroundColor: primaryColor,
                          ),
                        );
                        setState(() => _detectedProduct = null);
                      }
                    },
                    child: const Text('Quick +1 Stock'),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners(BuildContext context) {
    const double size = 24.0;
    const double width = 3.0;
    final color = Theme.of(context).colorScheme.primary;

    return [
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
          ),
        ),
      ),
    ];
  }
}
