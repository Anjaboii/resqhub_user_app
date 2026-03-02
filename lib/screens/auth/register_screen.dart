import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();

  final _email = TextEditingController();
  final _password = TextEditingController();

  // Vehicle inputs
  final _plate = TextEditingController();
  String? _brand;
  String? _model;

  bool _loading = false;
  String? _error;

  // Simple brand -> models list (you can expand later)
  final Map<String, List<String>> _brandModels = const {
    "Toyota": ["Corolla", "Axio", "Allion", "Prius", "Vitz", "Hilux"],
    "Honda": ["Civic", "Fit", "Vezel", "CR-V", "City"],
    "Nissan": ["March", "Tiida", "X-Trail", "Sunny"],
    "Suzuki": ["Wagon R", "Swift", "Alto"],
    "Mitsubishi": ["Lancer", "Montero", "Pajero"],
    "Kia": ["Sportage", "Rio", "Sorento"],
    "Hyundai": ["Tucson", "Elantra", "Santa Fe"],
    "Other": ["Other"],
  };

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    final brand = _brand;
    final model = _model;
    final plate = _plate.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _error = "Please enter your full name");
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = "Please enter your email");
      return;
    }
    if (password.length < 6) {
      setState(() => _error = "Password must be at least 6 characters");
      return;
    }

    // Vehicle required for your new flow
    if (brand == null || model == null) {
      setState(() => _error = "Please select your vehicle brand and model");
      return;
    }
    if (plate.isEmpty) {
      setState(() => _error = "Please enter your vehicle plate number");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception("User creation failed");
      }

      // set displayName in FirebaseAuth
      await user.updateDisplayName(name);

      final userDoc = FirebaseFirestore.instance.collection("users").doc(user.uid);

      // create user profile doc
      await userDoc.set({
        "fullName": name,
        "email": email,
        "phone": phone,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // add initial vehicle into subcollection
      await userDoc.collection("vehicles").add({
        "brand": brand,
        "model": model,
        "name": "$brand $model", // keeps compatibility with your other UI
        "plate": plate,
        "meta": "", // optional notes later
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Register failed");
    } catch (_) {
      setState(() => _error = "Something went wrong");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brands = _brandModels.keys.toList()..sort();
    final models = (_brand != null) ? (_brandModels[_brand!] ?? const <String>[]) : const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _fullName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            const SizedBox(height: 18),

            // Vehicle section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Vehicle",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _brand,
              items: brands
                  .map((b) => DropdownMenuItem(
                value: b,
                child: Text(b),
              ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _brand = v;
                  _model = null; // reset model when brand changes
                });
              },
              decoration: const InputDecoration(
                labelText: "Brand",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _model,
              items: models
                  .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m),
              ))
                  .toList(),
              onChanged: (_brand == null)
                  ? null
                  : (v) {
                setState(() => _model = v);
              },
              decoration: const InputDecoration(
                labelText: "Model",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _plate,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "Plate Number",
                hintText: "e.g. CAB-1234",
              ),
            ),

            const SizedBox(height: 18),

            // Account section
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password (min 6 chars)"),
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Create Account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}