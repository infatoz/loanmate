import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'reports_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark themes'),
            value: themeMode == ThemeMode.dark,
            onChanged: (val) {
              ref.read(themeProvider.notifier).toggleTheme();
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          const ListTile(
            title: Text('Data & Tools', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart),
            title: const Text('Financial Reports'),
            subtitle: const Text('View detailed analytics and charts'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Data'),
            subtitle: const Text('Save your database locally'),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Backup created successfully!')),
               );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Data'),
            subtitle: const Text('Restore from a local backup file'),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Select backup file to restore...')),
               );
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('About', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
