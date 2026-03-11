import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/emi_provider.dart';
import '../models/emi.dart';
import '../utils/app_utils.dart';
import '../core/app_colors.dart';

class EmiCalendarScreen extends ConsumerStatefulWidget {
  const EmiCalendarScreen({super.key});

  @override
  ConsumerState<EmiCalendarScreen> createState() => _EmiCalendarScreenState();
}

class _EmiCalendarScreenState extends ConsumerState<EmiCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Emi>> _emisByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // We fetch EMIs via provider
  }

  void _groupEmis(List<Emi> emis) {
    _emisByDate.clear();
    for (var emi in emis) {
      final date = DateTime(emi.dueDate.year, emi.dueDate.month, emi.dueDate.day);
      if (_emisByDate[date] == null) {
        _emisByDate[date] = [];
      }
      _emisByDate[date]!.add(emi);
    }
  }

  List<Emi> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _emisByDate[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final allEmisAsync = ref.watch(allEmisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () {
              // Navigate to Calculator
            },
          )
        ],
      ),
      body: allEmisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (emis) {
          _groupEmis(emis);
            
          return Column(
            children: [
              TableCalendar<Emi>(
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2050, 3, 14),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                    return Positioned(
                      right: 1,
                      bottom: 1,
                      child: _buildEventsMarker(events),
                    );
                  },
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildEventList(_getEventsForDay(_selectedDay!)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventsMarker(List<Emi> events) {
    // Check status to determine color
    bool hasOverdue = events.any((e) => e.status == EmiStatus.overdue);
    bool hasPending = events.any((e) => e.status == EmiStatus.pending);

    Color markerColor = Colors.green;
    if (hasOverdue) {
      markerColor = Colors.red;
    } else if (hasPending) {
      markerColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: markerColor),
      width: 14.0,
      height: 14.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle(color: Colors.white, fontSize: 10.0),
        ),
      ),
    );
  }

  Widget _buildEventList(List<Emi> events) {
    if (events.isEmpty) {
      return const Center(child: Text('No EMIs scheduled for this date.'));
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final emi = events[index];
        final isOverdue = emi.status == EmiStatus.overdue;
        final isPaid = emi.status == EmiStatus.paid;

        return ListTile(
          leading: Icon(
            isPaid ? Icons.check_circle : (isOverdue ? Icons.warning : Icons.schedule),
            color: isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
          ),
          title: Text(AppUtils.formatCurrency(emi.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Status: ${emi.status.name.toUpperCase()}'),
          trailing: isPaid ? const Text('Paid') : ElevatedButton(
             onPressed: () {},
             child: const Text('Pay'),
          ),
        );
      },
    );
  }
}
