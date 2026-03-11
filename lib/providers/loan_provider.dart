import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan.dart';
import '../database/database_helper.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

class LoanNotifier extends StateNotifier<AsyncValue<List<Loan>>> {
  final DatabaseHelper _db;

  LoanNotifier(this._db) : super(const AsyncValue.loading()) {
    loadLoans();
  }

  Future<void> loadLoans() async {
    try {
      state = const AsyncValue.loading();
      final loans = await _db.getAllLoans();
      state = AsyncValue.data(loans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addLoan(Loan loan) async {
    await _db.insertLoan(loan);
    await loadLoans(); // Refresh list
  }

  Future<void> updateLoan(Loan loan) async {
    await _db.updateLoan(loan);
    await loadLoans(); // Refresh list
  }

  Future<void> deleteLoan(String id) async {
    await _db.deleteLoan(id);
    await loadLoans(); // Refresh list
  }
}

final loanListProvider = StateNotifierProvider<LoanNotifier, AsyncValue<List<Loan>>>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return LoanNotifier(db);
});

// Summary providers derived from the main list
final activeLoansCountProvider = Provider<int>((ref) {
  final loansState = ref.watch(loanListProvider);
  return loansState.maybeWhen(
    data: (loans) => loans.where((l) => l.status == LoanStatus.active).length,
    orElse: () => 0,
  );
});

final totalLoanAmountProvider = Provider<double>((ref) {
  final loansState = ref.watch(loanListProvider);
  return loansState.maybeWhen(
    data: (loans) => loans.fold(0.0, (sum, loan) => sum + loan.loanAmount),
    orElse: () => 0.0,
  );
});
