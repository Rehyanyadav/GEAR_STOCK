import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/products/data/product_image_sync_service.dart';

class ProductImage extends ConsumerWidget {
  final String? source;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  const ProductImage({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.inventory_2_outlined,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageSource = source?.trim() ?? '';
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width.isFinite ? (width * pixelRatio).round() : null;
    final cacheHeight = height.isFinite ? (height * pixelRatio).round() : null;
    final isRemote = imageSource.startsWith('https://') ||
        imageSource.startsWith('http://');
    final isPrivateStorageImage = imageSource.startsWith('supabase://');

    Widget image;
    if (imageSource.isEmpty) {
      image = _placeholder(context);
    } else if (isPrivateStorageImage) {
      final userId = ref.watch(authenticatedUserIdProvider);
      if (userId == null) {
        image = _placeholder(context);
      } else {
        final imageBytes = ref.watch(
          productImageBytesProvider((
            userId: userId,
            objectPath: imageSource.substring('supabase://'.length),
          )),
        );
        image = imageBytes.when(
          data: (bytes) => Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            errorBuilder: (_, _, _) => _placeholder(context),
          ),
          loading: () => _placeholder(context),
          error: (_, _) => _placeholder(context),
        );
      }
    } else if (isRemote) {
      image = CachedNetworkImage(
        imageUrl: imageSource,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (_, _) => _placeholder(context),
        errorWidget: (_, _, _) => _placeholder(context),
      );
    } else if (kIsWeb) {
      image = Image.network(
        imageSource,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    } else {
      image = Image.file(
        File(imageSource),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        color: Theme.of(context).colorScheme.primary,
        size: height < 80 ? height * 0.45 : 40,
      ),
    );
  }
}
