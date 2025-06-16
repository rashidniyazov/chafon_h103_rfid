import 'package:chafon_h103_rfid_example/presentaion/login/widgets/login_textformfield.dart';
import 'package:chafon_h103_rfid_example/presentaion/login/widgets/smart_ip_input.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _dbNameController = TextEditingController();

  bool _rememberMe = false;
  bool _useDevice = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Logo hissəsi (öz şəklini əlavə et)
                const SizedBox(height: 40),
                SizedBox(
                  height: 120,
                  child:
                      Placeholder(), // Əvəzində: Image.asset('assets/logo.png')
                ),
                const SizedBox(height: 30),

                // Username
                LoginTextField(
                  controller: _usernameController,
                  labelText: 'İstifadəçi adı',
                ),

                const SizedBox(height: 16),

                LoginTextField(
                  controller: _passwordController,
                  labelText: 'Şifrə',
                  isPassword: true,
                  obscureText: _obscurePassword,
                  toggleObscureText: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: LoginTextField(
                        controller: _ipController,
                        labelText: 'IP ünvanı',
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [SmartIpInputFormatter()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: LoginTextField(
                        controller: _portController,
                        labelText: 'Port',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                LoginTextField(
                  controller: _dbNameController,
                  labelText: 'Verilənlər bazasının adı',
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text("Yadda saxla"),
                    const Spacer(),
                    Checkbox(
                      value: _useDevice,
                      onChanged: (value) {
                        setState(() {
                          _useDevice = value ?? false;
                        });
                      },
                    ),
                    const Text("Cihazla daxil ol"),
                  ],
                ),

                const SizedBox(height: 30),

                // Giriş düyməsi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 👈 burada yumru kənar
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16), // istəyə görə
                    ),
                    onPressed: () {
                      // Burada login prosesini idarə edə bilərsən
                      if (_formKey.currentState!.validate()) {
                        print('Login pressed');
                      }
                    },
                    child: const Text('Giriş'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


