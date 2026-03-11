enum LoanStatus {
  active,
  closed,
}

class Loan {
  final String id;
  final String lenderName;
  final String loanName;
  final String loanType;
  final double loanAmount;
  final double emiAmount;
  final double interestRate;
  final int totalMonths;
  final int remainingMonths;
  final DateTime startDate;
  final int dueDayOfMonth;
  final String notes;
  final LoanStatus status;
  final DateTime createdAt;

  Loan({
    required this.id,
    required this.lenderName,
    required this.loanName,
    required this.loanType,
    required this.loanAmount,
    required this.emiAmount,
    required this.interestRate,
    required this.totalMonths,
    required this.remainingMonths,
    required this.startDate,
    required this.dueDayOfMonth,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  Loan copyWith({
    String? id,
    String? lenderName,
    String? loanName,
    String? loanType,
    double? loanAmount,
    double? emiAmount,
    double? interestRate,
    int? totalMonths,
    int? remainingMonths,
    DateTime? startDate,
    int? dueDayOfMonth,
    String? notes,
    LoanStatus? status,
    DateTime? createdAt,
  }) {
    return Loan(
      id: id ?? this.id,
      lenderName: lenderName ?? this.lenderName,
      loanName: loanName ?? this.loanName,
      loanType: loanType ?? this.loanType,
      loanAmount: loanAmount ?? this.loanAmount,
      emiAmount: emiAmount ?? this.emiAmount,
      interestRate: interestRate ?? this.interestRate,
      totalMonths: totalMonths ?? this.totalMonths,
      remainingMonths: remainingMonths ?? this.remainingMonths,
      startDate: startDate ?? this.startDate,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lender_name': lenderName,
      'loan_name': loanName,
      'loan_type': loanType,
      'loan_amount': loanAmount,
      'emi_amount': emiAmount,
      'interest_rate': interestRate,
      'total_months': totalMonths,
      'remaining_months': remainingMonths,
      'start_date': startDate.toIso8601String(),
      'due_day_of_month': dueDayOfMonth,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      lenderName: map['lender_name'],
      loanName: map['loan_name'],
      loanType: map['loan_type'],
      loanAmount: map['loan_amount']?.toDouble() ?? 0.0,
      emiAmount: map['emi_amount']?.toDouble() ?? 0.0,
      interestRate: map['interest_rate']?.toDouble() ?? 0.0,
      totalMonths: map['total_months']?.toInt() ?? 0,
      remainingMonths: map['remaining_months']?.toInt() ?? 0,
      startDate: DateTime.parse(map['start_date']),
      dueDayOfMonth: map['due_day_of_month']?.toInt() ?? 1,
      notes: map['notes'] ?? '',
      status: LoanStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LoanStatus.active,
      ),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
