import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/loan_provider.dart';
import '../providers/emi_provider.dart';
import '../utils/app_utils.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../core/app_colors.dart';
import 'add_loan_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanListProvider);
    final activeCount = ref.watch(activeLoansCountProvider);
    final totalAmount = ref.watch(totalLoanAmountProvider);
    final upcomingEmiState = ref.watch(upcomingEmiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )
        ],
      ),
      body: loanState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (loans) {
          if (loans.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(loanListProvider.notifier).loadLoans();
              ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(context, activeCount, totalAmount),
                  const SizedBox(height: 24),
                  _buildChartsSection(context, loans),
                  const SizedBox(height: 24),
                  Text(
                    'Upcoming EMIs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingEmis(upcomingEmiState),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLoanScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No active loans found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first loan to get started.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, int activeCount, double totalAmount) {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.monetization_on, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Total Loan', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatCurrency(totalAmount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.assignment, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 8),
                  Text('Active Loans', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '$activeCount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection(BuildContext context, List<Loan> loans) {
    // Only process active loans
    final activeLoans = loans.where((l) => l.status == LoanStatus.active).toList();
    if (activeLoans.isEmpty) return const SizedBox.shrink();

    // Generate colors
    final List<Color> chartColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      Colors.blue,
      Colors.orange,
      Colors.teal,
    ];

    List<PieChartSectionData> sections = [];
    double total = activeLoans.fold(0, (sum, l) => sum + l.loanAmount);

    for (int i = 0; i < activeLoans.length; i++) {
      final loan = activeLoans[i];
      final percentage = total > 0 ? (loan.loanAmount / total) * 100 : 0;
      sections.add(
        PieChartSectionData(
          color: chartColors[i % chartColors.length],
          value: loan.loanAmount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        )
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        sections: sections,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: activeLoans.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: chartColors[index % chartColors.length],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  activeLoans[index].loanName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildUpcomingEmis(AsyncValue<List<Emi>> upcomingEmiState) {
    return upcomingEmiState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
      data: (emis) {
        if (emis.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming EMIs soon! 🎉')),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: emis.length > 3 ? 3 : emis.length, // Show up to 3 upcoming
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final emi = emis[index];
            final isOverdue = emi.status == EmiStatus.overdue;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isOverdue ? AppColors.errorContainer : AppColors.primaryContainer,
                child: Icon(
                  isOverdue ? Icons.warning : Icons.calendar_today,
                  color: isOverdue ? AppColors.error : AppColors.primary,
                ),
              ),
              title: Text(
                AppUtils.formatCurrency(emi.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Due: ${AppUtils.formatDate(emi.dueDate)}'),
              trailing: Chip(
                label: Text(
                  isOverdue ? 'Overdue' : 'Pending',
                  style: TextStyle(
                    color: isOverdue ? AppColors.onErrorContainer : AppColors.onSecondaryContainer,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: isOverdue ? AppColors.errorContainer : AppColors.secondaryContainer,
              ),
            );
          },
        );
      },
    );
  }
}
