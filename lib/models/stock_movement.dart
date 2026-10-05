enum StockMovementType {
  inbound,
  outboundSale,
  outboundService,
  adjustment,
  returnToVendor,
}

extension StockMovementTypeExt on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.inbound:
        return 'Inbound';
      case StockMovementType.outboundSale:
        return 'Counter Sale';
      case StockMovementType.outboundService:
        return 'Workshop Service';
      case StockMovementType.adjustment:
        return 'Stock Adjustment';
      case StockMovementType.returnToVendor:
        return 'Return to Vendor';
    }
  }

  bool get isInbound => this == StockMovementType.inbound;
}

class StockMovement {
  final String id;
  final StockMovementType type;
  final String referenceNumber;
  final String productId;
  final String productName;
  final String productSku;
  final int quantity; // e.g. +10 or -2
  final double unitPrice;
  final DateTime timestamp;
  final String notes;
  final String operatorName;

  StockMovement({
    required this.id,
    required this.type,
    required this.referenceNumber,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unitPrice,
    required this.timestamp,
    this.notes = '',
    this.operatorName = 'Rajesh',
  });

  double get totalAmount => (quantity.abs() * unitPrice);
}
