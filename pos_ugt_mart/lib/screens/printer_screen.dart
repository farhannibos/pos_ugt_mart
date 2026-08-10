import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../theme/app_theme.dart';
import '../services/printer_service.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<BluetoothInfo> _devices = [];
  String? _selectedAddress;
  String? _selectedName;
  bool _scanning = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _scan();
  }

  Future<void> _loadSaved() async {
    final (addr, name) = await PrinterService.getSelectedPrinter();
    if (mounted) setState(() { _selectedAddress = addr; _selectedName = name; });
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final devices = await PrinterService.scanDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (_) {}
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _select(BluetoothInfo device) async {
    await PrinterService.saveSelectedPrinter(device.macAdress, device.name);
    if (!mounted) return;
    setState(() {
      _selectedAddress = device.macAdress;
      _selectedName = device.name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printer "${device.name}" dipilih'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _testPrint() async {
    if (_selectedAddress == null) return;
    setState(() => _testing = true);
    final ok = await PrinterService.testPrint();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Test print berhasil!' : 'Gagal konek ke printer. Pastikan printer menyala & sudah di-pair.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.primary : AppColors.red,
      ),
    );
  }

  Future<void> _clearPrinter() async {
    await PrinterService.clearSelectedPrinter();
    if (!mounted) return;
    setState(() { _selectedAddress = null; _selectedName = null; });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // AppBar
          Container(
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Printer Struk',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Scan ulang',
                      icon: _scanning
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                      onPressed: _scanning ? null : _scan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 600.0 : double.infinity),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Printer aktif
                    if (_selectedAddress != null) ...[
                      Text(
                        'PRINTER AKTIF',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryMid),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.print, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedName ?? '-',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                                  ),
                                  Text(
                                    _selectedAddress!,
                                    style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                SizedBox(
                                  height: 32,
                                  child: TextButton(
                                    onPressed: _testing ? null : _testPrint,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: _testing
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text('Test', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 28,
                                  child: TextButton(
                                    onPressed: _clearPrinter,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text('Hapus', style: GoogleFonts.inter(fontSize: 11, color: AppColors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Daftar perangkat
                    Text(
                      'PERANGKAT BLUETOOTH',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),

                    if (_scanning && _devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(Icons.bluetooth_disabled, size: 44, color: AppColors.placeholder),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada perangkat ditemukan',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pastikan printer sudah di-pair\nmelalui Pengaturan > Bluetooth',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _scan,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Scan Ulang'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._devices.map((d) {
                        final isSelected = d.macAdress == _selectedAddress;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: isSelected ? AppColors.primaryLight : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () => _select(d),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryMid : AppColors.borderLight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF101828).withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : AppColors.grayLight,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        Icons.bluetooth,
                                        color: isSelected ? Colors.white : AppColors.textDim,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.name,
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                                          ),
                                          Text(
                                            d.macAdress,
                                            style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    // Info tips
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pastikan printer sudah dipasangkan (paired) terlebih dahulu melalui Pengaturan › Bluetooth di HP Anda, dan printer dalam kondisi menyala saat memilih.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.primaryDark),
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
        ],
      ),
    );
  }
}
