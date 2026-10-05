import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/features/products/data/product_image_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory temporaryDirectory;
  late ProductImageSyncService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp();
    service = ProductImageSyncService(
      SupabaseClient('http://localhost:54321', 'test-key'),
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('deletes a replaced local image after sync', () async {
    final oldImage = File('${temporaryDirectory.path}/old.png');
    await oldImage.writeAsBytes([1, 2, 3]);

    await service.cleanupReplacedImage(
      previousImage: oldImage.path,
      currentImage: 'supabase://shop/product/new.png',
    );

    expect(await oldImage.exists(), isFalse);
  });

  test('keeps a local image that remains in use', () async {
    final image = File('${temporaryDirectory.path}/current.png');
    await image.writeAsBytes([1, 2, 3]);

    await service.cleanupReplacedImage(
      previousImage: image.path,
      currentImage: image.path,
    );

    expect(await image.exists(), isTrue);
  });
}
