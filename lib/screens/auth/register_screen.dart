import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController(), _phone = TextEditingController();
  final _email = TextEditingController(), _password = TextEditingController(), _plate = TextEditingController();
  String? _brand, _model;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  int _step = 0; // 0=details, 1=vehicle, 2=security, 3=verify

  final Map<String, List<String>> _brandModels = const {
    "Toyota": ["Corolla", "Axio", "Allion", "Prius", "Vitz", "Hilux"],
    "Honda": ["Civic", "Fit", "Vezel", "CR-V", "City"],
    "Nissan": ["March", "Tiida", "X-Trail", "Sunny"],
    "Suzuki": ["Wagon R", "Swift", "Alto"],
    "Mitsubishi": ["Lancer", "Montero", "Pajero"],
    "Other": ["Other"],
  };

  void _nextStep() {
    if (_step == 0) {
      if (_fullName.text.trim().isEmpty || _phone.text.trim().isEmpty) { setState(() => _error = "Please fill all fields"); return; }
    } else if (_step == 1) {
      if (_brand == null || _plate.text.trim().isEmpty) { setState(() => _error = "Please complete vehicle details"); return; }
    }
    setState(() { _step++; _error = null; });
  }

  void _prevStep() { if (_step > 0) setState(() { _step--; _error = null; }); }

  Future<void> _register() async {
    if (_email.text.isEmpty || _password.text.length < 6) {
      setState(() => _error = "Email and password (6+ chars) required");
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      await cred.user!.updateDisplayName(_fullName.text.trim());

      // Send email verification
      await cred.user!.sendEmailVerification();

      final userDoc = FirebaseFirestore.instance.collection("users").doc(cred.user!.uid);
      await userDoc.set({
        "fullName": _fullName.text.trim(),
        "email": _email.text.trim(),
        "phone": _phone.text.trim(),
        "emailVerified": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await userDoc.collection("vehicles").add({
        "brand": _brand, "model": _model, "name": "$_brand $_model",
        "plate": _plate.text.trim().toUpperCase(), "isDefault": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      setState(() => _step = 3); // Move to verification step
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Registration failed");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('createAccount'), style: const TextStyle(fontWeight: FontWeight.w900)),
        leading: _step > 0 && _step < 3 ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep) : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Step indicator
          if (_step < 3) ...[
            Row(children: List.generate(3, (i) => Expanded(child: Container(
              height: 4, margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
                color: i <= _step ? AppTheme.accent : AppTheme.getStroke(isDark)),
            )))),
            const SizedBox(height: 8),
            Text("Step ${_step + 1} of 3", style: TextStyle(color: dimColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
          ],

          // Step 0: Personal Details
          if (_step == 0) GlassCard(child: Column(children: [
            Text(loc.tr('personalDetails'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: _fullName, style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: loc.tr('fullName'), prefixIcon: const Icon(Icons.person_outline, color: AppTheme.accent))),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, style: TextStyle(color: textColor),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
              decoration: InputDecoration(labelText: loc.tr('phone'), hintText: "+94 7X XXX XXXX",
                prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.accent))),
          ])),

          // Step 1: Vehicle
          if (_step == 1) GlassCard(child: Column(children: [
            Text(loc.tr('vehicleDetails'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent, fontSize: 16)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _brand, dropdownColor: AppTheme.getCard(isDark), style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: loc.tr('selectBrand'), prefixIcon: const Icon(Icons.directions_car, color: AppTheme.accent)),
              items: _brandModels.keys.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() { _brand = v; _model = null; })),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _model, dropdownColor: AppTheme.getCard(isDark), style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: loc.tr('selectModel'), prefixIcon: const Icon(Icons.build_circle, color: AppTheme.accent)),
              items: (_brand != null) ? _brandModels[_brand!]!.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList() : [],
              onChanged: (v) => setState(() => _model = v)),
            const SizedBox(height: 12),
            TextField(controller: _plate, style: TextStyle(color: textColor), textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: loc.tr('plateNumber'), hintText: "CAB-1234",
                prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppTheme.accent))),
          ])),

          // Step 2: Security
          if (_step == 2) GlassCard(child: Column(children: [
            Text(loc.tr('security'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: loc.tr('email'), prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accent))),
            const SizedBox(height: 12),
            TextField(controller: _password, obscureText: _obscurePassword, style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: loc.tr('password'),
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.accent),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: dimColor, size: 22),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline, size: 14, color: dimColor), const SizedBox(width: 6),
              Text("Password must be at least 6 characters", style: TextStyle(color: dimColor, fontSize: 12)),
            ]),
          ])),

          // Step 3: Verification
          if (_step == 3) GlassCard(child: Column(children: [
            const Icon(Icons.mark_email_read_rounded, color: AppTheme.accent, size: 60),
            const SizedBox(height: 16),
            Text("Verify Your Email", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: textColor)),
            const SizedBox(height: 12),
            Text("We've sent a verification link to\n${_email.text.trim()}", textAlign: TextAlign.center,
              style: TextStyle(color: dimColor, fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification email resent!")));
              },
              child: Text(loc.tr('resendOTP'), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                await FirebaseAuth.instance.currentUser?.reload();
                if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
                  await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.uid).update({"emailVerified": true});
                  if (mounted) Navigator.pop(context);
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email not verified yet. Check your inbox.")));
                }
              },
              child: const Text("I'VE VERIFIED MY EMAIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Continue later", style: TextStyle(color: dimColor, fontWeight: FontWeight.w600)),
            ),
          ])),

          if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 30),

          // Navigation buttons
          if (_step < 2) PrimaryButton(text: loc.tr('continueText'), onPressed: _nextStep),
          if (_step == 2) PrimaryButton(text: loc.tr('registerNow'), onPressed: _loading ? null : _register, isLoading: _loading),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}