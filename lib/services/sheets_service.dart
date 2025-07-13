import 'package:gsheets/gsheets.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';

class SheetsService {
  static const String _spreadsheetId =
      '1m4RtYARJz9osIQUpxR5ytI8pUUytz5UtyWyGMaibyhA';
  GSheets? _gsheets;
  Worksheet? _worksheet;
  Worksheet? _worksheet2;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await init();
  }

  Future<void> init() async {
    try {
      final credentials = await _loadCredentials();
      _gsheets = GSheets(credentials);

      final spreadsheet = await _gsheets!.spreadsheet(_spreadsheetId);
      _worksheet = spreadsheet.worksheetByTitle('Sheet1');
      _worksheet2 = spreadsheet.worksheetByTitle('Sheet2');

      _worksheet ??= await spreadsheet.addWorksheet('Sheet1');

      _worksheet2 ??= await spreadsheet.addWorksheet('Sheet2');

      await _initializeHeaders();
      await _initializeSheet2Headers();
      _initialized = true;
    } catch (e) {
      print('Error detail: $e');
      throw Exception('Error initializing Google Sheets: $e');
    }
  }

  Future<String> _loadCredentials() async {
    try {
      return await rootBundle.loadString('assets/credentials.json');
    } catch (e) {
      throw Exception('Failed to load credentials.json: $e');
    }
  }

  Future<void> _initializeHeaders() async {
    try {
      final header = await _worksheet?.values.row(1);
      if (header == null || header.isEmpty) {
        await _worksheet?.values
            .insertRow(1, ['Barcode', 'Nama Produk', 'Harga']);
      }
    } catch (e) {
      throw Exception('Failed to initialize headers: $e');
    }
  }

  Future<void> _initializeSheet2Headers() async {
    try {
      final header = await _worksheet2?.values.row(1);
      if (header == null || header.isEmpty) {
        await _worksheet2?.values.insertRow(
            1, ['Nama Produk', 'Harga', 'Quantity', 'Total', 'Tanggal']);
      }
    } catch (e) {
      throw Exception('Failed to initialize Sheet2 headers: $e');
    }
  }

  Future<Product?> findProductByBarcode(String barcode) async {
    await _ensureInitialized();
    try {
      final rows = await _worksheet!.values.allRows();
      if (rows.isEmpty) return null;

      for (var row in rows.skip(1)) {
        if (row.isNotEmpty && row[0] == barcode) {
          return Product.fromSheetRow(row);
        }
      }
      return null;
    } catch (e) {
      print('Error finding product: $e');
      throw Exception('Error mencari produk: $e');
    }
  }

  Future<void> insertProduct(String barcode, String nama, double harga) async {
    await _ensureInitialized();
    try {
      if (await findProductByBarcode(barcode) != null) {
        throw Exception('Produk dengan barcode $barcode sudah ada.');
      }
      await _worksheet!.values.appendRow([barcode, nama, harga.toString()]);
    } catch (e) {
      throw Exception('Failed to insert product: $e');
    }
  }

  Future<void> updateProduct(String barcode, String nama, int harga) async {
    await _ensureInitialized();
    try {
      final rows = await _worksheet!.values.allRows();
      for (var i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0] == barcode) {
          await _worksheet!.values
              .insertRow(i + 1, [barcode, nama, harga.toString()]);
          return;
        }
      }
      throw Exception('Produk tidak ditemukan.');
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String barcode) async {
    await _ensureInitialized();
    try {
      final rows = await _worksheet!.values.allRows();
      for (var i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0] == barcode) {
          await _worksheet!.deleteRow(i + 1);
          return;
        }
      }
      throw Exception('Produk tidak ditemukan.');
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> sendToSheet2(List<Map<String, dynamic>> products) async {
    await _ensureInitialized();
    try {
      // Hapus semua data kecuali header
      await clearSheet2Data();

      // Tambahkan data baru
      for (var product in products) {
        await _worksheet2!.values.appendRow([
          product['nama'],
          product['harga'],
          product['quantity'].toString(),
          product['total'],
          DateTime.now().toString(),
        ]);
      }

      // Dapatkan jumlah baris terakhir
      var lastRowIndex = await _worksheet2!.rowCount;

      // Tambahkan rumus SUM untuk Total Belanja
      await _worksheet2!.values.insertValue('=SUM(D2:D$lastRowIndex)',
          column: 6, // Kolom F (Total Belanja)
          row: lastRowIndex + 1 // Baris di bawah data terakhir
          );
    } catch (e) {
      throw Exception('Failed to send data to Sheet2: $e');
    }
  }

  // Fungsi untuk mendapatkan semua data dari Sheet2
  Future<List<List<String>>> getSheet2Data() async {
    await _ensureInitialized();
    try {
      return await _worksheet2!.values.allRows();
    } catch (e) {
      throw Exception('Failed to get Sheet2 data: $e');
    }
  }

  // Fungsi untuk menghapus semua data di Sheet2 (kecuali header)
  Future<void> clearSheet2Data() async {
    await _ensureInitialized();
    try {
      final rowCount = await _worksheet2!.rowCount;
      if (rowCount > 1) {
        await _worksheet2!.deleteRow(2, count: rowCount - 1);
      }
    } catch (e) {
      throw Exception('Failed to clear Sheet2 data: $e');
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      await _worksheet?.values.appendRow([
        product.barcode,
        product.name,
        product.price.toString(),
      ]);
    } catch (e) {
      throw Exception('Error adding product: $e');
    }
  }
  Future<List<Product>> getProducts() async {
  await _ensureInitialized(); // Gunakan method yang sudah ada
  
  // Gunakan _worksheet yang sudah didefinisikan
  final values = await _worksheet!.values.allRows();
  
  // Skip baris header dan convert ke list of Product
  return values.skip(1).map((row) => Product(
    barcode: row[0],
    name: row[1],
    price: double.parse(row[2]),
  )).toList();
}

Future<Product?> getProductByBarcode(String barcode) async {
  final products = await getProducts();
  try {
    return products.firstWhere((product) => product.barcode == barcode);
  } catch (e) {
    return null; // Return null jika barcode tidak ditemukan
  }
}
}
