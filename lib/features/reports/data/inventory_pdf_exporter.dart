import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InventoryPdfProduct {
  const InventoryPdfProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minStock,
    required this.shelfLocation,
    required this.imageSource,
  });

  final String id;
  final String name;
  final String sku;
  final double costPrice;
  final double sellingPrice;
  final int currentStock;
  final int minStock;
  final String shelfLocation;
  final String? imageSource;
}

Future<Uint8List> buildInventoryPdf({
  required List<InventoryPdfProduct> products,
  required Map<String, Uint8List> images,
  required DateTime generatedAt,
}) async {
  final document = pw.Document(
    title: 'GearStock Inventory',
    author: 'GearStock',
  );
  final generatedLabel = DateFormat('dd-MM-yyyy HH:mm').format(generatedAt);
  final priceFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'INR ',
    decimalDigits: 2,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: products.length + 10,
      header: (_) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          'GearStock | Inventory | $generatedLabel',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => [
        pw.Text(
          'Stock Inventory',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${products.length} active products',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.8),
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(58),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              children: [
                _headerCell(''),
                _headerCell('Product'),
                _headerCell('Stock'),
              ],
            ),
            for (final product in products)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: _productImage(images[product.id]),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          product.name,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'SKU: ${product.sku}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (product.shelfLocation.isNotEmpty)
                          pw.Text(
                            'Location: ${product.shelfLocation}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${product.currentStock} in stock',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Minimum: ${product.minStock}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Cost: ${priceFormat.format(product.costPrice)}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Selling: ${priceFormat.format(product.sellingPrice)}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );

  return document.save(enableEventLoopBalancing: true);
}

pw.Widget _headerCell(String label) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  child: pw.Text(
    label,
    style: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

pw.Widget _productImage(Uint8List? bytes) {
  if (bytes == null) {
    return pw.Container(
      width: 48,
      height: 48,
      color: PdfColors.grey200,
      alignment: pw.Alignment.center,
      child: pw.Text('No image', style: const pw.TextStyle(fontSize: 7)),
    );
  }

  return pw.Image(
    pw.MemoryImage(bytes, dpi: 72),
    width: 48,
    height: 48,
    fit: pw.BoxFit.cover,
  );
}
