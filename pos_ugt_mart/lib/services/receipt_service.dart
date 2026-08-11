import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';
import '../widgets/ugt_widgets.dart';
import 'printer_service.dart';

class ReceiptService {
  /// Cetak struk: coba Bluetooth ESC/POS dulu, fallback ke PDF dialog.
  static Future<void> printReceipt({
    required Transaction trx,
    required Map<String, dynamic> meta,
  }) async {
    final (address, _) = await PrinterService.getSelectedPrinter();
    if (address != null) {
      final bytes = await _buildEscPos(trx, meta);
      final ok = await PrinterService.writeBytes(bytes);
      if (ok) return;
    }
    final pdf = await _buildPdf(trx, meta);
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  /// Bagikan struk sebagai PDF.
  static Future<void> shareReceipt({
    required Transaction trx,
    required Map<String, dynamic> meta,
  }) async {
    final bytes = await _buildPdf(trx, meta);
    await Printing.sharePdf(bytes: bytes, filename: '${trx.id}.pdf');
  }

  /// Persingkat tanggal+jam: "06 Agu 2026" + "10:30" → "06/08/26 10:30"
  static String _shortDateTime(String tanggal, String jam) {
    const bulan = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'Mei': '05', 'Jun': '06', 'Jul': '07', 'Agu': '08',
      'Sep': '09', 'Okt': '10', 'Nov': '11', 'Des': '12',
    };
    final parts = tanggal.split(' ');
    if (parts.length == 3) {
      final day = parts[0];
      final mon = bulan[parts[1]] ?? parts[1];
      final yr  = parts[2].length >= 2 ? parts[2].substring(2) : parts[2];
      return '$day/$mon/$yr $jam';
    }
    return '$tanggal $jam';
  }

  /// Persingkat no transaksi: "TRX-20260806-001" → "260806-001"
  static String _shortId(String id) {
    final parts = id.split('-');
    if (parts.length >= 3) {
      final datePart = parts[parts.length - 2];
      final seqPart  = parts.last;
      final shortDate = datePart.length >= 6
          ? datePart.substring(datePart.length - 6)
          : datePart;
      return '$shortDate-$seqPart';
    }
    return id.length > 12 ? id.substring(id.length - 12) : id;
  }

  // ─── ESC/POS (Bluetooth thermal printer) ─────────────────────────────────

