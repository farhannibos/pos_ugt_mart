class Member {
  final String id;
  final String nama;
  final String hp;
  int poin;
  int spend;

  Member({
    required this.id,
    required this.nama,
    required this.hp,
    required this.poin,
    required this.spend,
  });

  String get tier {
    if (poin >= 1000) return 'Gold';
    if (poin >= 500) return 'Silver';
    return 'Reguler';
  }

  String get initials {
    final words = nama.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return nama.substring(0, 2).toUpperCase();
  }
}

final List<Member> dummyMembers = [];
