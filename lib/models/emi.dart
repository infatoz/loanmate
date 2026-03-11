enum EmiStatus {
  paid,
  pending,
  overdue,
}

class Emi {
  final String id;
  final String loanId;
  final int emiNumber;
  final DateTime dueDate;
  final double amount;
  final EmiStatus status;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? paymentReference;
  final String? proofImagePath;

  Emi({
    required this.id,
    required this.loanId,
    required this.emiNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.paymentReference,
    this.proofImagePath,
  });

  Emi copyWith({
    String? id,
    String? loanId,
    int? emiNumber,
    DateTime? dueDate,
    double? amount,
    EmiStatus? status,
    DateTime? paymentDate,
    String? paymentMethod,
    String? paymentReference,
    String? proofImagePath,
  }) {
    return Emi(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      emiNumber: emiNumber ?? this.emiNumber,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      proofImagePath: proofImagePath ?? this.proofImagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'emi_number': emiNumber,
      'due_date': dueDate.toIso8601String(),
      'amount': amount,
      'status': status.name,
      'payment_date': paymentDate?.toIso8601String(),
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'proof_image_path': proofImagePath,
    };
  }

  factory Emi.fromMap(Map<String, dynamic> map) {
    return Emi(
      id: map['id'],
      loanId: map['loan_id'],
      emiNumber: map['emi_number']?.toInt() ?? 0,
      dueDate: DateTime.parse(map['due_date']),
      amount: map['amount']?.toDouble() ?? 0.0,
      status: EmiStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => EmiStatus.pending,
      ),
      paymentDate: map['payment_date'] != null ? DateTime.parse(map['payment_date']) : null,
      paymentMethod: map['payment_method'],
      paymentReference: map['payment_reference'],
      proofImagePath: map['proof_image_path'],
    );
  }
}
