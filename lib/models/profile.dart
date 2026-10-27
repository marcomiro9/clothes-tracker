class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.pairId,
  });

  final String id;
  final String displayName;
  final String? pairId;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        displayName: map['display_name'] as String,
        pairId: map['pair_id'] as String?,
      );
}