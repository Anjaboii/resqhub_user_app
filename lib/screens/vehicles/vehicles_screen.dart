import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final vehiclesRef = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('vehicles')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("My Garage", style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        onPressed: () => _showAddVehicleSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: vehiclesRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No vehicles added yet.", style: TextStyle(color: AppTheme.textDim)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final isDefault = data["isDefault"] ?? false;
              return GlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data["name"] ?? "Vehicle", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(data["plate"] ?? "", style: const TextStyle(color: AppTheme.textDim, fontSize: 13, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    if (isDefault) const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppTheme.textDim),
                      onSelected: (v) async {
                        if (v == "default") await _setDefault(uid, docs[i].id);
                        if (v == "delete") await docs[i].reference.delete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: "default", child: Text("Set as Default")),
                        const PopupMenuItem(value: "delete", child: Text("Remove", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _setDefault(String uid, String vehicleId) async {
    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles');
    final all = await col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in all.docs) {
      batch.update(d.reference, {"isDefault": d.id == vehicleId});
    }
    await batch.commit();
  }

  static Future<void> _showAddVehicleSheet(BuildContext context) async {
    final platePrefix = TextEditingController();
    final plateNumbers = TextEditingController();
    String? selectedBrand;
    String? selectedModel;
    String? errorMessage; // 👈 New Variable for Error State

    final Map<String, List<String>> vehicleData = {
      "Toyota": ["Corolla", "Axio", "Prius", "Vitz", "Hilux"],
      "Honda": ["Civic", "Fit", "Vezel", "CR-V"],
      "Mitsubishi": ["Pajero", "Montero", "Lancer"],
      "Suzuki": ["Wagon R", "Swift", "Alto"],
      "Nissan": ["X-Trail", "Sunny", "Dayz"],
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const Text("Add New Vehicle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                dropdownColor: AppTheme.card,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldStyle("Select Brand", Icons.apartment_rounded),
                items: vehicleData.keys.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) => setModalState(() { selectedBrand = val; selectedModel = null; errorMessage = null; }),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                dropdownColor: AppTheme.card,
                value: selectedModel,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldStyle("Select Model", Icons.directions_car_rounded),
                items: (selectedBrand == null) ? [] : vehicleData[selectedBrand]!.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setModalState(() { selectedModel = val; errorMessage = null; }),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: platePrefix,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onChanged: (_) => setModalState(() => errorMessage = null),
                      inputFormatters: [LengthLimitingTextInputFormatter(3)],
                      decoration: _fieldStyle("Prefix", null).copyWith(hintText: "CAB"),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("-", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: plateNumbers,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onChanged: (_) => setModalState(() => errorMessage = null),
                      inputFormatters: [LengthLimitingTextInputFormatter(6), FilteringTextInputFormatter.digitsOnly],
                      decoration: _fieldStyle("Number", null).copyWith(hintText: "6197"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ⚠️ ERROR MESSAGE WIDGET
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () async {
                    // 🔍 VALIDATION LOGIC
                    if (selectedBrand == null || selectedModel == null || platePrefix.text.trim().isEmpty || plateNumbers.text.trim().isEmpty) {
                      setModalState(() {
                        errorMessage = "Please fill in all vehicle details.";
                      });
                      return;
                    }

                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final fullPlate = "${platePrefix.text.toUpperCase()} - ${plateNumbers.text}";

                    await FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles').add({
                      "name": "$selectedBrand $selectedModel",
                      "plate": fullPlate,
                      "isDefault": false,
                      "createdAt": FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Save Vehicle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _fieldStyle(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.textDim, size: 20) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.accent)),
    );
  }
}