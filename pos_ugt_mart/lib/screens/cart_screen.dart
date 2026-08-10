import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 640.0 : double.infinity),
          child: Column(
        children: [
          // AppBar
          _CartAppBar(
            count: prov.cartItemCount,
            onBack: () => Navigator.of(context).pop(),
            onClear: () {
              prov.clearCart();
              Navigator.of(context).pop();
            },
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
                        icon: Icons.person_outline,
                        label: 'Pelanggan',
                        value: prov.selectedCustomer ?? 'Umum',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MemberScreen(selectMode: true)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.sell_outlined,
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
                else
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CartItem(
                      cartItem: item,
                      onInc: () => prov.incrementCart(item.productId),
                      onDec: () => prov.decrementCart(item.productId),
                    ),
                  )),
                // Note field
                const SizedBox(height: 2),
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
          // Bottom summary
          _CartSummary(prov: prov),
        ],
          ),
        ),
      ),
    );
  }
}

class _CartAppBar extends StatelessWidget {
  final int count;
  final VoidCallback onBack;
  final VoidCallback onClear;

  const _CartAppBar({required this.count, required this.onBack, required this.onClear});

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
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red),
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoChip({required this.icon, required this.label, required this.value, required this.onTap});

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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: AppColors.primary),
              ),
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

  const _CartItem({required this.cartItem, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    final produk = dummyProducts.firstWhere(
      (p) => p.id == cartItem.productId,
      orElse: () => Product(id: '', nama: '', kategori: '', harga: 0, stok: 0, barcode: ''),
    );
    return UGTCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          InitialsAvatar(text: cartItem.initials, size: 50, fontSize: 14, borderRadius: 13),
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
                  '${formatRp(cartItem.harga)} / ${produk.satuan}',
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
          QtyControl(qty: cartItem.qty, onInc: onInc, onDec: onDec),
        ],
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.grayLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 24, color: AppColors.placeholder),
          ),
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
              _SummaryRow(label: 'PPN 11%', value: formatRp(prov.taxValue)),
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

