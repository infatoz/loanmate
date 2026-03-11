import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/loan_provider.dart';
import '../providers/emi_provider.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../utils/app_utils.dart';
import '../core/app_colors.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanListProvider);
    final allEmisAsync = ref.watch(allEmisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF Export coming soon!')),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildOverallSummary(context, loanState, allEmisAsync),
             const SizedBox(height: 24),
             _buildRepaymentChart(context, allEmisAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallSummary(BuildContext context, AsyncValue<List<Loan>> loanState, AsyncValue<List<Emi>> allEmisAsync) {
    return loanState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
      data: (loans) {
        final totalPrincipal = loans.fold(0.0, (sum, l) => sum + l.loanAmount);
        final totalInterest = loans.fold(0.0, (sum, l) => sum + ((l.emiAmount * l.totalMonths) - l.loanAmount));
        final totalPayable = totalPrincipal + totalInterest;

        return allEmisAsync.when(
          loading: () => const SizedBox(),
          error: (e, st) => const SizedBox(),
          data: (emis) {
            final totalPaid = emis.where((e) => e.status == EmiStatus.paid).fold(0.0, (sum, e) => sum + e.amount);
            final totalRemaining = totalPayable - totalPaid;

            return Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Financial Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _summaryItem(context, 'Total Payable', AppUtils.formatCurrency(totalPayable), AppColors.primary),
                        _summaryItem(context, 'Total Paid', AppUtils.formatCurrency(totalPaid), Colors.green),
                        _summaryItem(context, 'Remaining', AppUtils.formatCurrency(totalRemaining), Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LinearProgressIndicator(
                      value: totalPayable > 0 ? totalPaid / totalPayable : 0,
                      minHeight: 12,
                      backgroundColor: Colors.orange.withValues(alpha: 0.3),
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text('${(totalPayable > 0 ? (totalPaid / totalPayable * 100) : 0).toStringAsFixed(1)}% Paid Off', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _summaryItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildRepaymentChart(BuildContext context, AsyncValue<List<Emi>> allEmisAsync) {
    return allEmisAsync.when(
      loading: () => const SizedBox(),
      error: (e, st) => const SizedBox(),
      data: (emis) {
        final paidEmis = emis.where((e) => e.status == EmiStatus.paid).length;
        final pendingEmis = emis.where((e) => e.status == EmiStatus.pending).length;
        final overdueEmis = emis.where((e) => e.status == EmiStatus.overdue).length;

        if (emis.isEmpty) return const SizedBox();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMI Status Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: [
                              if (paidEmis > 0)
                                PieChartSectionData(
                                  color: Colors.green,
                                  value: paidEmis.toDouble(),
                                  title: '$paidEmis',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (pendingEmis > 0)
                                PieChartSectionData(
                                  color: Colors.orange,
                                  value: pendingEmis.toDouble(),
                                  title: '$pendingEmis',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (overdueEmis > 0)
                                PieChartSectionData(
                                  color: Colors.red,
                                  value: overdueEmis.toDouble(),
                                  title: '$overdueEmis',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legendItem('Paid', Colors.green),
                            const SizedBox(height: 8),
                            _legendItem('Pending', Colors.orange),
                            const SizedBox(height: 8),
                            _legendItem('Overdue', Colors.red),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
