import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  // 🚀 Logic: Standard Login
  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔑 Logic: Forgot Password Reset
  Future<void> _handleForgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Enter your email to reset password");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reset link sent! Check your email inbox."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = "Failed to send reset email");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.car_repair_rounded, size: 80, color: AppTheme.accent),
                const SizedBox(height: 10),
                const Text("ResQHub",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                const Text("Fast assistance, anytime.", style: TextStyle(color: AppTheme.textDim)),
                const SizedBox(height: 40),

                GlassCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Email",
                            labelStyle: TextStyle(color: AppTheme.textDim),
                            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.accent)
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Password",
                            labelStyle: TextStyle(color: AppTheme.textDim),
                            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent)
                        ),
                      ),
                    ],
                  ),
                ),

                // 🎯 Forgot Password Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),

                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                  ),

                const SizedBox(height: 24),

                PrimaryButton(
                  text: "Login",
                  onPressed: _loading ? null : _login,
                  isLoading: _loading,
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)
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