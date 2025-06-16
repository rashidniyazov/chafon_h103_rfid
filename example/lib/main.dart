import 'package:chafon_h103_rfid_example/presentaion/login/login_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: const LoginScreen(),
      routes: {
        "/functions": (context) =>
            LoginScreen(),
      },
    ),
  );
}
