import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../widgets/ugt_widgets.dart';
import 'member_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _showHapusSheet(BuildContext context, AppProvider prov) {
    final items = prov.cart.values.toList();
    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final allSelected = selected.length == items.length;

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
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Hapus Item',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setSheet(() {
                        if (allSelected) {
                          selected.clear();
                        } else {
                          selected.addAll(items.map((i) => i.productId));
                        }
                      }),
                      child: Text(
                        allSelected ? 'Batal Semua' : 'Pilih Semua',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final id = item.productId;
                  final isChecked = selected.contains(id);
                  return GestureDetector(
                    onTap: () => setSheet(() {
                      isChecked ? selected.remove(id) : selected.add(id);
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isChecked ? AppColors.redLight : AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isChecked ? AppColors.redBorder : AppColors.border,
                          width: isChecked ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: isChecked ? AppColors.red : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isChecked ? AppColors.red : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.nama,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  '${formatQty(item.qty, item.satuan)} × ${formatRp(item.harga)}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                                ),
                              ],
                            ),
                          ),
                          Text(formatRp(item.subtotal),
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700,
                                  color: isChecked ? AppColors.red : AppColors.text)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Material(
                    color: selected.isEmpty ? AppColors.grayMid : AppColors.red,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: selected.isEmpty ? null : () {
                        for (final id in selected) {
                          prov.removeFromCart(id);
                        }
                        Navigator.pop(ctx);
                        if (prov.cart.isEmpty) {
                          Navigator.of(context).pop('goto_products');
                        }
                      },
                      child: Center(
                        child: Text(
                          selected.isEmpty
                              ? 'Pilih item yang ingin dihapus'
                              : 'Hapus ${selected.length} Item',
                          style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: selected.isEmpty ? AppColors.textDim : Colors.white,
                          ),
                        ),
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

  void _showPelangganSheet(BuildContext context, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pilih Pelanggan',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 16),
            // Opsi Umum
            _PelangganOption(
              icon: Icons.person_outline,
              label: 'Umum',
              sub: 'Tanpa data pelanggan',
              active: prov.selectedCustomer == null,
              onTap: () {
                prov.clearSelectedCustomer();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),
            // Opsi Cari Member
            _PelangganOption(
              icon: Icons.badge_outlined,
              label: 'Pilih Member',
              sub: prov.selectedCustomer ?? 'Cari dari daftar member',
              active: prov.selectedCustomer != null,
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MemberScreen(selectMode: true)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, AppProvider prov) {
    final ctrl = TextEditingController(
      text: prov.discount > 0 ? prov.discount.toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Diskon', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            prefixText: 'Rp  ',
            prefixStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDim),
            hintText: '0',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              prov.setDiscount(0);
              Navigator.of(ctx).pop();
            },
            child: Text('Hapus', style: GoogleFonts.inter(fontSize: 13, color: AppColors.red)),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(ctrl.text) ?? 0;
              prov.setDiscount(amount);
              Navigator.of(ctx).pop();
            },
            child: Text('Terapkan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final items = prov.cart.values.toList();
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 640.0 : double.infinity),
                child: Column(
                  children: [
          // AppBar
          _CartAppBar(
            count: prov.cartItemCount,
            onBack: () => Navigator.of(context).pop(),
            onAddProduct: () => Navigator.of(context).pop('goto_products'),
            onClear: items.isEmpty ? null : () => _showHapusSheet(context, prov),
          ),
                    // Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                // Customer & Discount row
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        asset: 'assets/icons/ic_member.png',
                        label: 'Pelanggan',
                        value: prov.selectedCustomer ?? 'Umum',
                        showArrow: true,
                        onTap: () => _showPelangganSheet(context, prov),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoChip(
                        asset: 'assets/icons/ic_diskon.png',
                        label: 'Diskon',
                        value: prov.discount > 0 ? formatRp(prov.discount) : 'Tambah',
                        onTap: () => _showDiscountDialog(context, prov),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Cart items
                if (items.isEmpty)
                  _EmptyCart(onGoProduct: () => Navigator.of(context).pop('goto_products'))
                else ...[
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CartItem(
                      cartItem: item,
                      onInc: () => prov.incrementCart(item.productId),
                      onDec: () => prov.decrementCart(item.productId),
                      onDelete: () => prov.removeFromCart(item.productId),
                    ),
                  )),
                ],
                // Note field
                const SizedBox(height: 10),
                UGTCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text(
                            'Catatan Transaksi',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteCtrl,
                        onChanged: (v) => prov.note = v,
                        style: GoogleFonts.inter(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'mis. minta kantong terpisah',
                          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textDim),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ],
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
          _CartSummary(prov: prov),
        ],
      ),
    );
  }
}

