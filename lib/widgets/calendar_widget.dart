import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedTime = DateFormat.Hm().format(now);
    final formattedDate = DateFormat.EEEE().format(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hari ini", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("$formattedDate - $formattedTime"),
            const SizedBox(height: 16),
            const Text("Kalender (Mockup)"),
          ],
        ),
      ),
    );
  }
}