  static Future<List<int>> _buildEscPos(
    Transaction trx,
    Map<String, dynamic> meta,
  ) async {
    final storeName = meta['storeName'] as String? ?? 'FABIZO';
    final alamat    = meta['alamat']    as String? ?? '';
    final kasir     = meta['kasir']     as String? ?? '';
    final subtotal  = meta['subtotal']  as int?    ?? trx.total;
    final discount  = meta['discount']  as int?    ?? 0;
    final taxRate   = meta['taxRate']   as double? ?? 0;
    final taxVal    = meta['taxValue']  as int?    ?? 0;
    final roundUp   = meta['roundUp']   as int?    ?? 0;
    final method    = meta['method']    as String? ?? trx.metode;
    final cash      = meta['cash']      as int?    ?? 0;
    final change    = meta['change']    as int?    ?? 0;
    final customer  = meta['customer']  as String? ?? trx.customer;
    final points    = meta['points']    as int?    ?? 0;

    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // ── Header toko
    bytes += gen.text(
      storeName,
      styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += gen.feed(1);
    if (alamat.isNotEmpty) bytes += gen.text(alamat, styles: PosStyles(align: PosAlign.center));
    bytes += gen.hr();

    // ── Info transaksi: no kode kiri | tanggal jam kanan
    bytes += gen.row([
      PosColumn(text: _shortId(trx.id), width: 5),
      PosColumn(text: _shortDateTime(trx.tanggal, trx.jam), width: 7, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += gen.row([
      PosColumn(text: 'Kasir', width: 4),
      PosColumn(text: kasir, width: 8, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += gen.row([
      PosColumn(text: 'Pelanggan', width: 4),
      PosColumn(text: customer, width: 8, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += gen.hr();

    // ── Item produk
    for (final item in trx.cartItems) {
      bytes += gen.text(item.nama);
      bytes += gen.row([
        PosColumn(text: '  ${item.qty} x ${formatRp(item.harga)}', width: 7),
        PosColumn(text: formatRp(item.subtotal), width: 5, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += gen.hr();

    // ── Ringkasan harga
    bytes += gen.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(text: formatRp(subtotal), width: 6, styles: PosStyles(align: PosAlign.right)),
    ]);
    if (discount > 0) {
      bytes += gen.row([
        PosColumn(text: 'Diskon', width: 6),
        PosColumn(text: '- ${formatRp(discount)}', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    if (taxRate > 0) {
      bytes += gen.row([
        PosColumn(text: 'PPN ${taxRate.toInt()}%', width: 6),
        PosColumn(text: formatRp(taxVal), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    if (roundUp > 0) {
      bytes += gen.row([
        PosColumn(text: 'Pembulatan', width: 6),
        PosColumn(text: formatRp(roundUp), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += gen.hr();

    // ── Total + metode pembayaran langsung di bawah total
    bytes += gen.row([
      PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(bold: true)),
      PosColumn(text: formatRp(trx.total), width: 6, styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);
    if (method == 'Tunai') {
      bytes += gen.row([
        PosColumn(text: 'Tunai', width: 6),
        PosColumn(text: formatRp(cash), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
      bytes += gen.row([
        PosColumn(text: 'Kembalian', width: 6),
        PosColumn(text: formatRp(change), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    } else {
      bytes += gen.row([
        PosColumn(text: method, width: 6),
        PosColumn(text: formatRp(trx.total), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    if (points > 0) {
      bytes += gen.row([
        PosColumn(text: 'Poin', width: 6),
        PosColumn(text: '+$points poin', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += gen.feed(1);

    // ── Footer
    bytes += gen.text('Terima kasih telah berbelanja', styles: PosStyles(align: PosAlign.center));
    bytes += gen.text('di $storeName', styles: PosStyles(align: PosAlign.center));
    bytes += gen.text('Barang yang sudah dibeli', styles: PosStyles(align: PosAlign.center));
    bytes += gen.text('tidak dapat dikembalikan', styles: PosStyles(align: PosAlign.center));
    bytes += gen.feed(3);
    bytes += gen.cut();

    return bytes;
  }

  // ─── PDF (untuk share / fallback) ────────────────────────────────────────

  static Future<Uint8List> _buildPdf(Transaction trx, Map<String, dynamic> meta) async {
    final doc = pw.Document();

    final storeName = meta['storeName'] as String? ?? 'FABIZO';
    final alamat    = meta['alamat']    as String? ?? '';
    final kasir     = meta['kasir']     as String? ?? '';
    final subtotal  = meta['subtotal']  as int?    ?? trx.total;
    final discount  = meta['discount']  as int?    ?? 0;
    final taxRate   = meta['taxRate']   as double? ?? 0;
    final taxVal    = meta['taxValue']  as int?    ?? 0;
    final roundUp   = meta['roundUp']   as int?    ?? 0;
    final method    = meta['method']    as String? ?? trx.metode;
    final cash      = meta['cash']      as int?    ?? 0;
    final change    = meta['change']    as int?    ?? 0;
    final customer  = meta['customer']  as String? ?? trx.customer;
    final points    = meta['points']    as int?    ?? 0;

    const lineW = 58.0;

    pw.TextStyle normal() => const pw.TextStyle(fontSize: 9);
    pw.TextStyle small()  => const pw.TextStyle(fontSize: 8);
    pw.TextStyle bold()   => pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    pw.TextStyle boldLg() => pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

    String dash() => '─' * 32;
    pw.Widget divider() => pw.Text(dash(), style: small());

    pw.Widget row(String l, String r, {bool isBold = false}) => pw.Row(
      children: [
        pw.Expanded(child: pw.Text(l, style: isBold ? bold() : normal())),
        pw.Text(r, style: isBold ? bold() : normal()),
      ],
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(lineW * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header toko (tanpa terminal)
            pw.Text(storeName, style: boldLg(), textAlign: pw.TextAlign.center),
            if (alamat.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(alamat, style: small(), textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 6),
            divider(),
            pw.SizedBox(height: 4),

            // Info transaksi: no kode kiri | tanggal kanan
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(_shortId(trx.id), style: bold()),
                      pw.Spacer(),
                      pw.Text(_shortDateTime(trx.tanggal, trx.jam), style: normal()),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  row('Kasir', kasir),
                  pw.SizedBox(height: 2),
                  row('Pelanggan', customer),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            divider(),
            pw.SizedBox(height: 4),

            // Item produk
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: trx.cartItems.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.nama, style: normal()),
                      pw.Row(
                        children: [
                          pw.Text('  ${item.qty} x ${formatRp(item.harga)}', style: small()),
                          pw.Spacer(),
                          pw.Text(formatRp(item.subtotal), style: normal()),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            pw.SizedBox(height: 4),
            divider(),
            pw.SizedBox(height: 4),

            // Ringkasan harga
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  row('Subtotal', formatRp(subtotal)),
                  if (discount > 0) ...[
                    pw.SizedBox(height: 2),
                    row('Diskon', '- ${formatRp(discount)}'),
                  ],
                  if (taxRate > 0) ...[
                    pw.SizedBox(height: 2),
                    row('PPN ${taxRate % 1 == 0 ? taxRate.toInt() : taxRate}%', formatRp(taxVal)),
                  ],
                  if (roundUp > 0) ...[
                    pw.SizedBox(height: 2),
                    row('Pembulatan', formatRp(roundUp)),
                  ],
                  pw.SizedBox(height: 4),
                  divider(),
                  pw.SizedBox(height: 4),

                  // Total + metode langsung di bawah total
                  row('TOTAL', formatRp(trx.total), isBold: true),
                  pw.SizedBox(height: 2),
                  if (method == 'Tunai') ...[
                    row('Tunai', formatRp(cash)),
                    pw.SizedBox(height: 2),
                    row('Kembalian', formatRp(change)),
                  ] else
                    row(method, formatRp(trx.total)),
                  if (points > 0) ...[
                    pw.SizedBox(height: 2),
                    row('Poin Ditambahkan', '+$points poin'),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            divider(),
            pw.SizedBox(height: 8),

            // Footer
            pw.Text('Terima kasih telah berbelanja', style: small(), textAlign: pw.TextAlign.center),
            pw.Text('di $storeName', style: small(), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text('Barang yang sudah dibeli', style: small(), textAlign: pw.TextAlign.center),
            pw.Text('tidak dapat dikembalikan', style: small(), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }
}
