import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 26, color: AppColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Pengaturan Aplikasi',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [

                // ── TRANSAKSI ──
                _SectionLabel('Transaksi'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _ToggleItem(
                    icon: Icons.tune_rounded,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    title: 'Pembulatan Harga',
                    subtitle: 'Bulatkan total ke Rp100 terdekat (ke atas)',
                    value: prov.roundUpEnabled,
                    onChanged: (v) => context.read<AppProvider>().setRoundUp(v),
                    showBorder: false,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── INFORMASI TOKO ──
                _SectionLabel('Informasi Toko'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _EditableItem(
                    icon: Icons.store_outlined,
                    iconBg: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    title: 'Nama Toko',
                    value: prov.storeName,
                    showBorder: true,
                    onEdit: () => _showEditSheet(
                      context,
                      label: 'Nama Toko',
                      currentValue: prov.storeName,
                      hint: 'Contoh: FABIZO',
                      onSave: (v) => context.read<AppProvider>().setStoreName(v),
                    ),
                  ),
                  _EditableItem(
                    icon: Icons.computer_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Nama Terminal',
                    value: prov.terminalName,
                    showBorder: true,
                    onEdit: () => _showEditSheet(
                      context,
                      label: 'Nama Terminal',
                      currentValue: prov.terminalName,
                      hint: 'Contoh: Terminal Kasir 01',
                      onSave: (v) => context.read<AppProvider>().setTerminalName(v),
                    ),
                  ),
                  _EditableItem(
                    icon: Icons.location_on_outlined,
                    iconBg: const Color(0xFFFFF1F2),
                    iconColor: const Color(0xFFF43F5E),
                    title: 'Alamat Toko',
                    value: prov.alamatToko,
                    showBorder: false,
                    onEdit: () => _showEditSheet(
                      context,
                      label: 'Alamat Toko',
                      currentValue: prov.alamatToko,
                      hint: 'Masukkan alamat toko',
                      maxLines: 2,
                      onSave: (v) => context.read<AppProvider>().setAlamatToko(v),
                    ),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── TENTANG ──
                _SectionLabel('Tentang'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _InfoItem(
                    icon: Icons.apps_rounded,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Versi Aplikasi',
                    value: 'v2.4.0',
                    showBorder: true,
                  ),
                  _InfoItem(
                    icon: Icons.business_outlined,
                    iconBg: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    title: 'Dibuat oleh',
                    value: 'FABIZO Dev Team',
                    showBorder: false,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(
    BuildContext context, {
    required String label,
    required String currentValue,
    required String hint,
    required void Function(String) onSave,
    int maxLines = 1,
  }) {
    final ctrl = TextEditingController(text: currentValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Edit $label',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: maxLines,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      onSave(ctrl.text);
                      Navigator.of(ctx).pop();
                    },
                    child: Center(
                      child: Text('Simpan',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim, letterSpacing: 0.8),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: children),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBorder;

  const _ToggleItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: AppColors.borderLight)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _EditableItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final bool showBorder;
  final VoidCallback onEdit;

  const _EditableItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.showBorder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: showBorder ? const Border(bottom: BorderSide(color: AppColors.borderLight)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 15, color: AppColors.placeholder),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final bool showBorder;

  const _InfoItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.showBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: AppColors.borderLight)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
          Text(value, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
