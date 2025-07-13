class Product {
  final String barcode;
  final String name;
  final double price;

  Product({
    required this.barcode,
    required this.name,
    required this.price,
  });

  // Konversi dari List<String> (dari Google Sheets) ke objek Product
  factory Product.fromSheetRow(List<String> row) {
    return Product(
      barcode: row[0],
      name: row[1],
      price: double.tryParse(row[2]) ?? 0.0,
    );
  }

  // Konversi dari Product ke List<String> (untuk disimpan ke Google Sheets)
  List<String> toSheetRow() {
    return [barcode, name, price.toString()];
  }
}
