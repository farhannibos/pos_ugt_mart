import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static const _keyAddress = 'bt_printer_address';
  static const _keyName = 'bt_printer_name';

  static Future<List<BluetoothInfo>> scanDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<void> saveSelectedPrinter(String address, String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyAddress, address);
    await p.setString(_keyName, name);
  }

  static Future<void> clearSelectedPrinter() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyAddress);
    await p.remove(_keyName);
  }

  static Future<(String?, String?)> getSelectedPrinter() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_keyAddress), p.getString(_keyName));
  }

  static Future<bool> _ensureConnected(String address) async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    return await PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  static Future<bool> writeBytes(List<int> bytes) async {
    final (address, _) = await getSelectedPrinter();
    if (address == null) return false;
    if (!await _ensureConnected(address)) return false;
    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  static Future<bool> testPrint() async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];
    bytes += gen.text(
      'TEST PRINT',
      styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += gen.feed(1);
    bytes += gen.text('Printer terhubung & siap digunakan', styles: PosStyles(align: PosAlign.center));
    bytes += gen.feed(1);
    bytes += gen.text('UGT MART POS', styles: PosStyles(align: PosAlign.center));
    bytes += gen.feed(3);
    bytes += gen.cut();
    return writeBytes(bytes);
  }
}
