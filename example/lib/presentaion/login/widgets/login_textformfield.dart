import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? toggleObscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.isPassword = false,
    this.obscureText = false,
    this.toggleObscureText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // istədiyin radius dəyəri (məsələn 12)
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: toggleObscureText,
        )
            : null,
      ),
    );
  }
}