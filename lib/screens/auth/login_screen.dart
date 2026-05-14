import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

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
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      // ── Role check: only allow 'user' role ──
      final uid = cred.user?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!userDoc.exists) {
          // Not in users collection — check if they're a provider
          await FirebaseAuth.instance.signOut();
          setState(() => _error = "No account registered with this email.");
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleForgotPassword() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with animated glow
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.car_repair_rounded, size: 60, color: AppTheme.accent),
                ),
                const SizedBox(height: 16),
                Text(loc.tr('appName'),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1, color: textColor)),
                Text(loc.tr('fastAssistance'), style: TextStyle(color: dimColor)),
                const SizedBox(height: 40),

                GlassCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                            labelText: loc.tr('email'),
                            labelStyle: TextStyle(color: dimColor),
                            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                            labelText: loc.tr('password'),
                            labelStyle: TextStyle(color: dimColor),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.accent),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: dimColor,
                                size: 22,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                        ),
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    child: Text(
                      loc.tr('forgotPassword'),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
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
                  text: loc.tr('login'),
                  onPressed: _loading ? null : _login,
                  isLoading: _loading,
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: Text(
                      loc.tr('noAccount'),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)
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