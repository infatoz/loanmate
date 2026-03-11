import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../providers/loan_provider.dart';
import '../utils/app_utils.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  const AddLoanScreen({super.key});

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

  bool _isCalculating = false;

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
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final tenure = int.tryParse(_tenureController.text) ?? 0;

    if (amount > 0 && tenure > 0) {
      final calculatedEmi = AppUtils.calculateEMI(amount, rate, tenure);
      setState(() {
        _emiController.text = calculatedEmi.toStringAsFixed(2);
      });
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
        _dueDay = picked.day; // Default due day to start date day
      });
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isCalculating = true);

    try {
      final amount = double.parse(_amountController.text);
      final rate = double.tryParse(_rateController.text) ?? 0.0;
      final tenure = int.parse(_tenureController.text);
      final emiAmount = double.parse(_emiController.text);

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
        remainingMonths: tenure, // Initially, remaining equals total
        startDate: _startDate,
        dueDayOfMonth: _dueDay,
        notes: _notesController.text,
        status: LoanStatus.active,
        createdAt: DateTime.now(),
      );

      // Save Loan
      await ref.read(loanListProvider.notifier).addLoan(loan);

      // Generate EMIs
      final List<Emi> generatedEmis = [];
      DateTime nextDueDate = DateTime(_startDate.year, _startDate.month, _dueDay);
      // If start date is same as due date and it has passed for the first month, we usually start from next month
      // For simplicity, we just generate monthly from start
      for (int i = 1; i <= tenure; i++) {
        // Increment month by i
        DateTime dueDate = DateTime(nextDueDate.year, nextDueDate.month + i, nextDueDate.day);
        
        generatedEmis.add(Emi(
          id: const Uuid().v4(),
          loanId: loanId,
          emiNumber: i,
          dueDate: dueDate,
          amount: emiAmount,
          status: EmiStatus.pending,
        ));
      }

      await ref.read(databaseHelperProvider).insertEmis(generatedEmis);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Loan added successfully!')),
         );
         Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding loan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Loan'),
      ),
      body: _isCalculating 
        ? const Center(child: CircularProgressIndicator())
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _loanNameController,
                decoration: const InputDecoration(labelText: 'Loan Title (e.g., Car Loan)'),
                validator: (val) => val == null || val.isEmpty ? 'Please enter loan title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lenderController,
                decoration: const InputDecoration(labelText: 'Lender / Bank Name'),
                validator: (val) => val == null || val.isEmpty ? 'Please enter lender name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _loanType,
                decoration: const InputDecoration(labelText: 'Loan Type'),
                items: _loanTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _loanType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Loan Amount (Principal)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateEmi(),
                validator: (val) => val == null || val.isEmpty ? 'Please enter amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(labelText: 'Interest Rate (% p.a.)'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateEmi(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _tenureController,
                      decoration: const InputDecoration(labelText: 'Tenure (Months)'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateEmi(),
                      validator: (val) => val == null || val.isEmpty ? 'Enter tenure' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emiController,
                decoration: InputDecoration(
                  labelText: 'Monthly EMI Amount',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate),
                    onPressed: _calculateEmi,
                    tooltip: 'Calculate EMI',
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Enter EMI amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Start Date'),
                        child: Text(AppUtils.formatDate(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                       initialValue: _dueDay,
                       decoration: const InputDecoration(labelText: 'Due Day'),
                       items: List.generate(31, (index) => index + 1).map((day) {
                         return DropdownMenuItem(value: day, child: Text(day.toString()));
                       }).toList(),
                       onChanged: (val) {
                         if (val != null) setState(() => _dueDay = val);
                       },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveLoan,
                child: const Text('Save Loan & Generate EMIs'),
              ),
            ],
          ),
        ),
    );
  }
}
