import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';

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

  final Map<String, List<String>> _brandModels = const {
    "Toyota": ["Corolla", "Axio", "Allion", "Prius", "Vitz", "Hilux"],
    "Honda": ["Civic", "Fit", "Vezel", "CR-V", "City"],
    "Nissan": ["March", "Tiida", "X-Trail", "Sunny"],
    "Suzuki": ["Wagon R", "Swift", "Alto"],
    "Mitsubishi": ["Lancer", "Montero", "Pajero"],
    "Other": ["Other"],
  };

  Future<void> _register() async {
    if (_fullName.text.isEmpty || _email.text.isEmpty || _brand == null || _plate.text.isEmpty) {
      setState(() => _error = "Please complete all fields");
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      await cred.user!.updateDisplayName(_fullName.text.trim());

      final userDoc = FirebaseFirestore.instance.collection("users").doc(cred.user!.uid);
      await userDoc.set({
        "fullName": _fullName.text.trim(),
        "email": _email.text.trim(),
        "phone": _phone.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
      });

      // Add first vehicle as DEFAULT
      await userDoc.collection("vehicles").add({
        "brand": _brand,
        "model": _model,
        "name": "$_brand $_model",
        "plate": _plate.text.trim().toUpperCase(),
        "isDefault": true, // 👈 Important for the Request Flow auto-selection
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Registration failed");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account", style: TextStyle(fontWeight: FontWeight.w900))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                children: [
                  const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
                  const SizedBox(height: 12),
                  TextField(controller: _fullName, decoration: const InputDecoration(labelText: "Full Name")),
                  const SizedBox(height: 12),
                  TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone")),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                children: [
                  const Text("Vehicle Details", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _brand,
                    decoration: const InputDecoration(labelText: "Brand"),
                    items: _brandModels.keys.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() { _brand = v; _model = null; }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _model,
                    decoration: const InputDecoration(labelText: "Model"),
                    items: (_brand != null) ? _brandModels[_brand!]!.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList() : [],
                    onChanged: (v) => setState(() => _model = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _plate, decoration: const InputDecoration(labelText: "Plate Number", hintText: "ABC-1234")),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                children: [
                  const Text("Security", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
                  const SizedBox(height: 12),
                  TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
                  const SizedBox(height: 12),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                ],
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 30),
            PrimaryButton(text: "Register Now", onPressed: _loading ? null : _register),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}