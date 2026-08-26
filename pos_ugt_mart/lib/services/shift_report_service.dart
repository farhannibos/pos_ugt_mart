import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/ugt_widgets.dart';

class ShiftReportData {
  final String storeName;
  final String alamat;
  final String kasir;
  final String tanggal;
  final String jamBuka;
  final String jamTutup;
  final int modalAwal;
  final int omzet;
  final int piutang;
  final int nonTunai;
  final int kasMasukLain;
  final int kasKeluarLain;
  final int pembelianTunai;
  final int totalKasKasir;
  final int jumlahTransaksi;
  final int jumlahItem;

  const ShiftReportData({
    required this.storeName,
    required this.alamat,
    required this.kasir,
    required this.tanggal,
    required this.jamBuka,
    required this.jamTutup,
    required this.modalAwal,
    required this.omzet,
    required this.piutang,
    required this.nonTunai,
    required this.kasMasukLain,
    required this.kasKeluarLain,
    required this.pembelianTunai,
    required this.totalKasKasir,
    required this.jumlahTransaksi,
    required this.jumlahItem,
  });
}

// Laporan tutup shift ditujukan untuk arsip/pertanggungjawaban kasir ke
// pemilik toko — dibuat sebagai dokumen A4 formal (tabel, kop, tanda tangan),
// BUKAN struk kasir 58mm. Karena itu jalur cetak selalu lewat dialog print
// sistem (PDF), tidak lewat printer thermal Bluetooth yang dipakai untuk
// struk transaksi di ReceiptService.
class ShiftReportService {
  static const _brand = PdfColor.fromInt(0xFF00A53D);
  static const _red   = PdfColor.fromInt(0xFFDC2626);
  static const _gray  = PdfColor.fromInt(0xFF6B7280);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);

  static Future<void> printReport(ShiftReportData data) async {
    final pdf = await _buildPdf(data);
    await Printing.layoutPdf(onLayout: (_) => pdf, name: 'Laporan Tutup Shift');
  }

  static Future<void> shareReport(ShiftReportData data) async {
    final bytes = await _buildPdf(data);
    final fileSafeJam = data.jamBuka.replaceAll(':', '');
    await Printing.sharePdf(bytes: bytes, filename: 'laporan-tutup-shift-$fileSafeJam.pdf');
  }

  static Future<Uint8List> _buildPdf(ShiftReportData d) async {
    final doc = pw.Document();

    pw.TextStyle label()  => pw.TextStyle(fontSize: 9.5, color: _gray);
    pw.TextStyle value()  => const pw.TextStyle(fontSize: 9.5);
    pw.TextStyle section() => pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _brand);

    pw.Widget infoRow(String l, String v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 92, child: pw.Text(l, style: label())),
          pw.Text(':  ', style: label()),
          pw.Expanded(child: pw.Text(v, style: value().copyWith(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );

    pw.Widget detailRow(String l, String v, {PdfColor? color, bool isTotal = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: isTotal ? PdfColor.fromInt(0xFFEFFDF4) : null,
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: isTotal ? 0 : 0.6)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(l,
                style: isTotal
                    ? pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)
                    : value()),
          ),
          pw.Text(v,
              style: isTotal
                  ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _brand)
                  : value().copyWith(color: color, fontWeight: color != null ? pw.FontWeight.bold : null)),
        ],
      ),
    );

    pw.TextStyle label2() => pw.TextStyle(fontSize: 9, color: _gray);
    pw.Widget signatureBox(String label) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 48),
          pw.Container(width: 140, height: 0.8, color: _border),
          pw.SizedBox(height: 4),
          pw.Text(label, style: label2()),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Kop laporan ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(d.storeName,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _brand)),
                      if (d.alamat.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(d.alamat, style: pw.TextStyle(fontSize: 9, color: _gray)),
                      ],
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('LAPORAN TUTUP SHIFT',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(d.tanggal, style: pw.TextStyle(fontSize: 9, color: _gray)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Container(height: 2, color: _brand),
            pw.SizedBox(height: 16),

            // ── Info shift ──
            pw.Text('INFORMASI SHIFT', style: section()),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(children: [
                    infoRow('Kasir', d.kasir),
                    infoRow('Jam Buka', d.jamBuka),
                  ]),
                ),
                pw.Expanded(
                  child: pw.Column(children: [
                    infoRow('Jumlah Transaksi', '${d.jumlahTransaksi} transaksi'),
                    infoRow('Jam Tutup', d.jamTutup),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── Rincian keuangan ──
            pw.Text('RINCIAN KEUANGAN', style: section()),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.8)),
              child: pw.Column(
                children: [
                  detailRow('Omzet', formatRp(d.omzet)),
                  detailRow('Kas Terakhir (Modal Awal Shift)', formatRp(d.modalAwal)),
                  detailRow('Kas Masuk Lainnya', '+ ${formatRp(d.kasMasukLain)}', color: _brand),
                  detailRow('Piutang', '- ${formatRp(d.piutang)}', color: _red),
                  detailRow('Nontunai', '- ${formatRp(d.nonTunai)}', color: _red),
                  detailRow('Kas Keluar Lainnya', '- ${formatRp(d.kasKeluarLain)}', color: _red),
                  detailRow('Pembelian Tunai', '- ${formatRp(d.pembelianTunai)}', color: _red),
                  detailRow('KAS KASIR (Saldo Seharusnya)', formatRp(d.totalKasKasir), isTotal: true),
                ],
              ),
            ),
            pw.SizedBox(height: 28),

            // ── Tanda tangan ──
            pw.Row(
              children: [
                signatureBox('Kasir'),
                pw.SizedBox(width: 24),
                signatureBox('Diperiksa Oleh'),
              ],
            ),

            pw.Spacer(),
            pw.Divider(color: _border, height: 1),
            pw.SizedBox(height: 6),
            pw.Text('Dokumen dibuat otomatis oleh sistem FABIZO POS',
                style: pw.TextStyle(fontSize: 7.5, color: _gray)),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }
}
