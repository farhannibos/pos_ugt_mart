import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/member.dart';
import '../widgets/ugt_widgets.dart';
import 'member_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final members = _filtered;
    final isWide = MediaQuery.of(context).size.width > 600;

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
