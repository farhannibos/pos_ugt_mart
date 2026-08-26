import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../widgets/ugt_widgets.dart';
import 'transaction_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String initialFilterStatus;
  const HistoryScreen({super.key, this.initialFilterStatus = 'Semua'});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Filter state — independen, bisa dikombinasi
  late String _filterStatus;  // Semua / Lunas / Piutang
  String _filterMetode  = 'Semua'; // Semua / Tunai / Non-Tunai
  String _filterTanggal = 'Semua'; // Semua / Hari ini / Kemarin / Pilih
  DateTime? _tanggalPilih;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilterStatus;
  }

  // ── Helpers ──────────────────────────────────────────────────
  static const _bulan = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')} ${_bulan[dt.month-1]} ${dt.year}';

  // Parse 2 format: ISO '2026-08-19' atau Indonesia '19 Agu 2026'
  DateTime? _parseTanggal(String tanggal) {
    if (tanggal.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(tanggal)) {
      return DateTime.tryParse(tanggal);
    }
    final parts = tanggal.split(' ');
    if (parts.length == 3) {
      final day   = int.tryParse(parts[0]);
      final month = _bulan.indexOf(parts[1]) + 1;
      final year  = int.tryParse(parts[2]);
      if (day != null && month > 0 && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  bool _isSameDay(String tanggal, DateTime dt) {
    final parsed = _parseTanggal(tanggal);
    if (parsed == null) return false;
    return parsed.year == dt.year && parsed.month == dt.month && parsed.day == dt.day;
  }

  int get _activeFilterCount {
    int n = 0;
    if (_filterStatus  != 'Semua') n++;
    if (_filterMetode  != 'Semua') n++;
    if (_filterTanggal != 'Semua') n++;
    return n;
  }

  bool get _allDefault => _activeFilterCount == 0;

  void _resetFilters() => setState(() {
    _filterStatus  = 'Semua';
    _filterMetode  = 'Semua';
    _filterTanggal = 'Semua';
    _tanggalPilih  = null;
  });

  // ── Filtered list ─────────────────────────────────────────────
  List<Transaction> get _filtered {
    final now = DateTime.now();
    return dummyHistory.where((h) {
      // status
      if (_filterStatus != 'Semua' && h.status != _filterStatus) return false;
      // metode
      if (_filterMetode == 'Tunai'     && h.metode != 'Tunai')  return false;
      if (_filterMetode == 'Non-Tunai' && h.metode == 'Tunai')  return false;
      // tanggal
      if (_filterTanggal == 'Hari ini') {
        if (!_isSameDay(h.tanggal, now)) return false;
      } else if (_filterTanggal == 'Kemarin') {
        if (!_isSameDay(h.tanggal, now.subtract(const Duration(days: 1)))) return false;
      } else if (_filterTanggal == 'Pilih' && _tanggalPilih != null) {
        if (!_isSameDay(h.tanggal, _tanggalPilih!)) return false;
      }
      return true;
    }).toList();
  }

  // ── Label ringkas untuk summary card ─────────────────────────
  String get _summaryLabel {
    final parts = <String>[];
    if (_filterTanggal == 'Hari ini') parts.add('hari ini');
    if (_filterTanggal == 'Kemarin')  parts.add('kemarin');
    if (_filterTanggal == 'Pilih' && _tanggalPilih != null) parts.add(_fmt(_tanggalPilih!));
    if (_filterStatus  != 'Semua')    parts.add(_filterStatus.toLowerCase());
    if (_filterMetode  != 'Semua')    parts.add(_filterMetode.toLowerCase());
    return parts.isEmpty ? 'semua' : parts.join(' · ');
  }

  // ── Bottom sheet filter lengkap ───────────────────────────────
  void _showFilterSheet() {
    // state lokal sheet — apply hanya saat tekan Terapkan
    String tmpStatus  = _filterStatus;
    String tmpMetode  = _filterMetode;
    String tmpTanggal = _filterTanggal;
    DateTime? tmpPilih = _tanggalPilih;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Filter Transaksi',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setSheet(() {
                          tmpStatus  = 'Semua';
                          tmpMetode  = 'Semua';
                          tmpTanggal = 'Semua';
                          tmpPilih   = null;
                        });
                      },
                      child: Text('Reset', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.red, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Tanggal ──
                _SheetLabel('Tanggal'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['Semua', 'Hari ini', 'Kemarin', 'Pilih tanggal'].map((opt) {
                    final key = opt == 'Pilih tanggal' ? 'Pilih' : opt;
                    final active = tmpTanggal == key;
                    final label = (key == 'Pilih' && tmpPilih != null)
                        ? _fmt(tmpPilih!)
                        : opt;
                    return GestureDetector(
                      onTap: () async {
                        if (opt == 'Pilih tanggal') {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tmpPilih ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            builder: (c, child) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppColors.primary),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setSheet(() { tmpPilih = picked; tmpTanggal = 'Pilih'; });
                        } else {
                          setSheet(() => tmpTanggal = key);
                        }
                      },
                      child: _FilterChipWidget(label: label, active: active),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Metode Bayar ──
                _SheetLabel('Metode Bayar'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Semua', 'Tunai', 'Non-Tunai'].map((opt) =>
                    GestureDetector(
                      onTap: () => setSheet(() => tmpMetode = opt),
                      child: _FilterChipWidget(label: opt, active: tmpMetode == opt),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 20),

                // ── Status ──
                _SheetLabel('Status'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Semua', 'Lunas', 'Piutang'].map((opt) =>
                    GestureDetector(
                      onTap: () => setSheet(() => tmpStatus = opt),
                      child: _FilterChipWidget(label: opt, active: tmpStatus == opt),
                    ),
                  ).toList(),
                ),

                const SizedBox(height: 24),

                // ── Terapkan ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _filterStatus  = tmpStatus;
                          _filterMetode  = tmpMetode;
                          _filterTanggal = tmpTanggal;
                          _tanggalPilih  = tmpPilih;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Center(
                        child: Text('Terapkan',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final history  = _filtered;
    final isWide   = MediaQuery.of(context).size.width > 600;
    final totalVal = history.where((h) => h.status == 'Lunas').fold(0, (s, h) => s + h.total);
    final n        = _activeFilterCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Filter button
                    Row(
                      children: [
                        Text('Riwayat Penjualan',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showFilterSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: n > 0 ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: n > 0 ? AppColors.primary : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 14,
                                    color: n > 0 ? Colors.white : AppColors.textMuted),
                                const SizedBox(width: 5),
                                Text(
                                  n > 0 ? 'Filter ($n)' : 'Filter',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: n > 0 ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick chips — sisanya (Lunas/Piutang/Tunai/Non-Tunai)
                    // sudah lengkap di sheet Filter, tidak perlu diduplikasi di sini.
                    Row(
                      children: [
                        // Semua — reset semua filter
                        _QuickChip(
                          label: 'Semua',
                          active: _allDefault,
                          onTap: _resetFilters,
                        ),
                        const SizedBox(width: 8),
                        // Hari ini
                        _QuickChip(
                          label: 'Hari ini',
                          active: _filterTanggal == 'Hari ini',
                          onTap: () => setState(() {
                            _filterTanggal = _filterTanggal == 'Hari ini' ? 'Semua' : 'Hari ini';
                            _tanggalPilih  = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── List ──
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 720.0 : double.infinity),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<AppProvider>().refreshData(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 24 : 104),
                    children: [
                      // Summary card
                      UGTCard(
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total lunas · $_summaryLabel',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                                const SizedBox(height: 2),
                                Text(formatRp(totalVal),
                                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Transaksi', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                                const SizedBox(height: 2),
                                Text('${history.length}',
                                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (history.isEmpty)
                        _EmptyFilter(onReset: _resetFilters)
                      else
                        ...history.map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryCard(
                            trx: h,
                            onTap: () {
                              context.read<AppProvider>().selectedTransaction = h;
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TransactionDetailScreen()),
                              );
                            },
                          ),
                        )),
                    ],
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

// ── Quick chip ─────────────────────────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Filter chip di sheet ───────────────────────────────────────────────────────
class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool active;

  const _FilterChipWidget({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primaryDark : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Section label di sheet ─────────────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 0.3));
  }
}

// ── Empty state saat filter tidak ada hasil ────────────────────────────────────
class _EmptyFilter extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyFilter({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 42, color: AppColors.textDim),
          const SizedBox(height: 10),
          Text('Tidak ada transaksi',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Coba ubah atau reset filter',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Reset Filter',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History card ───────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final Transaction trx;
  final VoidCallback onTap;

  const _HistoryCard({required this.trx, required this.onTap});

  String get _shortId => '#${trx.id.split('-').last}';

  IconData get _icon {
    if (trx.metode == 'QRIS') return Icons.qr_code_2;
    if (trx.metode.contains('EDC') || trx.metode.contains('Kartu')) return Icons.credit_card;
    if (trx.metode == 'Voucher') return Icons.confirmation_number_outlined;
    return Icons.payments_outlined;
  }

  bool get _isWarning => trx.status == 'Piutang' || trx.status == 'Pending';
  Color get _iconBg  => _isWarning ? AppColors.yellowLight  : AppColors.primaryLight;
  Color get _iconFg  => _isWarning ? AppColors.yellowText   : AppColors.primary;
  Color get _badgeBg => _isWarning ? AppColors.yellowLight  : AppColors.primaryLight;
  Color get _badgeFg => _isWarning ? AppColors.yellowText   : AppColors.primaryDark;

  int? get _umurHutang {
    if (trx.status != 'Piutang') return null;
    DateTime? dt;
    final t = trx.tanggal;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
      dt = DateTime.tryParse(t);
    } else {
      const bulan = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      final parts = t.split(' ');
      if (parts.length == 3) {
        final m = bulan.indexOf(parts[1]) + 1;
        if (m > 0) dt = DateTime.tryParse('${parts[2]}-${m.toString().padLeft(2,'0')}-${parts[0].padLeft(2,'0')}');
      }
    }
    if (dt == null) return null;
    return DateTime.now().difference(dt).inDays;
  }

  Color _umurBg(int hari) {
    if (hari > 30) return const Color(0xFFFFE4E6); // merah muda
    if (hari > 7)  return const Color(0xFFFEF3C7); // kuning muda
    return const Color(0xFFDCFCE7);                 // hijau muda
  }

  Color _umurFg(int hari) {
    if (hari > 30) return const Color(0xFFDC2626); // merah
    if (hari > 7)  return const Color(0xFFB45309); // kuning tua
    return const Color(0xFF16A34A);                 // hijau
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, size: 18, color: _iconFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_shortId,
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: _badgeBg, borderRadius: BorderRadius.circular(100)),
                          child: Text(trx.status,
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: _badgeFg)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trx.jam}  ·  ${trx.items} item  ·  ${trx.metode}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_umurHutang != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 11, color: _umurFg(_umurHutang!)),
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _umurBg(_umurHutang!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _umurHutang == 0 ? 'Hari ini' : 'Sudah $_umurHutang hari',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _umurFg(_umurHutang!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatRp(trx.total),
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _isWarning ? AppColors.yellow : AppColors.text,
                      )),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.textDim),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
