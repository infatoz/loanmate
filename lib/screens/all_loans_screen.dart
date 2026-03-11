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
          return ListView.builder(
            itemCount: loans.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final loan = loans[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    loan.loanName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Lender: ${loan.lenderName}'),
                      const SizedBox(height: 4),
                      Text('Amount: ${AppUtils.formatCurrency(loan.loanAmount)}'),
                      const SizedBox(height: 4),
                      Text('EMI: ${AppUtils.formatCurrency(loan.emiAmount)} (${loan.remainingMonths}/${loan.totalMonths} remaining)'),
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
