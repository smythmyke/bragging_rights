class FighterModel {
  final String id;
  final String name;
  final String? nickname;
  final String? record;
  final int? wins;
  final int? losses;
  final int? draws;
  final int? knockouts;
  final int? submissions;
  final int? decisions;
  final String? height;
  final String? weight;
  final String? reach;
  final String? stance;
  final int? age;
  final String? birthDate;
  final String? country;
  final String? flagUrl;
  final String? imageUrl;
  final String? division;
  final List<Map<String, dynamic>>? recentFights;

  FighterModel({
    required this.id,
    required this.name,
    this.nickname,
    this.record,
    this.wins,
    this.losses,
    this.draws,
    this.knockouts,
    this.submissions,
    this.decisions,
    this.height,
    this.weight,
    this.reach,
    this.stance,
    this.age,
    this.birthDate,
    this.country,
    this.flagUrl,
    this.imageUrl,
    this.division,
    this.recentFights,
  });

  factory FighterModel.fromJson(Map<String, dynamic> json) {
    // Parse record to extract wins/losses/draws
    int? wins;
    int? losses;
    int? draws;

    if (json['record'] != null) {
      final recordParts = json['record'].toString().split('-');
      if (recordParts.length >= 2) {
        wins = int.tryParse(recordParts[0]);
        losses = int.tryParse(recordParts[1]);
        if (recordParts.length >= 3) {
          draws = int.tryParse(recordParts[2]);
        }
      }
    }

    return FighterModel(
      id: json['id']?.toString() ?? '',
      name: json['displayName'] ?? json['name'] ?? 'Unknown Fighter',
      nickname: json['nickname'],
      record: json['record'],
      wins: wins ?? json['wins'],
      losses: losses ?? json['losses'],
      draws: draws ?? json['draws'] ?? 0,
      knockouts: json['knockouts'] ?? json['ko'],
      submissions: json['submissions'] ?? json['sub'],
      decisions: json['decisions'] ?? json['dec'],
      height: json['height'],
      weight: json['weight'],
      reach: json['reach'],
      stance: json['stance'],
      age: json['age'],
      birthDate: json['birthDate'] ?? json['dateOfBirth'],
      country: json['birthCountry'] ?? json['country'],
      flagUrl: json['flag'],
      imageUrl: json['headshot']?['href'] ?? json['imageUrl'],
      division: json['division'] ?? json['weightClass'],
      recentFights: json['recentFights'] != null
          ? List<Map<String, dynamic>>.from(json['recentFights'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'record': record,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'knockouts': knockouts,
      'submissions': submissions,
      'decisions': decisions,
      'height': height,
      'weight': weight,
      'reach': reach,
      'stance': stance,
      'age': age,
      'birthDate': birthDate,
      'country': country,
      'flagUrl': flagUrl,
      'imageUrl': imageUrl,
      'division': division,
      'recentFights': recentFights,
    };
  }
}