import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_provider.dart';
import '../payment/saved_cards_screen.dart';
import 'faq_screen.dart';
import 'about_screen.dart';

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
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.getTextPrimary(isDark);
    final dimColor = AppTheme.getTextDim(isDark);
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
            padding: EdgeInsets.zero,
            children: [
              // ── Gradient Header ──
              Container(
                padding: const EdgeInsets.only(top: 60, bottom: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.3),
                      isDark ? AppTheme.darkBg : AppTheme.lightBg,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.accent, width: 2)),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppTheme.getCard(isDark),
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
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                    Text("${loc.tr('memberSince')} ${_formatDate(user.metadata.creationTime)}", style: TextStyle(color: dimColor, fontSize: 13)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openEditNameSheet(context, user),
                      icon: const Icon(Icons.edit, size: 16, color: AppTheme.accent),
                      label: Text(loc.tr('editProfile'), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.accent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats ──
                    GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatStream(stream: FirebaseFirestore.instance.collection("requests").where("userId", isEqualTo: uid).snapshots(), label: loc.tr('services')),
                          _StatStream(stream: userDocRef.collection("vehicles").snapshots(), label: loc.tr('vehicles')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ── Contact ──
                    _SectionLabel(loc.tr('contactInfo'), isDark),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          _InfoRow(icon: Icons.phone_rounded, label: loc.tr('phone'), value: phone, textColor: textColor, dimColor: dimColor,
                            onEdit: () => _openEditContactSheet(context, userDocRef: userDocRef, currentPhone: phone)),
                          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 25),
                          _InfoRow(icon: Icons.email_rounded, label: loc.tr('email'), value: user.email ?? "—", textColor: textColor, dimColor: dimColor,
                            onEdit: () => _openEditEmailSheet(context, user: user, userDocRef: userDocRef)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ── Preferences ──
                    _SectionLabel(loc.tr('preferences'), isDark),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          // Dark Mode
                          _SettingRow(title: loc.tr('darkMode'), icon: Icons.dark_mode_rounded, textColor: textColor, dimColor: dimColor,
                            trailing: Switch(value: context.watch<ThemeProvider>().isDarkMode, activeColor: AppTheme.accent,
                              onChanged: (_) => context.read<ThemeProvider>().toggleTheme())),
                          // Language
                          _SettingRow(title: loc.tr('language'), icon: Icons.language_rounded, textColor: textColor, dimColor: dimColor,
                            trailing: Text(LocaleProvider.localeNames[context.watch<LocaleProvider>().locale.languageCode] ?? 'English',
                              style: TextStyle(color: dimColor, fontSize: 14)),
                            onTap: () => _showLanguageSheet(context)),
                          // Payment Methods
                          _SettingRow(title: loc.tr('paymentMethods'), icon: Icons.credit_card_rounded, textColor: textColor, dimColor: dimColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedCardsScreen()))),
                          // Notifications
                          _SettingRow(title: loc.tr('notifications'), icon: Icons.notifications_rounded, textColor: textColor, dimColor: dimColor,
                            trailing: Switch(value: notificationsEnabled, activeColor: AppTheme.accent, onChanged: (v) => setState(() => notificationsEnabled = v))),
                          // Account Security
                          _SettingRow(title: loc.tr('accountSecurity'), icon: Icons.shield_rounded, textColor: textColor, dimColor: dimColor, isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ── Support ──
                    _SectionLabel(loc.tr('support'), isDark),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          _SettingRow(title: loc.tr('faq'), icon: Icons.help_outline_rounded, textColor: textColor, dimColor: dimColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen()))),
                          _SettingRow(title: loc.tr('aboutUs'), icon: Icons.info_outline_rounded, textColor: textColor, dimColor: dimColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
                          _SettingRow(title: loc.tr('termsConditions'), icon: Icons.description_outlined, textColor: textColor, dimColor: dimColor),
                          _SettingRow(title: loc.tr('privacyPolicy'), icon: Icons.privacy_tip_outlined, textColor: textColor, dimColor: dimColor, isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ── Logout ──
                    GlassCard(
                      child: _SettingRow(
                        title: loc.tr('logout'), icon: Icons.logout_rounded, isLast: true,
                        color: Colors.redAccent, textColor: textColor, dimColor: dimColor,
                        onTap: () => FirebaseAuth.instance.signOut(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text("${loc.tr('version')} 1.0.0", style: TextStyle(color: dimColor, fontSize: 12))),
                    const SizedBox(height: 30),
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

  Widget _SectionLabel(String text, bool isDark) => Text(text, style: TextStyle(color: AppTheme.getTextDim(isDark), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2));

  void _showLanguageSheet(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              ...LocaleProvider.supportedLocales.map((locale) {
                final code = locale.languageCode;
                final isSelected = localeProvider.locale.languageCode == code;
                return ListTile(
                  leading: Text(LocaleProvider.localeFlags[code] ?? '', style: const TextStyle(fontSize: 24)),
                  title: Text(LocaleProvider.localeNames[code] ?? code, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(isDark))),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.accent) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : null,
                  onTap: () { localeProvider.setLocale(locale); Navigator.pop(ctx); },
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, User user) async {
    final ImagePicker picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final XFile? image = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCard(isDark),
        title: const Text("Select Profile Photo"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt, color: AppTheme.accent), title: const Text("Camera"),
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.camera, imageQuality: 70))),
          ListTile(leading: const Icon(Icons.photo_library, color: AppTheme.accent), title: const Text("Gallery"),
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.gallery, imageQuality: 70))),
        ]),
      ),
    );
    if (image == null) return;
    setState(() => isUploading = true);
    try {
      final File file = File(image.path);
      final TaskSnapshot uploadTask = await FirebaseStorage.instance.ref('users/${user.uid}/profile_pic.jpg').putFile(file);
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

  void _openEditNameSheet(BuildContext context, User user) {
    final nameCtrl = TextEditingController(text: user.displayName ?? "");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Edit Name", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Full Name", prefixIcon: const Icon(Icons.person, color: AppTheme.accent))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              await user.updateDisplayName(nameCtrl.text.trim());
              await FirebaseFirestore.instance.collection("users").doc(user.uid).update({"fullName": nameCtrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  void _openEditContactSheet(BuildContext context, {required DocumentReference userDocRef, required String currentPhone}) {
    final phoneCtrl = TextEditingController(text: currentPhone == "—" ? "" : currentPhone);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Update Phone", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: "Phone Number", prefixIcon: const Icon(Icons.phone, color: AppTheme.accent))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              await userDocRef.set({"phone": phoneCtrl.text.trim()}, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  void _openEditEmailSheet(BuildContext context, {required User user, required DocumentReference userDocRef}) {
    final emailCtrl = TextEditingController(text: user.email ?? "");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppTheme.getCard(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Update Email", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: "Email Address", prefixIcon: const Icon(Icons.email, color: AppTheme.accent))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              try {
                await user.verifyBeforeUpdateEmail(emailCtrl.text.trim());
                await userDocRef.set({"email": emailCtrl.text.trim()}, SetOptions(merge: true));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification sent to new email!")));
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
              }
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          )),
        ]),
      ),
    );
  }
}

class _StatStream extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String label;
  const _StatStream({required this.stream, required this.label});
  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.getTextPrimary(Theme.of(context).brightness == Brightness.dark);
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) => Column(children: [
        Text("${snap.data?.docs.length ?? 0}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accent)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppTheme.getTextDim(Theme.of(context).brightness == Brightness.dark), fontSize: 12)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onEdit;
  final Color textColor, dimColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.onEdit, required this.textColor, required this.dimColor});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.accent, size: 20),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: dimColor, fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor)),
      ])),
      if (onEdit != null) IconButton(onPressed: onEdit, icon: Icon(Icons.edit_square, size: 18, color: dimColor)),
    ]);
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final Color textColor, dimColor;
  final bool isLast;
  const _SettingRow({required this.title, required this.icon, this.onTap, this.trailing, this.color, this.isLast = false, required this.textColor, required this.dimColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color ?? dimColor, size: 22),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? textColor)),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white10 : Colors.grey.shade300),
      ),
      if (!isLast) Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
    ]);
  }
}