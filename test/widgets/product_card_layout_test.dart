import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/models/product.dart';
import 'package:gearstock/theme/app_theme.dart';
import 'package:gearstock/widgets/product_card.dart';

void main() {
  testWidgets('product card fits on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ProductCard(
                  product: Product(
                    id: 'product',
                    name: 'Brake pads',
                    sku: 'VERY-LONG-SKU-123456789',
                    category: 'Brakes',
                    brand: 'Very Long Bicycle Parts Brand Name',
                    costPrice: 71,
                    sellingPrice: 89,
                    currentStock: 14,
                    minStock: 2,
                    shelfLocation: '',
                    barcode: '',
                    supplierName: '',
                    description: '',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('14 in stock'), findsOneWidget);
  });
}
