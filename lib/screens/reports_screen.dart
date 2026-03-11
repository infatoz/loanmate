import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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
            tooltip: 'Export Summary PDF',
            onPressed: () => _exportSummaryPdf(context, loanState, allEmisAsync),
          ),
        ],
      ),
      body: loanState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (loans) => allEmisAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (emis) => _buildBody(context, loans, emis),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Loan> loans, List<Emi> emis) {
    if (loans.isEmpty) {
      return const Center(child: Text('No data to report yet.'));
    }

    final totalPrincipal = loans.fold(0.0, (s, l) => s + (l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths));
    final totalPayable = loans.fold(0.0, (s, l) => s + (l.emiAmount * l.totalMonths));
    final totalInterest = totalPayable - totalPrincipal;
    final totalPaid = emis.where((e) => e.status == EmiStatus.paid).fold(0.0, (s, e) => s + e.amount);
    final totalRemaining = totalPayable - totalPaid;

    final paidCount = emis.where((e) => e.status == EmiStatus.paid).length;
    final pendingCount = emis.where((e) => e.status == EmiStatus.pending).length;
    final overdueCount = emis.where((e) => e.status == EmiStatus.overdue).length;
    final totalCount = emis.length;

    final activeLoans = loans.where((l) => l.status == LoanStatus.active).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === FINANCIAL HEALTH CARD ===
        _buildHealthCard(context, totalPaid, totalPayable, overdueCount),
        const SizedBox(height: 16),
        // === SUMMARY NUMBERS ===
        _sectionTitle(context, 'Loan Summary'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _metricCard(context, 'Total Principal', AppUtils.formatCurrency(totalPrincipal), Icons.account_balance, Colors.blue),
            _metricCard(context, 'Total Payable', AppUtils.formatCurrency(totalPayable), Icons.payments, AppColors.primary),
            _metricCard(context, 'Total Interest', AppUtils.formatCurrency(totalInterest), Icons.percent, Colors.orange),
            _metricCard(context, 'Total Paid', AppUtils.formatCurrency(totalPaid), Icons.check_circle, Colors.green),
            _metricCard(context, 'Remaining', AppUtils.formatCurrency(totalRemaining > 0 ? totalRemaining : 0), Icons.pending_actions, Colors.red),
            _metricCard(context, 'Monthly Load', AppUtils.formatCurrency(activeLoans.fold(0.0, (s, l) => s + l.emiAmount)), Icons.calendar_month, Colors.teal),
          ],
        ),
        const SizedBox(height: 20),
        // === PAID VS REMAINING BAR ===
        _sectionTitle(context, 'Overall Progress'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: totalPayable > 0 ? (totalPaid / totalPayable).clamp(0.0, 1.0) : 0,
                  minHeight: 16,
                  backgroundColor: Colors.orange.shade100,
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _progressLabel('Paid', AppUtils.formatCurrency(totalPaid), Colors.green),
                  Text('${(totalPayable > 0 ? totalPaid / totalPayable * 100 : 0).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _progressLabel('Remaining', AppUtils.formatCurrency(totalRemaining > 0 ? totalRemaining : 0), Colors.orange),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // === EMI STATUS PIE CHART ===
        _sectionTitle(context, 'EMI Status Breakdown'),
        const SizedBox(height: 10),
        if (totalCount > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 160,
                      child: PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          if (paidCount > 0) PieChartSectionData(color: Colors.green, value: paidCount.toDouble(), title: '$paidCount', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          if (pendingCount > 0) PieChartSectionData(color: Colors.orange, value: pendingCount.toDouble(), title: '$pendingCount', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          if (overdueCount > 0) PieChartSectionData(color: Colors.red, value: overdueCount.toDouble(), title: '$overdueCount', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      )),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pieLegend('Paid', paidCount, totalCount, Colors.green),
                        const SizedBox(height: 12),
                        _pieLegend('Pending', pendingCount, totalCount, Colors.orange),
                        const SizedBox(height: 12),
                        _pieLegend('Overdue', overdueCount, totalCount, Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        // === LOAN DISTRIBUTION PIE ===
        _sectionTitle(context, 'Loan Distribution'),
        const SizedBox(height: 10),
        if (activeLoans.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLoanDistributionChart(context, activeLoans),
            ),
          ),
        const SizedBox(height: 20),
        // === SMART INSIGHTS ===
        _sectionTitle(context, '💡 Smart Insights'),
        const SizedBox(height: 10),
        _buildSmartInsights(context, loans, emis),
        const SizedBox(height: 20),
        // === LOANS TABLE ===
        _sectionTitle(context, 'Loans Overview'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ...loans.map((l) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: l.status == LoanStatus.active ? AppColors.primaryContainer : Colors.grey.shade100,
                  child: Icon(Icons.account_balance, size: 18, color: l.status == LoanStatus.active ? AppColors.primary : Colors.grey),
                ),
                title: Text(l.loanName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${l.lenderName} · ${l.loanType}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppUtils.formatCurrency(l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: l.status == LoanStatus.active ? Colors.green.shade100 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l.status.name.toUpperCase(), style: TextStyle(fontSize: 10, color: l.status == LoanStatus.active ? Colors.green.shade700 : Colors.grey)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthCard(BuildContext context, double totalPaid, double totalPayable, int overdueCount) {
    final pct = totalPayable > 0 ? (totalPaid / totalPayable * 100) : 0;
    String healthLabel;
    Color healthColor;
    IconData healthIcon;
    if (overdueCount > 0) {
      healthLabel = 'Needs Attention';
      healthColor = Colors.red;
      healthIcon = Icons.warning_amber;
    } else if (pct > 75) {
      healthLabel = 'Excellent';
      healthColor = Colors.green;
      healthIcon = Icons.sentiment_very_satisfied;
    } else if (pct > 40) {
      healthLabel = 'Good';
      healthColor = Colors.lightGreen;
      healthIcon = Icons.sentiment_satisfied;
    } else {
      healthLabel = 'Getting Started';
      healthColor = Colors.orange;
      healthIcon = Icons.emoji_emotions_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [healthColor, healthColor.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(healthIcon, size: 48, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financial Health', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(healthLabel, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${pct.toStringAsFixed(1)}% of total debt repaid${overdueCount > 0 ? ' · $overdueCount EMI overdue!' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsights(BuildContext context, List<Loan> loans, List<Emi> emis) {
    final active = loans.where((l) => l.status == LoanStatus.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    // Sort by remaining months (fewest first = close first)
    final sortedByRemaining = List.of(active)..sort((a, b) => a.remainingMonths.compareTo(b.remainingMonths));
    final highestRate = [...active]..sort((a, b) => b.interestRate.compareTo(a.interestRate));
    final overdueEmis = emis.where((e) => e.status == EmiStatus.overdue).toList();

    return Column(
      children: [
        if (overdueEmis.isNotEmpty)
          _insightCard(context, Icons.warning_amber, Colors.red, 'Overdue Alert',
              'You have ${overdueEmis.length} overdue EMI(s) totalling ${AppUtils.formatCurrency(overdueEmis.fold(0.0, (s, e) => s + e.amount))}. Pay immediately to avoid penalties.'),
        if (sortedByRemaining.isNotEmpty)
          _insightCard(context, Icons.flag, Colors.teal, 'Quick Win',
              'Pay off "${sortedByRemaining.first.loanName}" first — only ${sortedByRemaining.first.remainingMonths} installments left!'),
        if (highestRate.first.interestRate > 0)
          _insightCard(context, Icons.percent, Colors.orange, 'Save on Interest',
              '"${highestRate.first.loanName}" has the highest rate (${highestRate.first.interestRate}%). Consider prepaying to save on interest.'),
      ],
    );
  }

  Widget _insightCard(BuildContext context, IconData icon, Color color, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanDistributionChart(BuildContext context, List<Loan> loans) {
    final List<Color> colors = [AppColors.primary, AppColors.secondary, AppColors.tertiary, Colors.blue, Colors.orange, Colors.teal];
    final total = loans.fold(0.0, (s, l) => s + (l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths));
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: List.generate(loans.length, (i) {
                final effAmt = loans[i].loanAmount > 0 ? loans[i].loanAmount : (loans[i].emiAmount * loans[i].totalMonths);
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: effAmt,
                  title: total > 0 ? '${(effAmt / total * 100).toStringAsFixed(0)}%' : '',
                  radius: 48,
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                );
              }),
            )),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(loans.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(loans[i].loanName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                ]),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));

  Widget _metricCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressLabel(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ],
  );

  Widget _pieLegend(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100) : 0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('$count EMIs (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
      ],
    );
  }


  Future<void> _exportSummaryPdf(BuildContext context, AsyncValue<List<Loan>> loanState, AsyncValue<List<Emi>> allEmisAsync) async {
    final loans = loanState.asData?.value ?? [];
    final emis = allEmisAsync.asData?.value ?? [];
    try {
      final pdf = pw.Document();
      final totalPaid = emis.where((e) => e.status == EmiStatus.paid).fold(0.0, (s, e) => s + e.amount);
      final totalPayable = loans.fold(0.0, (s, l) => s + (l.emiAmount * l.totalMonths));

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('LoanMate – Financial Summary', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Total Loans: ${loans.length}'),
            pw.Text('Total Principal: ${AppUtils.formatCurrency(loans.fold(0.0, (s, l) => s + (l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths)))}'),
            pw.Text('Total Payable: ${AppUtils.formatCurrency(totalPayable)}'),
            pw.Text('Total Paid: ${AppUtils.formatCurrency(totalPaid)}'),
            pw.Text('Remaining: ${AppUtils.formatCurrency(totalPayable - totalPaid)}'),
            pw.SizedBox(height: 20),
            pw.Text('Loans', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Loan', 'Lender', 'Amount', 'EMI', 'Remaining', 'Status'],
              data: loans.map((l) => [
                l.loanName, l.lenderName,
                AppUtils.formatCurrency(l.loanAmount > 0 ? l.loanAmount : l.emiAmount * l.totalMonths),
                AppUtils.formatCurrency(l.emiAmount),
                '${l.remainingMonths} months',
                l.status.name.toUpperCase(),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ));

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/loanmate_summary_report.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
