class UserDataExportModel {
  final String id;
  final String status;
  final String fileName;
  final String downloadUrl;
  final int fileSizeBytes;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const UserDataExportModel({
    required this.id,
    required this.status,
    required this.fileName,
    required this.downloadUrl,
    required this.fileSizeBytes,
    this.createdAt,
    this.expiresAt,
  });

  factory UserDataExportModel.fromMap(Map<String, dynamic> map) {
    return UserDataExportModel(
      id: (map['id'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      downloadUrl: (map['downloadUrl'] ?? '').toString(),
      fileSizeBytes: _toInt(map['fileSizeBytes']),
      createdAt: _parseDate(map['createdAt']),
      expiresAt: _parseDate(map['expiresAt']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
