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
import 'settings_screen.dart';
import 'loan_details_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanListProvider);
    final upcomingEmiState = ref.watch(upcomingEmiProvider);
    final allEmisAsync = ref.watch(allEmisProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('LoanMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allEmisProvider);
          ref.read(loanListProvider.notifier).loadLoans();
          ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();
        },
        child: loanState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (loans) {
            if (loans.isEmpty) return _buildEmptyState(context);
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(context, ref, loans, allEmisAsync),
                  const SizedBox(height: 20),
                  _buildChartsSection(context, loans, allEmisAsync),
                  const SizedBox(height: 20),
                  _buildUpcomingSection(context, upcomingEmiState, ref),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLoanScreen())),
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
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(Icons.account_balance_wallet, size: 60, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text('No Loans Yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tap + Add Loan to start tracking', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref, List<Loan> loans, AsyncValue<List<Emi>> allEmisAsync) {
    final activeLoans = loans.where((l) => l.status == LoanStatus.active);
    final totalLoan = activeLoans.fold(0.0, (s, l) => s + (l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths));
    final totalMonthlyEmi = activeLoans.fold(0.0, (s, l) => s + l.emiAmount);
    final closedCount = loans.where((l) => l.status == LoanStatus.closed).length;

    double totalPaid = 0;
    allEmisAsync.whenData((emis) {
      totalPaid = emis.where((e) => e.status == EmiStatus.paid).fold(0.0, (s, e) => s + e.amount);
    });
    final totalRemaining = totalLoan - totalPaid;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statCard(context, 'Total Loan', AppUtils.formatCurrency(totalLoan), Icons.monetization_on, AppColors.primary, AppColors.primaryContainer)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(context, 'Monthly EMI', AppUtils.formatCurrency(totalMonthlyEmi), Icons.repeat, Colors.indigo, Colors.indigo.shade50)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard(context, 'Total Paid', AppUtils.formatCurrency(totalPaid), Icons.check_circle, Colors.green, Colors.green.shade50)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(context, 'Remaining', AppUtils.formatCurrency(totalRemaining > 0 ? totalRemaining : 0), Icons.pending_actions, Colors.orange, Colors.orange.shade50)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard(context, 'Active Loans', '${activeLoans.length}', Icons.assignment, AppColors.secondary, AppColors.secondaryContainer)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(context, 'Closed Loans', '$closedCount', Icons.task_alt, Colors.teal, Colors.teal.shade50)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color, Color bgColor) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context, List<Loan> loans, AsyncValue<List<Emi>> allEmisAsync) {
    final activeLoans = loans.where((l) => l.status == LoanStatus.active).toList();
    if (activeLoans.isEmpty) return const SizedBox.shrink();

    final List<Color> chartColors = [AppColors.primary, AppColors.secondary, AppColors.tertiary, Colors.blue, Colors.orange, Colors.teal];
    final double total = activeLoans.fold(0.0, (s, l) => s + (l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths));

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loan Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38,
                          sections: List.generate(activeLoans.length, (i) {
                            final effectiveAmt = activeLoans[i].loanAmount > 0 ? activeLoans[i].loanAmount : (activeLoans[i].emiAmount * activeLoans[i].totalMonths);
                            final pct = total > 0 ? (effectiveAmt / total * 100) : 0;
                            return PieChartSectionData(
                              color: chartColors[i % chartColors.length],
                              value: effectiveAmt,
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: 48,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }),
                        )),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(activeLoans.length, (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: chartColors[i % chartColors.length], borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Expanded(child: Text(activeLoans[i].loanName, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                            ]),
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // EMI Status Bar Chart
        allEmisAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (emis) {
            final paid = emis.where((e) => e.status == EmiStatus.paid).length;
            final pending = emis.where((e) => e.status == EmiStatus.pending).length;
            final overdue = emis.where((e) => e.status == EmiStatus.overdue).length;
            final totalEmi = paid + pending + overdue;
            if (totalEmi == 0) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMI Progress', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _emiProgressItem(context, 'Paid', paid, totalEmi, Colors.green),
                        _emiProgressItem(context, 'Pending', pending, totalEmi, Colors.orange),
                        _emiProgressItem(context, 'Overdue', overdue, totalEmi, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            if (paid > 0) Expanded(flex: paid, child: Container(color: Colors.green)),
                            if (pending > 0) Expanded(flex: pending, child: Container(color: Colors.orange)),
                            if (overdue > 0) Expanded(flex: overdue, child: Container(color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$paid of $totalEmi installments paid (${(paid / totalEmi * 100).toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _emiProgressItem(BuildContext context, String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontSize: 12)),
          Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context, AsyncValue<List<Emi>> upcomingEmiState, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming EMIs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        upcomingEmiState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
          data: (emis) {
            // Filter out purely paid EMIs and group by loanId to find the single next earliest EMI per loan
            final upcoming = emis.where((e) => e.status != EmiStatus.paid).toList();
            final Map<String, Emi> nextEmiPerLoan = {};
            for (var e in upcoming) {
              if (!nextEmiPerLoan.containsKey(e.loanId) || e.dueDate.isBefore(nextEmiPerLoan[e.loanId]!.dueDate)) {
                nextEmiPerLoan[e.loanId] = e;
              }
            }
            final sortedNextEmis = nextEmiPerLoan.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

            if (sortedNextEmis.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration, color: Colors.green),
                      const SizedBox(width: 12),
                      Text('All clear! No upcoming EMIs 🎉', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedNextEmis.length > 5 ? 5 : sortedNextEmis.length,
              itemBuilder: (context, index) {
                final emi = sortedNextEmis[index];
                
                // Retrieve the loan object for name and navigation
                final loansState = ref.watch(loanListProvider);
                final loanList = loansState.asData?.value ?? [];
                final parentLoan = loanList.firstWhere((l) => l.id == emi.loanId, orElse: () => Loan(id: '', lenderName: '', loanName: 'Unknown Loan', loanType: '', loanAmount: 0, emiAmount: 0, interestRate: 0, totalMonths: 0, remainingMonths: 0, startDate: DateTime.now(), dueDayOfMonth: 1, notes: '', status: LoanStatus.active, createdAt: DateTime.now()));
                
                final isOverdue = emi.status == EmiStatus.overdue;
                final daysUntil = emi.dueDate.difference(DateTime.now()).inDays;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOverdue ? Colors.red.shade50 : Colors.orange.shade50,
                      child: Icon(isOverdue ? Icons.warning_amber : Icons.schedule,
                          color: isOverdue ? Colors.red : Colors.orange, size: 20),
                    ),
                    title: Text(parentLoan.loanName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMI #${emi.emiNumber} · ${AppUtils.formatCurrency(emi.amount)}'),
                        Text(AppUtils.formatDate(emi.dueDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    onTap: () {
                      if (parentLoan.id.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailsScreen(loanId: parentLoan.id, loan: parentLoan)));
                      }
                    },
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverdue ? Colors.red.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOverdue ? 'Overdue' : (daysUntil == 0 ? 'Today' : 'In $daysUntil days'),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
