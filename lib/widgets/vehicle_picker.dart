import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VehicleSnapshot {
  final String name;
  final String plate;
  final String meta;
  final String source; // "saved" | "temporary"

  const VehicleSnapshot({
    required this.name,
    required this.plate,
    required this.meta,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    "name": name,
    "plate": plate,
    "meta": meta,
  };
}

class VehiclePicker extends StatefulWidget {
  final ValueChanged<VehicleSnapshot> onChanged;

  const VehiclePicker({super.key, required this.onChanged});

  @override
  State<VehiclePicker> createState() => _VehiclePickerState();
}

class _VehiclePickerState extends State<VehiclePicker> {
  String? selectedVehicleId;
  bool useTemporary = false;

  final tempName = TextEditingController();
  final tempPlate = TextEditingController();
  final tempMeta = TextEditingController();

  @override
  void dispose() {
    tempName.dispose();
    tempPlate.dispose();
    tempMeta.dispose();
    super.dispose();
  }

  void _emitTemp() {
    widget.onChanged(VehicleSnapshot(
      name: tempName.text.trim(),
      plate: tempPlate.text.trim(),
      meta: tempMeta.text.trim(),
      source: "temporary",
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final vehiclesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // toggle
        Row(
          children: [
            Expanded(
              child: Text(
                useTemporary ? "Temporary vehicle" : "My vehicles",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => useTemporary = !useTemporary);
              },
              child: Text(useTemporary ? "Use saved vehicle" : "Use another vehicle"),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!useTemporary)
          StreamBuilder<QuerySnapshot>(
            stream: vehiclesRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "No vehicles added yet.\nGo to Vehicles tab and add one, or use 'another vehicle' for this request.",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              // auto select first if none
              selectedVehicleId ??= docs.first.id;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedVehicleId,
                    isExpanded: true,
                    items: [
                      for (final d in docs)
                        DropdownMenuItem(
                          value: d.id,
                          child: Text("${d['name']} • ${d['plate']}"),
                        ),
                    ],
                    onChanged: (id) async {
                      if (id == null) return;
                      setState(() => selectedVehicleId = id);

                      final doc =
                      docs.firstWhere((e) => e.id == id).data() as Map<String, dynamic>;
                      widget.onChanged(VehicleSnapshot(
                        name: (doc["name"] ?? "").toString(),
                        plate: (doc["plate"] ?? "").toString(),
                        meta: (doc["meta"] ?? "").toString(),
                        source: "saved",
                      ));
                    },
                  ),
                ),
              );
            },
          )
        else
          Column(
            children: [
              TextField(
                controller: tempName,
                decoration: const InputDecoration(labelText: "Vehicle name (e.g., Honda Civic)"),
                onChanged: (_) => _emitTemp(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tempPlate,
                decoration: const InputDecoration(labelText: "Plate number (e.g., WP-1234)"),
                onChanged: (_) => _emitTemp(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tempMeta,
                decoration: const InputDecoration(labelText: "Notes (optional)"),
                onChanged: (_) => _emitTemp(),
              ),
            ],
          ),
      ],
    );
  }
}