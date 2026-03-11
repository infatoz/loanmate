import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../providers/loan_provider.dart';
import '../providers/emi_provider.dart';
import '../database/database_helper.dart';
import '../utils/app_utils.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final Loan? existingLoan; // If set, we're editing
  const AddLoanScreen({super.key, this.existingLoan});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();

  final _lenderController = TextEditingController();
  final _loanNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _emiController = TextEditingController();
  final _notesController = TextEditingController();

  String _loanType = 'Personal';
  DateTime _startDate = DateTime.now();
  int _dueDay = 1;

  final List<String> _loanTypes = ['Personal', 'Home', 'Auto', 'Education', 'Business', 'Other'];
  bool _isSaving = false;
  bool get _isEditing => widget.existingLoan != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    final loan = widget.existingLoan;
    if (loan != null) {
      _lenderController.text = loan.lenderName;
      _loanNameController.text = loan.loanName;
      _amountController.text = loan.loanAmount > 0 ? loan.loanAmount.toString() : '';
      _rateController.text = loan.interestRate > 0 ? loan.interestRate.toString() : '';
      _tenureController.text = loan.totalMonths.toString();
      _emiController.text = loan.emiAmount.toString();
      _notesController.text = loan.notes;
      _loanType = loan.loanType;
      _startDate = loan.startDate;
      _dueDay = loan.dueDayOfMonth;
    } else {
      _dueDay = DateTime.now().day;
    }
  }

  @override
  void dispose() {
    _lenderController.dispose();
    _loanNameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateEmi() {
    final emi = double.tryParse(_emiController.text);
    final tenure = int.tryParse(_tenureController.text);

    if (emi != null && tenure != null) {
      final loanAmount = emi * tenure;
      _amountController.text = loanAmount.toStringAsFixed(2);
    } else {
      _amountController.clear();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _dueDay = picked.day;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final rate = double.tryParse(_rateController.text) ?? 0.0;
      final tenure = int.tryParse(_tenureController.text) ?? 0;
      final emiAmount = double.tryParse(_emiController.text) ?? 0.0;

      if (_isEditing) {
        // --- UPDATE LOAN ---
        final updatedLoan = widget.existingLoan!.copyWith(
          lenderName: _lenderController.text,
          loanName: _loanNameController.text,
          loanType: _loanType,
          loanAmount: amount,
          emiAmount: emiAmount,
          interestRate: rate,
          totalMonths: tenure,
          startDate: _startDate,
          dueDayOfMonth: _dueDay,
          notes: _notesController.text,
        );
        await ref.read(loanListProvider.notifier).updateLoan(updatedLoan);

        // Regenerate unpaid EMIs to reflect new tenure / amounts
        final db = DatabaseHelper.instance;
        await db.deleteUnpaidEmisForLoan(updatedLoan.id);
        final existingEmis = await db.getEmisForLoan(updatedLoan.id);
        final int paidCount = existingEmis.where((e) => e.status == EmiStatus.paid).length;

        if (tenure > paidCount) {
          final List<Emi> newEmis = [];
          for (int i = paidCount + 1; i <= tenure; i++) {
            final dueDate = DateTime(_startDate.year, _startDate.month + i, _dueDay);
            newEmis.add(Emi(
              id: const Uuid().v4(),
              loanId: updatedLoan.id,
              emiNumber: i,
              dueDate: dueDate,
              amount: emiAmount,
              status: EmiStatus.pending,
            ));
          }
          await db.insertEmis(newEmis);
        }

        ref.invalidate(allEmisProvider);
        ref.invalidate(emisForLoanProvider(updatedLoan.id));
        ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan updated!')));
          Navigator.pop(context, updatedLoan);
        }
      } else {
        // --- ADD LOAN ---
        final loanId = const Uuid().v4();
        final loan = Loan(
          id: loanId,
          lenderName: _lenderController.text,
          loanName: _loanNameController.text,
          loanType: _loanType,
          loanAmount: amount,
          emiAmount: emiAmount,
          interestRate: rate,
          totalMonths: tenure,
          remainingMonths: tenure,
          startDate: _startDate,
          dueDayOfMonth: _dueDay,
          notes: _notesController.text,
          status: LoanStatus.active,
          createdAt: DateTime.now(),
        );

        await ref.read(loanListProvider.notifier).addLoan(loan);

        // Generate EMIs
        final List<Emi> generatedEmis = [];
        for (int i = 1; i <= tenure; i++) {
          final dueDate = DateTime(_startDate.year, _startDate.month + i, _dueDay);
          generatedEmis.add(Emi(
            id: const Uuid().v4(),
            loanId: loanId,
            emiNumber: i,
            dueDate: dueDate,
            amount: emiAmount,
            status: EmiStatus.pending,
          ));
        }
        await DatabaseHelper.instance.insertEmis(generatedEmis);
        // Refresh providers
        ref.invalidate(allEmisProvider);
        ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan added & EMI schedule generated!')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Loan' : 'Add New Loan'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _sectionHeader(context, 'Basic Information', Icons.info_outline),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _loanNameController,
                    decoration: const InputDecoration(labelText: 'Loan Title *', hintText: 'e.g. Car Loan'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lenderController,
                    decoration: const InputDecoration(labelText: 'Lender / Bank Name', hintText: 'Optional'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _loanType,
                    decoration: const InputDecoration(labelText: 'Loan Type'),
                    items: _loanTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) { if (val != null) setState(() => _loanType = val); },
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(context, 'Financial Details', Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 4),
                  // Helper text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Enter EMI directly, or fill Amount + Rate + Tenure to auto-calculate.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Loan Amount (Calculated)', hintText: 'Auto-fills based on EMI * Tenure'),
                    readOnly: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rateController,
                          decoration: const InputDecoration(labelText: 'Interest Rate (% p.a.)', hintText: 'Optional'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _calculateEmi(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _tenureController,
                          decoration: const InputDecoration(labelText: 'Tenure (Months) *'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _calculateEmi(),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emiController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly EMI Amount (₹) *',
                      hintText: 'Enter EMI amount',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _calculateEmi(),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(context, 'Schedule', Icons.calendar_today_outlined),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              suffixIcon: Icon(Icons.edit_calendar),
                            ),
                            child: Text(AppUtils.formatDate(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _dueDay,
                          decoration: const InputDecoration(labelText: 'EMI Due Day'),
                          items: List.generate(28, (i) => i + 1)
                              .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                              .toList(),
                          onChanged: (val) { if (val != null) setState(() => _dueDay = val); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes (Optional)', hintText: 'Any additional info...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: Icon(_isEditing ? Icons.save : Icons.add_circle_outline),
                    label: Text(_isEditing ? 'Update Loan' : 'Save & Generate EMI Schedule'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.primary.withValues(alpha: 0.3))),
      ],
    );
  }
}
