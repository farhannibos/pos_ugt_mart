import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/member.dart';
import '../widgets/ugt_widgets.dart';
import 'member_detail_screen.dart';
import 'upgrade_screen.dart';

class MemberScreen extends StatefulWidget {
  final bool selectMode;
  const MemberScreen({super.key, this.selectMode = false});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Member> get _filtered {
    final q = _query.toLowerCase();
    return dummyMembers.where((m) =>
      m.nama.toLowerCase().contains(q) || m.hp.contains(q)
    ).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showMemberLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Batas Member Tercapai', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Plan Free maksimal ${AppProvider.freeMemberLimit} member. Upgrade ke Premium untuk menambah member tanpa batas.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Nanti Dulu', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
            },
            child: Text('Upgrade', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    if (context.read<AppProvider>().memberLimitReached) {
      _showMemberLimitDialog(context);
      return;
    }
    final namaCtrl = TextEditingController();
    final hpCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // fixed header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tambah Member Baru',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 3),
                            Text('Daftarkan pelanggan sebagai member',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textDim),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bg,
                          shape: const CircleBorder(),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      ),
                    ],
                  ),
                ),
                // scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _fieldLabel('Nama Member'),
                          TextFormField(
                            controller: namaCtrl,
                            textCapitalization: TextCapitalization.words,
                            autofocus: true,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('Contoh: Budi Santoso'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('No. HP / WhatsApp'),
                          TextFormField(
                            controller: hpCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('08xxxxxxxxxx'),
                            validator: (v) => (v == null || v.trim().length < 9) ? 'No. HP tidak valid' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: loading ? null : () async {
                                  if (!(formKey.currentState?.validate() ?? false)) return;
                                  final prov = ctx.read<AppProvider>();
                                  final nama = namaCtrl.text.trim();
                                  final hp = hpCtrl.text.trim();
                                  setSheet(() => loading = true);
                                  final ok = await prov.addMember(nama, hp);
                                  if (!ctx.mounted) return;
                                  if (ok) {
                                    Navigator.of(ctx).pop();
                                  } else {
                                    setSheet(() => loading = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          prov.lastError.isEmpty
                                            ? 'Gagal menyimpan member'
                                            : 'Gagal: ${prov.lastError}',
                                        ),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Center(
                                  child: loading
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text('Simpan Member',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final members = _filtered;
    final isWide = MediaQuery.of(context).size.width > 600;
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (widget.selectMode)
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chevron_left, size: 24),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        Expanded(
                          child: Text(
                            'Member',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                          ),
                        ),
                        if (!prov.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: prov.memberLimitReached ? AppColors.redBg : AppColors.bg,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: prov.memberLimitReached ? AppColors.redBorder : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '${dummyMembers.length}/${AppProvider.freeMemberLimit} member',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: prov.memberLimitReached ? AppColors.red : AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Image.asset('assets/icons/ic_search.png', width: 22, fit: BoxFit.contain),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v),
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Cari nama atau nomor HP',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 720.0 : double.infinity),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<AppProvider>().refreshData(),
                  child: isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 4.2,
                        ),
                        itemCount: members.length,
                        itemBuilder: (_, i) => _MemberCard(
                          member: members[i],
                          onTap: () {
                            if (widget.selectMode) {
                              context.read<AppProvider>().useMemberForTransaction(members[i]);
                              Navigator.of(context).pop();
                            } else {
                              context.read<AppProvider>().selectMember(members[i]);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MemberDetailScreen()),
                              );
                            }
                          },
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MemberCard(
                          member: members[i],
                          onTap: () {
                            if (widget.selectMode) {
                              context.read<AppProvider>().useMemberForTransaction(members[i]);
                              Navigator.of(context).pop();
                            } else {
                              context.read<AppProvider>().selectMember(members[i]);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MemberDetailScreen()),
                              );
                            }
                          },
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Member', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              InitialsAvatar(
                text: member.initials,
                size: 44,
                fontSize: 14,
                borderRadius: 14,
                bgColor: AppColors.primaryLight,
                textColor: AppColors.primaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.nama, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(
                      '${member.hp} · ${member.tier}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    member.poin.toLocaleString(),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  Text('poin', style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.textDim)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension IntExt on int {
  String toLocaleString() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}

Widget _fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
);

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
  filled: true,
  fillColor: AppColors.bg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.red)),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
);
