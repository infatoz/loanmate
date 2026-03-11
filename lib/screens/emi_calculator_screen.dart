import 'package:flutter/material.dart';
import '../utils/app_utils.dart';
import '../core/app_colors.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();

  double _emiAmount = 0.0;
  double _totalInterest = 0.0;
  double _totalPayable = 0.0;
  double _principalAmount = 0.0;

  void _calculate() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final tenure = int.tryParse(_tenureController.text) ?? 0;

    if (amount > 0 && rate > 0 && tenure > 0) {
      final emi = AppUtils.calculateEMI(amount, rate, tenure);
      final total = emi * tenure;
      final interest = total - amount;

      setState(() {
         _principalAmount = amount;
         _emiAmount = emi;
         _totalPayable = total;
         _totalInterest = interest;
      });
    } else {
      setState(() {
        _emiAmount = 0.0;
        _totalInterest = 0.0;
        _totalPayable = 0.0;
        _principalAmount = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Calculator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Loan Amount (Principal)', prefixText: '₹ '),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rateController,
                            decoration: const InputDecoration(labelText: 'Interest Rate (%)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculate(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _tenureController,
                            decoration: const InputDecoration(labelText: 'Tenure (Months)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculate(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_emiAmount > 0) ...[
              Text(
                'Monthly EMI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppUtils.formatCurrency(_emiAmount),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _resultItem(context, 'Principal', AppUtils.formatCurrency(_principalAmount), Colors.blue),
                  _resultItem(context, 'Interest', AppUtils.formatCurrency(_totalInterest), Colors.orange),
                  _resultItem(context, 'Total', AppUtils.formatCurrency(_totalPayable), AppColors.primary),
                ],
              ),
              const SizedBox(height: 24),
              // Let's add a basic visual indicator of Principal vs Interest
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                   height: 20,
                   child: Row(
                     children: [
                       Expanded(
                         flex: (_principalAmount / _totalPayable * 100).toInt(),
                         child: Container(color: Colors.blue),
                       ),
                       Expanded(
                         flex: (_totalInterest / _totalPayable * 100).toInt(),
                         child: Container(color: Colors.orange),
                       ),
                     ],
                   )
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Principal (${(_principalAmount / _totalPayable * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  Text('Interest (${(_totalInterest / _totalPayable * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _resultItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
