import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../providers/loan_provider.dart';
import '../providers/emi_provider.dart';
import '../utils/app_utils.dart';
import '../services/notification_service.dart';
// import '../database/database_helper.dart';

class LoanDetailsScreen extends ConsumerStatefulWidget {
  final String loanId;
  final Loan loan;

  const LoanDetailsScreen({super.key, required this.loanId, required this.loan});

  @override
  ConsumerState<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends ConsumerState<LoanDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final emisAsyncValue = ref.watch(emisForLoanProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loan.loanName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Edit loan functionality
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLoanSummaryCard(),
            const SizedBox(height: 24),
            emisAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
              data: (emis) {
                 return _buildEmiList(emis);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSummaryCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Principal Amount', style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      AppUtils.formatCurrency(widget.loan.loanAmount),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('EMI Amount', style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      AppUtils.formatCurrency(widget.loan.emiAmount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoItem('Interest Rate', '${widget.loan.interestRate}% p.a.'),
                _infoItem('Tenure', '${widget.loan.totalMonths} months'),
                _infoItem('Remaining', '${widget.loan.remainingMonths} months'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmiList(List<Emi> emis) {
    if (emis.isEmpty) return const Text('No EMIs found.');

    final paidEmis = emis.where((e) => e.status == EmiStatus.paid).length;
    final progress = paidEmis / emis.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('EMI Repayment Schedule', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('${(progress * 100).toStringAsFixed(0)}% Completed', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: emis.length,
          itemBuilder: (context, index) {
            final emi = emis[index];
            final isPaid = emi.status == EmiStatus.paid;
            final isOverdue = emi.status == EmiStatus.overdue;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPaid ? Colors.green.withValues(alpha: 0.2) : (isOverdue ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                  child: Text('${emi.emiNumber}', style: TextStyle(color: isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange))),
                ),
                title: Text(AppUtils.formatDate(emi.dueDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(AppUtils.formatCurrency(emi.amount)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid ? Colors.green : null,
                    foregroundColor: isPaid ? Colors.white : null,
                  ),
                  onPressed: isPaid ? null : () => _markAsPaid(emi),
                  child: Text(isPaid ? 'Paid' : 'Pay Now'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _markAsPaid(Emi emi) async {
    final updatedEmi = emi.copyWith(
      status: EmiStatus.paid,
      paymentDate: DateTime.now(),
      paymentMethod: 'Manual',
    );

    // Update in DB
    await ref.read(databaseHelperProvider).updateEmi(updatedEmi);
    
    // Update Loan remaining months
    final newRemaining = widget.loan.remainingMonths > 0 ? widget.loan.remainingMonths - 1 : 0;
    final updatedLoan = widget.loan.copyWith(
      remainingMonths: newRemaining,
      status: newRemaining == 0 ? LoanStatus.closed : LoanStatus.active,
    );
    await ref.read(loanListProvider.notifier).updateLoan(updatedLoan);

    // Cancel Notifications
    await NotificationService().cancelEmiReminders(emi);

    // Refresh Providers
    ref.invalidate(emisForLoanProvider(widget.loanId));
    ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMI marked as Paid!')));
    }
  }
}
