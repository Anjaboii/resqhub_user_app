import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _method = 'email'; // email or sms
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _error;

  Future<void> _sendResetLink() async {
    if (_emailCtrl.text.trim().isEmpty) { setState(() => _error = "Please enter your email"); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Failed to send reset link");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('forgotPasswordTitle'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent.withValues(alpha: 0.1)),
            child: const Icon(Icons.lock_reset_rounded, color: AppTheme.accent, size: 48)),
          const SizedBox(height: 20),
          Text(loc.tr('forgotPasswordTitle'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 8),
          Text("Choose how you'd like to reset your password", textAlign: TextAlign.center,
            style: TextStyle(color: dimColor, fontSize: 14)),
          const SizedBox(height: 30),

          if (_sent) ...[
            GlassCard(child: Column(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
              const SizedBox(height: 12),
              Text("Reset link sent!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text("Check your email inbox and follow the link to reset your password.",
                textAlign: TextAlign.center, style: TextStyle(color: dimColor, fontSize: 14)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: const Text("BACK TO LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ])),
          ] else ...[
            // Method selector
            Row(children: [
              Expanded(child: _MethodCard(icon: Icons.email_rounded, label: loc.tr('resetViaEmail'),
                selected: _method == 'email', isDark: isDark, onTap: () => setState(() => _method = 'email'))),
              const SizedBox(width: 12),
              Expanded(child: _MethodCard(icon: Icons.sms_rounded, label: loc.tr('resetViaSMS'),
                selected: _method == 'sms', isDark: isDark, onTap: () => setState(() => _method = 'sms'))),
            ]),
            const SizedBox(height: 24),

            GlassCard(child: Column(children: [
              if (_method == 'email') ...[
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(labelText: loc.tr('enterEmail'),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accent))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _isLoading ? null : _sendResetLink,
                  child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(loc.tr('sendResetLink'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
              ] else ...[
                TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(labelText: loc.tr('enterPhone'),
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.accent),
                    hintText: "+94 7X XXX XXXX")),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _isLoading ? null : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("SMS OTP coming soon. Use email reset for now.")));
                  },
                  child: Text(loc.tr('sendOTP'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
              ],
            ])),

            if (_error != null) Padding(padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
          ],
        ]),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon; final String label; final bool selected, isDark; final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.label, required this.selected, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.getStroke(isDark), width: selected ? 2 : 1)),
      child: Column(children: [
        Icon(icon, color: selected ? AppTheme.accent : AppTheme.getTextDim(isDark), size: 28),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.getTextPrimary(isDark), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}
