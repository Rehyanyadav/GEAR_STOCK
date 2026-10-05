import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

const productImagesBucket = 'product-images';

class ProductImageSyncService {
  ProductImageSyncService(this._client);

  final SupabaseClient _client;

  Future<String> uploadLocalImage({
    required String localPath,
    required String productId,
    required String shopId,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('Product image is missing.', localPath);
    }
    final filename = file.uri.pathSegments.last;
    final objectPath = '$shopId/$productId/$filename';
    await _client.storage
        .from(productImagesBucket)
        .upload(objectPath, file, fileOptions: const FileOptions(upsert: true));
    return objectPath;
  }

  Future<Uint8List> downloadImage(String objectPath) {
    return _client.storage.from(productImagesBucket).download(objectPath);
  }

  Future<void> deleteImage(String objectPath) async {
    await _client.storage.from(productImagesBucket).remove([objectPath]);
  }

  Future<void> deleteProductImages({
    required String shopId,
    required String productId,
  }) async {
    final prefix = '$shopId/$productId';
    final files = await _client.storage
        .from(productImagesBucket)
        .list(path: prefix);
    if (files.isEmpty) return;
    await _client.storage
        .from(productImagesBucket)
        .remove(files.map((file) => '$prefix/${file.name}').toList());
  }

  Future<void> cleanupReplacedImage({
    required String? previousImage,
    required String? currentImage,
  }) async {
    if (previousImage == null || previousImage == currentImage) return;
    if (previousImage.startsWith('supabase://')) {
      await deleteImage(previousImage.substring('supabase://'.length));
    } else if (!previousImage.startsWith('http://') &&
        !previousImage.startsWith('https://')) {
      final file = File(previousImage);
      if (await file.exists()) await file.delete();
    }
  }
}

final productImageSyncServiceProvider = Provider<ProductImageSyncService>((
  ref,
) {
  return ProductImageSyncService(ref.watch(supabaseClientProvider));
});

typedef ProductImageRequest = ({String userId, String objectPath});

final productImageBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, ProductImageRequest>((ref, request) async {
      if (ref.watch(authenticatedUserIdProvider) != request.userId) {
        throw StateError('The signed-in account changed during image loading.');
      }
      return ref
          .watch(productImageSyncServiceProvider)
          .downloadImage(request.objectPath);
    });
