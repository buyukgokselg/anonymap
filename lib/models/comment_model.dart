class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userDisplayName;
  final String userProfilePhotoUrl;
  final String text;
  final DateTime? createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.userDisplayName = '',
    this.userProfilePhotoUrl = '',
    this.text = '',
    this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: (map['id'] ?? '').toString(),
      postId: (map['postId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userDisplayName: (map['userDisplayName'] ?? '').toString(),
      userProfilePhotoUrl: (map['userProfilePhotoUrl'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
