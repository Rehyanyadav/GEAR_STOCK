import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/widgets/product_image.dart';

void main() {
  testWidgets('product image handles an unbounded parent width', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ProductImage(
                  source: null,
                  width: double.infinity,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
