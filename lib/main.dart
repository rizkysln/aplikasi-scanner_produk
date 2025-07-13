import 'package:flutter/material.dart';
import 'screens/product_scanner.dart';
import 'theme.dart';

void main() {
  runApp(MaterialApp(
    theme: customTheme(),
    home: ProductScanner(),
  ));
}