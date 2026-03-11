import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emi.dart';
import '../database/database_helper.dart';
import 'loan_provider.dart';

class UpcomingEmiNotifier extends StateNotifier<AsyncValue<List<Emi>>> {
  final DatabaseHelper _db;

  UpcomingEmiNotifier(this._db) : super(const AsyncValue.loading()) {
    loadUpcomingEmis();
  }

  Future<void> loadUpcomingEmis() async {
    try {
      state = const AsyncValue.loading();
      final emis = await _db.getUpcomingEmis();
      state = AsyncValue.data(emis);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final upcomingEmiProvider = StateNotifierProvider<UpcomingEmiNotifier, AsyncValue<List<Emi>>>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return UpcomingEmiNotifier(db);
});

final allEmisProvider = FutureProvider<List<Emi>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getAllEmis();
});

// A provider to fetch EMIs for a specific loan
final emisForLoanProvider = FutureProvider.family<List<Emi>, String>((ref, loanId) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getEmisForLoan(loanId);
});
