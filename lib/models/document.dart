class Document {
  final String id;
  final String loanId;
  final String filePath;
  final String fileType;
  final DateTime uploadedAt;

  Document({
    required this.id,
    required this.loanId,
    required this.filePath,
    required this.fileType,
    required this.uploadedAt,
  });

  Document copyWith({
    String? id,
    String? loanId,
    String? filePath,
    String? fileType,
    DateTime? uploadedAt,
  }) {
    return Document(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'file_path': filePath,
      'file_type': fileType,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      loanId: map['loan_id'],
      filePath: map['file_path'],
      fileType: map['file_type'],
      uploadedAt: DateTime.parse(map['uploaded_at']),
    );
  }
}
