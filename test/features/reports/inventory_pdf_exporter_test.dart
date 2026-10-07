import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/features/reports/data/inventory_pdf_exporter.dart';

void main() {
  group('buildInventoryPdf', () {
    test('creates a readable inventory PDF with the provided snapshot', () async {
      final bytes = await buildInventoryPdf(
        products: const [
          InventoryPdfProduct(
            id: 'part-1',
            name: 'Brake Cable',
            sku: 'BC-001',
            costPrice: 120.5,
            sellingPrice: 199.0,
            currentStock: 12,
            minStock: 3,
            shelfLocation: 'A1',
            imageSource: null,
          ),
        ],
        images: const {},
        generatedAt: DateTime(2026, 10, 6, 22, 15),
      );

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  });
}
