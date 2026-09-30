import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final user = await DatabaseHelper.instance.loginUser(username, password);

      setState(() => _isLoading = false);

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user['FullName']}!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else if (mounted) {
        // Login අසාර්ථකයි නම්
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username or Password is incorrect!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[100], //[cite: 3]
    body: Center( //[cite: 3]
      child: SingleChildScrollView( //[cite: 3]
        padding: const EdgeInsets.all(16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380), // Window එකට හරියන ප්‍රමාණය[cite: 3]
          child: Card( //[cite: 3]
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), //[cite: 3]
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0), //[cite: 3]
              child: Form( //[cite: 3]
                key: _formKey, //[cite: 3]
                child: Column( //[cite: 3]
                  mainAxisSize: MainAxisSize.min, //[cite: 3]
                  children: [
                    const Icon(
                      Icons.point_of_sale, //[cite: 3]
                      size: 56,
                      color: Colors.blue, //[cite: 3]
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EasyBill POS', //[cite: 3]
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold, //[cite: 3]
                      ),
                    ),
                    const Text(
                      'Sign in to continue', //[cite: 3]
                      style: TextStyle(color: Colors.grey), //[cite: 3]
                    ),
                    const SizedBox(height: 24),

                    // Username Input
                    TextFormField( //[cite: 3]
                      controller: _usernameController, //[cite: 3]
                      decoration: InputDecoration(
                        labelText: 'Username', //[cite: 3]
                        prefixIcon: const Icon(Icons.person), //[cite: 3]
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), //[cite: 3]
                        ),
                      ),
                      validator: (value) { //[cite: 3]
                        if (value == null || value.isEmpty) { //[cite: 3]
                          return 'Please enter your username'; //[cite: 3]
                        }
                        return null; //[cite: 3]
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextFormField( //[cite: 3]
                      controller: _passwordController, //[cite: 3]
                      obscureText: !_isPasswordVisible, //[cite: 3]
                      decoration: InputDecoration(
                        labelText: 'Password', //[cite: 3]
                        prefixIcon: const Icon(Icons.lock), //[cite: 3]
                        suffixIcon: IconButton( //[cite: 3]
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off, //[cite: 3]
                          ),
                          onPressed: () { //[cite: 3]
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible; //[cite: 3]
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), //[cite: 3]
                        ),
                      ),
                      validator: (value) { //[cite: 3]
                        if (value == null || value.isEmpty) { //[cite: 3]
                          return 'Please enter your password'; //[cite: 3]
                        }
                        return null; //[cite: 3]
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox( //[cite: 3]
                      width: double.infinity, //[cite: 3]
                      height: 48, //[cite: 3]
                      child: ElevatedButton( //[cite: 3]
                        onPressed: _isLoading ? null : _handleLogin, //[cite: 3]
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, //[cite: 3]
                          foregroundColor: Colors.white, //[cite: 3]
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), //[cite: 3]
                          ),
                        ),
                        child: _isLoading //[cite: 3]
                            ? const CircularProgressIndicator(color: Colors.white) //[cite: 3]
                            : const Text(
                                'Login', //[cite: 3]
                                style: TextStyle(fontSize: 16), //[cite: 3]
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}