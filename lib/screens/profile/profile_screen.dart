import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationsEnabled = true;
  bool isUploading = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Login Required")));

    final uid = user.uid;
    final displayName = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : "User";
    final userDocRef = FirebaseFirestore.instance.collection("users").doc(uid);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDocRef.snapshots(),
        builder: (context, userSnap) {
          final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
          final phone = (userData["phone"] ?? "—").toString();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 40),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.accent.withOpacity(0.1),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.accent, width: 2)),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.card,
                          backgroundImage: (user.photoURL != null) ? NetworkImage(user.photoURL!) : null,
                          child: isUploading
                              ? const CircularProgressIndicator(color: AppTheme.accent)
                              : (user.photoURL == null)
                              ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.accent))
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => _pickAndUploadImage(context, user),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Center(child: Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              Center(child: Text("Member since ${_formatDate(user.metadata.creationTime)}", style: const TextStyle(color: AppTheme.textDim, fontSize: 13))),

              const SizedBox(height: 30),

              GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatStream(
                      stream: FirebaseFirestore.instance.collection("requests").where("userId", isEqualTo: uid).snapshots(),
                      label: "Services",
                    ),
                    _StatStream(
                      stream: userDocRef.collection("vehicles").snapshots(),
                      label: "Vehicles",
                    ),
                    const _PStat(title: "5.0", sub: "Rating"),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              _SectionLabel("CONTACT INFORMATION"),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.phone_rounded, label: "Phone", value: phone,
                      onEdit: () => _openEditContactSheet(context, userDocRef: userDocRef, currentPhone: phone),
                    ),
                    const Divider(color: Colors.white10, height: 25),
                    _InfoRow(icon: Icons.email_rounded, label: "Email", value: user.email ?? "—"),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              _SectionLabel("PREFERENCES"),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    _SettingRow(title: "Payment Methods", icon: Icons.credit_card_rounded),
                    _SettingRow(title: "Account Security", icon: Icons.shield_rounded),
                    _SettingRow(
                      title: "Notifications", icon: Icons.notifications_rounded,
                      trailing: Switch(
                        value: notificationsEnabled,
                        activeColor: AppTheme.accent,
                        onChanged: (v) => setState(() => notificationsEnabled = v),
                      ),
                    ),
                    _SettingRow(
                      title: "Logout", icon: Icons.logout_rounded, isLast: true,
                      color: Colors.redAccent,
                      onTap: () => FirebaseAuth.instance.signOut(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "—";
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[dt.month - 1]} ${dt.year}";
  }

  Widget _SectionLabel(String text) => Text(text, style: const TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2));

  Future<void> _pickAndUploadImage(BuildContext context, User user) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text("Select Profile Photo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accent),
              title: const Text("Camera"),
              onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.camera, imageQuality: 70)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accent),
              title: const Text("Gallery"),
              onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.gallery, imageQuality: 70)),
            ),
          ],
        ),
      ),
    );

    if (image == null) return;
    setState(() => isUploading = true);

    try {
      final File file = File(image.path);
      final String refPath = 'users/${user.uid}/profile_pic.jpg';
      final TaskSnapshot uploadTask = await FirebaseStorage.instance.ref(refPath).putFile(file);
      final String downloadUrl = await uploadTask.ref.getDownloadURL();
      await user.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({"photoURL": downloadUrl});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated ✅")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _openEditContactSheet(BuildContext context, {required DocumentReference userDocRef, required String currentPhone}) {
    final phoneCtrl = TextEditingController(text: currentPhone == "—" ? "" : currentPhone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Phone", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone Number",
                prefixIcon: const Icon(Icons.phone, color: AppTheme.accent),
                filled: true, fillColor: AppTheme.bg.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () async {
                  await userDocRef.set({"phone": phoneCtrl.text.trim()}, SetOptions(merge: true));
                  Navigator.pop(ctx);
                },
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MISSING HELPER CLASSES RESTORED BELOW ---

class _StatStream extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String label;
  const _StatStream({required this.stream, required this.label});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) => _PStat(title: "${snap.data?.docs.length ?? 0}", sub: label),
    );
  }
}

class _PStat extends StatelessWidget {
  final String title, sub;
  const _PStat({required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accent)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onEdit;
  const _InfoRow({required this.icon, required this.label, required this.value, this.onEdit});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.accent, size: 20),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ])),
      if (onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_square, size: 18, color: AppTheme.textDim)),
    ]);
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLast;
  const _SettingRow({required this.title, required this.icon, this.onTap, this.trailing, this.color, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color ?? AppTheme.textDim, size: 22),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.white)),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white10),
        ),
        if (!isLast) const Divider(color: Colors.white10, height: 1),
      ],
    );
  }
}