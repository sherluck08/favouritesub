class ReferralMember {
  const ReferralMember({
    required this.id,
    required this.username,
    this.joinedAt,
  });

  final int id;
  final String username;
  final DateTime? joinedAt;

  factory ReferralMember.fromJson(Map<String, dynamic> json) {
    final rawDate = json['create_date'] ?? json['joined_at'];
    return ReferralMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString().trim(),
      joinedAt: rawDate == null
          ? null
          : DateTime.tryParse(rawDate.toString())?.toLocal(),
    );
  }
}
