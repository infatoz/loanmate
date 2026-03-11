import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/emi_provider.dart';
import '../models/emi.dart';
import '../utils/app_utils.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'emi_calculator_screen.dart';

class EmiCalendarScreen extends ConsumerStatefulWidget {
  const EmiCalendarScreen({super.key});

  @override
  ConsumerState<EmiCalendarScreen> createState() => _EmiCalendarScreenState();
}

class _EmiCalendarScreenState extends ConsumerState<EmiCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Emi>> _emisByDate = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _groupEmis(List<Emi> emis) {
    _emisByDate.clear();
    for (var emi in emis) {
      final date = DateTime.utc(emi.dueDate.year, emi.dueDate.month, emi.dueDate.day);
      _emisByDate.putIfAbsent(date, () => []).add(emi);
    }
  }

  List<Emi> _getEventsForDay(DateTime day) {
    return _emisByDate[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final allEmisAsync = ref.watch(allEmisProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'EMI Calculator',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmiCalculatorScreen())),
          ),
        ],
      ),
      body: allEmisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (emis) {
          _groupEmis(emis);

          // Summary counts
          final paid = emis.where((e) => e.status == EmiStatus.paid).length;
          final pending = emis.where((e) => e.status == EmiStatus.pending).length;
          final overdue = emis.where((e) => e.status == EmiStatus.overdue).length;

          return Column(
            children: [
              // Legend strip
              Container(
                color: cs.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendDot('Paid ($paid)', Colors.green),
                    _legendDot('Pending ($pending)', Colors.orange),
                    _legendDot('Overdue ($overdue)', Colors.red),
                  ],
                ),
              ),
              Card(
                margin: const EdgeInsets.all(8),
                child: TableCalendar<Emi>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2050, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (format) => setState(() => _calendarFormat = format),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: _getEventsForDay,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();
                      bool hasOverdue = events.any((e) => e.status == EmiStatus.overdue);
                      bool hasPending = events.any((e) => e.status == EmiStatus.pending);
                      Color markerColor;
                      if (hasOverdue) {
                        markerColor = Colors.red;
                      } else if (hasPending) {
                        markerColor = Colors.orange;
                      } else {
                        markerColor = Colors.green;
                      }
                      return Positioned(
                        bottom: 2,
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle),
                        ),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(formatButtonVisible: true, titleCentered: true),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: Colors.transparent),
                  ),
                ),
              ),
              Expanded(
                child: _buildEventList(_getEventsForDay(_selectedDay ?? _focusedDay)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legendDot(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _buildEventList(List<Emi> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No EMIs on this date', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final emi = events[index];
        final isPaid = emi.status == EmiStatus.paid;
        final isOverdue = emi.status == EmiStatus.overdue;
        final Color statusColor = isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(isPaid ? Icons.check : (isOverdue ? Icons.warning_amber : Icons.schedule), color: statusColor, size: 20),
            ),
            title: Text(AppUtils.formatCurrency(emi.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMI #${emi.emiNumber}'),
                if (isPaid && emi.paymentDate != null)
                  Text('Paid on ${AppUtils.formatDate(emi.paymentDate!)}', style: const TextStyle(color: Colors.green, fontSize: 11)),
              ],
            ),
            trailing: isPaid
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                    child: const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => _markAsPaid(emi),
                    child: const Text('Pay'),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _markAsPaid(Emi emi) async {
    final updated = emi.copyWith(status: EmiStatus.paid, paymentDate: DateTime.now(), paymentMethod: 'Manual');
    await DatabaseHelper.instance.updateEmi(updated);
    await NotificationService().cancelEmiReminders(emi);
    ref.invalidate(allEmisProvider);
    ref.read(upcomingEmiProvider.notifier).loadUpcomingEmis();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ EMI marked as Paid!')));
  }
}
