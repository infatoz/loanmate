import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../providers/loan_provider.dart';
import '../providers/emi_provider.dart';
import '../utils/app_utils.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'add_loan_screen.dart';

class LoanDetailsScreen extends ConsumerStatefulWidget {
  final String loanId;
  final Loan loan;

  const LoanDetailsScreen({super.key, required this.loanId, required this.loan});

  @override
  ConsumerState<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends ConsumerState<LoanDetailsScreen> {
  late Loan _currentLoan;

  @override
  void initState() {
    super.initState();
    _currentLoan = widget.loan;
  }

  @override
  Widget build(BuildContext context) {
    final emisAsync = ref.watch(emisForLoanProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentLoan.loanName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Loan',
            onPressed: () async {
              final updated = await Navigator.push<Loan>(
                context,
                MaterialPageRoute(builder: (_) => AddLoanScreen(existingLoan: _currentLoan)),
              );
              if (updated != null) setState(() => _currentLoan = updated);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(emisAsync),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') _confirmDelete(context);
              if (val == 'close') _confirmClose(context);
            },
            itemBuilder: (_) => [
              if (_currentLoan.status == LoanStatus.active)
                const PopupMenuItem(value: 'close', child: Row(children: [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 8), Text('Close Loan')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete Loan', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: emisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (emis) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummary(context, emis),
              const SizedBox(height: 20),
              _buildProgressCard(context, emis),
              const SizedBox(height: 20),
              Text('EMI Schedule', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildEmiList(context, emis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, List<Emi> emis) {
    final cs = Theme.of(context).colorScheme;
    final totalPayable = _currentLoan.emiAmount * _currentLoan.totalMonths;
    final totalInterest = totalPayable - _currentLoan.loanAmount;
    final paidAmount = emis.where((e) => e.status == EmiStatus.paid).fold(0.0, (s, e) => s + e.amount);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_currentLoan.lenderName, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(height: 4),
                Text(AppUtils.formatCurrency(_currentLoan.loanAmount),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _currentLoan.status == LoanStatus.active ? Colors.green.shade400 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_currentLoan.status.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _summaryItem('EMI / Month', AppUtils.formatCurrency(_currentLoan.emiAmount), Colors.white)),
              Flexible(child: _summaryItem('Tenure', '${_currentLoan.totalMonths} months', Colors.white)),
              Flexible(child: _summaryItem('Rate', '${_currentLoan.interestRate}%', Colors.white)),
            ],
          ),
          const Divider(color: Colors.white30, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _summaryItem('Paid', AppUtils.formatCurrency(paidAmount), Colors.greenAccent)),
              Flexible(child: _summaryItem('Total Payable', AppUtils.formatCurrency(totalPayable), Colors.white70)),
              Flexible(child: _summaryItem('Interest', AppUtils.formatCurrency(totalInterest > 0 ? totalInterest : 0), Colors.orangeAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ],
  );

  Widget _buildProgressCard(BuildContext context, List<Emi> emis) {
    final paid = emis.where((e) => e.status == EmiStatus.paid).length;
    final progress = emis.isNotEmpty ? paid / emis.length : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Repayment Progress', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text('$paid / ${emis.length} paid', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey.shade200, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).toStringAsFixed(1)}% completed · ${emis.length - paid} installments remaining',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildEmiList(BuildContext context, List<Emi> emis) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: emis.length,
      itemBuilder: (context, index) {
        final emi = emis[index];
        final isPaid = emi.status == EmiStatus.paid;
        final isOverdue = emi.status == EmiStatus.overdue;
        final statusColor = isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Text('${emi.emiNumber}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Row(
              children: [
                Text(AppUtils.formatDate(emi.dueDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha:0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(emi.status.name.toUpperCase(), style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: isPaid && emi.paymentDate != null
                ? Text('Paid on ${AppUtils.formatDate(emi.paymentDate!)}', style: const TextStyle(fontSize: 12))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppUtils.formatCurrency(emi.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!isPaid) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12)),
                    onPressed: () => _markAsPaid(emi),
                    child: const Text('Pay'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsPaid(Emi emi) async {
    final updatedEmi = emi.copyWith(status: EmiStatus.paid, paymentDate: DateTime.now(), paymentMethod: 'Manual');
    await DatabaseHelper.instance.updateEmi(updatedEmi);
    final newRemaining = (_currentLoan.remainingMonths - 1).clamp(0, _currentLoan.totalMonths);
    final updatedLoan = _currentLoan.copyWith(
      remainingMonths: newRemaining,
      status: newRemaining == 0 ? LoanStatus.closed : LoanStatus.active,
    );
    await ref.read(loanListProvider.notifier).updateLoan(updatedLoan);
    setState(() => _currentLoan = updatedLoan);
    await NotificationService().cancelEmiReminders(emi);
    ref.invalidate(emisForLoanProvider(widget.loanId));
    ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ EMI marked as Paid!')));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: Text('This will permanently delete "${_currentLoan.loanName}" and all its EMI records. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(loanListProvider.notifier).deleteLoan(_currentLoan.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Loan deleted.')));
      navigator.pop();
    }
  }

  Future<void> _confirmClose(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Loan?'),
        content: Text('Mark "${_currentLoan.loanName}" as CLOSED? This will change its status but keep all data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close Loan')),
        ],
      ),
    );
    if (confirm == true) {
      final updated = _currentLoan.copyWith(status: LoanStatus.closed, remainingMonths: 0);
      await ref.read(loanListProvider.notifier).updateLoan(updated);
      setState(() => _currentLoan = updated);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Loan marked as Closed.')));
    }
  }

  Future<void> _exportPdf(AsyncValue<List<Emi>> emisAsync) async {
    final emis = emisAsync.asData?.value ?? [];
    try {
      final pdf = pw.Document();
      final loan = _currentLoan;
      final paidEmis = emis.where((e) => e.status == EmiStatus.paid).toList();
      final totalPaid = paidEmis.fold(0.0, (s, e) => s + e.amount);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(level: 0, child: pw.Text('LoanMate – Loan Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 12),
          pw.Text('Loan: ${loan.loanName}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Lender: ${loan.lenderName}'),
          pw.Text('Type: ${loan.loanType}'),
          pw.Text('Principal: ${AppUtils.formatCurrency(loan.loanAmount)}'),
          pw.Text('EMI: ${AppUtils.formatCurrency(loan.emiAmount)} / month'),
          pw.Text('Tenure: ${loan.totalMonths} months'),
          pw.Text('Interest Rate: ${loan.interestRate}% p.a.'),
          pw.Text('Status: ${loan.status.name.toUpperCase()}'),
          pw.Text('Start Date: ${AppUtils.formatDate(loan.startDate)}'),
          pw.SizedBox(height: 16),
          pw.Text('Total Paid: ${AppUtils.formatCurrency(totalPaid)}'),
          pw.Text('Remaining: ${AppUtils.formatCurrency((loan.emiAmount * loan.remainingMonths))}'),
          pw.SizedBox(height: 20),
          pw.Text('EMI Schedule', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Due Date', 'Amount', 'Status', 'Payment Date'],
            data: emis.map((e) => [
              '${e.emiNumber}',
              AppUtils.formatDate(e.dueDate),
              AppUtils.formatCurrency(e.amount),
              e.status.name.toUpperCase(),
              e.paymentDate != null ? AppUtils.formatDate(e.paymentDate!) : '-',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ));

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/loan_${loan.loanName.replaceAll(' ', '_')}_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(file.path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to ${file.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    }
  }
}
