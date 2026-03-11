import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/loan_provider.dart';
import '../models/loan.dart';
import '../utils/app_utils.dart';
import 'loan_details_screen.dart';
import 'add_loan_screen.dart';

class AllLoansScreen extends ConsumerWidget {
  const AllLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Loans'),
      ),
      body: loanState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (loans) {
          if (loans.isEmpty) {
            return const Center(child: Text('No loans found.'));
          }

          final now = DateTime.now();

          // Helper to calculate the next nearest upcoming EMI date simply (for sorting purposes)
          DateTime getNextDue(Loan loan) {
            if (loan.status == LoanStatus.closed) return DateTime(2100); // Push closed way back
            DateTime target = DateTime(now.year, now.month, loan.dueDayOfMonth);
            if (target.isBefore(now)) {
              target = DateTime(now.year, now.month + 1, loan.dueDayOfMonth);
            }
            return target;
          }

          final sortedLoans = List<Loan>.from(loans)
            ..sort((a, b) {
              if (a.status != b.status) {
                return a.status == LoanStatus.active ? -1 : 1;
              }
              final dueA = getNextDue(a);
              final dueB = getNextDue(b);
              return dueA.compareTo(dueB);
            });

          return ListView.builder(
            itemCount: sortedLoans.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final loan = sortedLoans[index];

              IconData getLoanIcon(String type) {
                final lw = type.toLowerCase();
                if (lw.contains('home')) return Icons.home_outlined;
                if (lw.contains('car') || lw.contains('auto')) return Icons.directions_car_outlined;
                if (lw.contains('education')) return Icons.school_outlined;
                if (lw.contains('business')) return Icons.business_center_outlined;
                return Icons.person_outline;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: loan.status == LoanStatus.active ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
                    child: Icon(getLoanIcon(loan.loanType), color: loan.status == LoanStatus.active ? Theme.of(context).colorScheme.primary : Colors.grey),
                  ),
                  title: Text(
                    loan.loanName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('${AppUtils.formatCurrency(loan.loanAmount > 0 ? loan.loanAmount : loan.emiAmount * loan.totalMonths)} · ${loan.interestRate}% p.a.', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      if (loan.status == LoanStatus.active)
                        Text('Next EMI: ${AppUtils.formatCurrency(loan.emiAmount)} on ${AppUtils.formatDate(getNextDue(loan))}', style: const TextStyle(color: Colors.grey, fontSize: 12))
                      else
                        const Text('Fully Paid ✅', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      loan.status.name.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: loan.status == LoanStatus.active ? Colors.green : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoanDetailsScreen(loanId: loan.id, loan: loan),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLoanScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
