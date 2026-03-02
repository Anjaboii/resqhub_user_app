import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final vehiclesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Vehicles"),
        actions: [
          IconButton(
            onPressed: () => _showAddVehicleSheet(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: vehiclesRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No vehicles yet.\nTap + to add one.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snap.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final name = (data["name"] ?? "").toString();
              final plate = (data["plate"] ?? "").toString();
              final meta = (data["meta"] ?? "").toString();
              final isDefault = (data["isDefault"] ?? false) as bool;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Text(
                                    "Default",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plate,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(meta, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == "default") {
                          await _setDefault(uid, doc.id);
                        } else if (v == "delete") {
                          await doc.reference.delete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: "default", child: Text("Set as default")),
                        PopupMenuItem(value: "delete", child: Text("Delete")),
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
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final metaCtrl = TextEditingController();
    bool loading = false;
    String? error;

    Future<void> save(StateSetter setModalState) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final name = nameCtrl.text.trim();
      final plate = plateCtrl.text.trim().toUpperCase();
      final meta = metaCtrl.text.trim();

      if (name.isEmpty || plate.isEmpty) {
        setModalState(() => error = "Name and plate are required");
        return;
      }

      setModalState(() {
        loading = true;
        error = null;
      });

      try {
        final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('vehicles');

        // ✅ Prevent duplicates by plate
        final dup = await col.where('plate', isEqualTo: plate).limit(1).get();
        if (dup.docs.isNotEmpty) {
          setModalState(() {
            loading = false;
            error = "This plate is already added.";
          });
          return;
        }

        await col.add({
          "name": name,
          "plate": plate,
          "meta": meta,
          "isDefault": false,
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        setModalState(() {
          loading = false;
          error = "Failed to add vehicle";
        });
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF070A12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add Vehicle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Vehicle name (e.g., Toyota Corolla)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(labelText: "Plate number (e.g., CAB-1234)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: metaCtrl,
                    decoration: const InputDecoration(labelText: "Notes (optional)"),
                  ),
                  const SizedBox(height: 12),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : () => save(setModalState),
                      child: loading
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text("Save"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}