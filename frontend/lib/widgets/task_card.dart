import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(task.status),
                  backgroundColor: _getStatusColor(task.status),
                ),
              ],
            ),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(task.description!),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (task.dueDate != null)
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                if (task.dueDate != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    task.dueDate!.toString().split(' ')[0],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                if (task.riskScore != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRiskColor(task.riskScore!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Risk: ${(task.riskScore! * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.7) return Colors.red;
    if (risk > 0.4) return Colors.orange;
    return Colors.green;
  }
}

