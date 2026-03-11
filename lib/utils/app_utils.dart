import 'package:intl/intl.dart';

class AppUtils {
  static final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String formatCurrency(double amount) {
    return currencyFormat.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
  
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }
  
  // Calculate EMI amounts based on:
  // EMI = P × R × (1+R)^N / ((1+R)^N − 1)
  // where P = Principal amount, R = Monthly interest rate, N = Tenure in months
  static double calculateEMI(double principal, double annualInterestRate, int tenureMonths) {
    if (annualInterestRate == 0) return principal / tenureMonths;
    if (tenureMonths == 0) return principal;

    double monthlyRate = annualInterestRate / 12 / 100;
    // (1+R)^N
    double onePlusRN = 1.0;
    for (int i = 0; i < tenureMonths; i++) {
      onePlusRN *= (1 + monthlyRate);
    }
    
    double emi = principal * monthlyRate * onePlusRN / (onePlusRN - 1);
    return emi;
  }
}
