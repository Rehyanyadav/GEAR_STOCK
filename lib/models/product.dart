class Product {
  final String id;
  final String name;
  final String sku;
  final String category;
  final String brand;
  final double costPrice;
  final double sellingPrice;
  int currentStock;
  final int minStock;
  final String shelfLocation;
  final String barcode;
  final String supplierName;
  final String description;
  final Map<String, String> specs;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.brand,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minStock,
    required this.shelfLocation,
    required this.barcode,
    required this.supplierName,
    required this.description,
    this.specs = const {},
    this.imageUrl,
  });

  bool get isLowStock => currentStock <= minStock;
  double get profitMargin => sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;
  double get totalStockValue => currentStock * costPrice;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    String? brand,
    double? costPrice,
    double? sellingPrice,
    int? currentStock,
    int? minStock,
    String? shelfLocation,
    String? barcode,
    String? supplierName,
    String? description,
    Map<String, String>? specs,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      barcode: barcode ?? this.barcode,
      supplierName: supplierName ?? this.supplierName,
      description: description ?? this.description,
      specs: specs ?? this.specs,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
