import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../models/product.dart';
import '../services/sheets_service.dart';
import '../screens/login.dart';

class ProductScanner extends StatefulWidget {
  const ProductScanner({super.key});

  @override
  _ProductScannerState createState() => _ProductScannerState();
}

class _ProductScannerState extends State<ProductScanner> {
  final SheetsService _sheetsService = SheetsService();
  List<Product> scannedProducts = [];
  Map<String, int> productQuantities = {};
  double total = 0;
  bool _isLoading = false; // Tambahkan variabel loading

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    try {
      await _sheetsService.init();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize sheets: $e')),
      );
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final barcode = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Batal',
        true,
        ScanMode.BARCODE,
      );

      if (barcode == '-1') return;

      await _processBarcode(barcode);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: $e')),
      );
    }
  }

  Future<void> _inputManualCode() async {
    String? manualCode = await showDialog<String>(
      context: context,
      builder: (context) {
        String inputCode = '';
        return AlertDialog(
          title: Text('Masukkan Kode Produk'),
          content: TextField(
            onChanged: (value) => inputCode = value,
            decoration: InputDecoration(hintText: 'Masukkan Kode'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, inputCode),
              child: Text('OK'),
            ),
          ],
        );
      },
    );

    if (manualCode != null && manualCode.isNotEmpty) {
      await _processBarcode(manualCode);
    }
  }

  Future<void> _processBarcode(String barcode) async {
    final product = await _sheetsService.findProductByBarcode(barcode);
    if (product != null) {
      setState(() {
        if (productQuantities.containsKey(barcode)) {
          productQuantities[barcode] = productQuantities[barcode]! + 1;
        } else {
          scannedProducts.add(product);
          productQuantities[barcode] = 1;
        }
        total += product.price;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk Tidak Ditemukan!')),
      );
    }
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Penghapusan'),
        content: Text('Yakin ingin menghapus item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                String barcode = scannedProducts[index].barcode;
                total -=
                    scannedProducts[index].price * productQuantities[barcode]!;
                scannedProducts.removeAt(index);
                productQuantities.remove(barcode);
              });
              Navigator.pop(context);
            },
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendDataToSheet2() async {
    if (scannedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada produk untuk dikirim!')),
      );
      return;
    }

    // Tampilkan indikator loading dan nonaktifkan tombol
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> productsToSend = scannedProducts
          .map((product) => {
                'nama': product.name,
                'harga': product.price,
                'quantity': productQuantities[product.barcode],
                'total': product.price * productQuantities[product.barcode]!,
              })
          .toList();

      await _sheetsService.sendToSheet2(productsToSend);

      // Reset data setelah berhasil kirim
      setState(() {
        scannedProducts.clear();
        productQuantities.clear();
        total = 0;
        _isLoading = false; // Reset status loading
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil dikirim ke Kasir')),
      );
    } catch (e) {
      // Reset status loading meskipun terjadi error
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Produk'),
        actions: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Image.asset(
                'assets/images/add.png',
                width: 24, // Sesuaikan ukuran
                height: 24,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 16, 96, 16),
                  itemCount: scannedProducts.length,
                  itemBuilder: (context, index) {
                    final product = scannedProducts[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[900],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'Rp ${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Quantity: ${productQuantities[product.barcode]}',
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ],
                        ),
                        trailing: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _confirmDelete(index),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/images/tongs.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[900],
                          ),
                        ),
                        Text(
                          'Rp ${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendDataToSheet2,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.indigo[600],
                          disabledBackgroundColor: Colors.indigo[300], // Warna saat dinonaktifkan
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Memproses...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 25, 25, 25),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Bayar di Kasir',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 25, 25, 25),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 16, // Pindahkan ke bagian atas
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: _scanBarcode,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(8),
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/scan.png',
                            width: 50, height: 50), // Logo
                      ],
                    ),
                  ),
                ),
                Container(
                  child: ElevatedButton(
                    onPressed: _inputManualCode,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(8),
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/manual.png',
                            width: 50, height: 50), // Logo
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}