import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/emi.dart';
import '../models/loan.dart';
import '../utils/app_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'instant_notifications',
      'Instant Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleEmiReminder(Loan loan, Emi emi) async {
    final dueDate = emi.dueDate;
    final formattedAmount = AppUtils.formatCurrency(emi.amount);
    
    // Create notifications for 3 days before, 1 day before, and on the due date
    await _scheduleNotification(
      id: emi.id.hashCode + 3, // Unique ID for 3 days before
      title: 'Upcoming EMI Reminder',
      body: 'Your $formattedAmount EMI for ${loan.loanName} is due in 3 days on ${AppUtils.formatDate(dueDate)}.',
      scheduledDate: dueDate.subtract(const Duration(days: 3)),
    );

    await _scheduleNotification(
      id: emi.id.hashCode + 1, // Unique ID for 1 day before
      title: 'EMI Due Tomorrow',
      body: 'Your $formattedAmount EMI for ${loan.loanName} is due tomorrow.',
      scheduledDate: dueDate.subtract(const Duration(days: 1)),
    );

    await _scheduleNotification(
      id: emi.id.hashCode, // Unique ID for due date
      title: 'EMI Due Today!',
      body: 'Reminder: Your $formattedAmount EMI for ${loan.loanName} is due today.',
      scheduledDate: dueDate,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Only schedule if the date is in the future
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Set time to 10:00 AM
    final scheduleTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      10, 0, 0,
    );

    if (scheduleTime.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduleTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emi_reminders',
      'EMI Reminders',
      channelDescription: 'Notifications for upcoming EMI payments',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelEmiReminders(Emi emi) async {
    await flutterLocalNotificationsPlugin.cancel(emi.id.hashCode + 3);
    await flutterLocalNotificationsPlugin.cancel(emi.id.hashCode + 1);
    await flutterLocalNotificationsPlugin.cancel(emi.id.hashCode);
  }
  
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