class _CartAppBar extends StatelessWidget {
  final int count;
  final VoidCallback onBack;
  final VoidCallback onAddProduct;
  final VoidCallback? onClear;

  const _CartAppBar({
    required this.count,
    required this.onBack,
    required this.onAddProduct,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 24, color: AppColors.text),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'Keranjang · $count item',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
              Tooltip(
                message: 'Tambah Produk',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddProduct,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.primaryMid, width: 0.8),
                      ),
                      child: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                    ),
                  ),
                ),
              ),
              if (onClear != null)
                PopupMenuButton<void>(
                  tooltip: 'Opsi lainnya',
                  padding: EdgeInsets.zero,
                  splashRadius: 15,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: const Icon(Icons.more_vert, size: 25, color: AppColors.textMuted),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      onTap: onClear,
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep_outlined, size: 17, color: AppColors.red),
                          const SizedBox(width: 10),
                          Text(
                            'Kosongkan Keranjang',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(width: 8),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String? asset;
  final String label;
  final String value;
  final bool showArrow;
  final VoidCallback onTap;

  const _InfoChip({this.asset, required this.label, required this.value, this.showArrow = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
              Image.asset(asset ?? 'assets/icons/ic_diskon.png', width: 28, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.textDim, letterSpacing: 0.5),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final dynamic cartItem;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onDelete;

  const _CartItem({required this.cartItem, required this.onInc, required this.onDec, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final produk = dummyProducts.firstWhere(
      (p) => p.id == cartItem.productId,
      orElse: () => Product(id: '', nama: '', kategori: '', harga: 0, stok: 0, barcode: ''),
    );
    final isBulk = cartItem.isBulk as bool;
    return Slidable(
      key: ValueKey(cartItem.productId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(18),
          ),
        ],
      ),
      child: UGTCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ProductThumb(fotoUrl: produk.fotoUrl, initials: cartItem.initials as String),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.nama,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatRp(cartItem.harga)} / ${cartItem.satuan}',
                    style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRp(cartItem.subtotal),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            if (isBulk)
              GestureDetector(
                onTap: () async {
                  final prov = context.read<AppProvider>();
                  final qty = await showBulkInputDialog(
                    context, produk, initial: cartItem.qty as double);
                  if (qty != null) prov.setBulkQty(cartItem.productId as String, qty);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.primaryMid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatQty(cartItem.qty as double, cartItem.satuan as String),
                        style: GoogleFonts.inter(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.edit_outlined, size: 13, color: AppColors.primaryDark),
                    ],
                  ),
                ),
              )
            else
              QtyControl(qty: (cartItem.qty as double).round(), onInc: onInc, onDec: onDec),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? fotoUrl;
  final String initials;

  const _ProductThumb({required this.fotoUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.network(
          fotoUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              InitialsAvatar(text: initials, size: 50, fontSize: 14, borderRadius: 13),
        ),
      );
    }
    return InitialsAvatar(text: initials, size: 50, fontSize: 14, borderRadius: 13);
  }
}

class _PelangganOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;

  const _PelangganOption({
    required this.icon,
    required this.label,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: active ? Colors.white : AppColors.textDim),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: active ? AppColors.primaryDark : AppColors.text)),
                  Text(sub,
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onGoProduct;
  const _EmptyCart({required this.onGoProduct});

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
      child: Column(
        children: [
          Image.asset('assets/icons/ic_cart.png', width: 72, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text('Keranjang kosong', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(
            'Tambahkan produk untuk mulai transaksi',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onGoProduct,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pilih Produk',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final AppProvider prov;
  const _CartSummary({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _SummaryRow(label: 'Subtotal', value: formatRp(prov.subtotal)),
            const SizedBox(height: 5),
            _SummaryRow(
              label: 'Diskon',
              value: '- ${formatRp(prov.discount)}',
              valueColor: AppColors.red,
            ),
            if (prov.taxEnabled) ...[
              const SizedBox(height: 5),
              _SummaryRow(
                label: 'PPN ${prov.taxRate % 1 == 0 ? prov.taxRate.toInt() : prov.taxRate}%',
                value: formatRp(prov.taxValue),
              ),
            ],
            if (prov.roundUpEnabled) ...[
              const SizedBox(height: 5),
              _SummaryRow(label: 'Pembulatan', value: formatRp(prov.roundUpValue)),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: DashedDivider(),
            ),
            Row(
              children: [
                Text(
                  'Total Pembayaran',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                const Spacer(),
                Text(
                  formatRp(prov.total),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: prov.hasCart
                      ? () => Navigator.of(context).pushNamed('/payment')
                      : null,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.credit_card, color: Colors.white, size: 17),
                        const SizedBox(width: 9),
                        Text(
                          'Bayar Sekarang',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({required this.label, required this.value, this.valueColor = AppColors.textMuted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 12, color: valueColor)),
      ],
    );
  }
}

