class Shift {
  final int id;
  final String kasirNama;
  final int modalAwal;
  final DateTime jamBuka;
  String status; // 'buka' | 'tutup'

  Shift({
    required this.id,
    required this.kasirNama,
    required this.modalAwal,
    required this.jamBuka,
    this.status = 'buka',
  });

  bool get isOpen => status == 'buka';

  String get jamBukaStr {
    final h = jamBuka.hour.toString().padLeft(2, '0');
    final m = jamBuka.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
