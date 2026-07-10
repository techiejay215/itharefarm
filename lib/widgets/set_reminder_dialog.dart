// lib/widgets/set_reminder_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class SetReminderDialog extends StatefulWidget {
  final String? animalName;
  final String? animalId;

  const SetReminderDialog({super.key, this.animalName, this.animalId});

  @override
  State<SetReminderDialog> createState() => _SetReminderDialogState();
}

class _SetReminderDialogState extends State<SetReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.animalName != null
          ? 'Reminder for ${widget.animalName}'
          : 'Set General Reminder'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Reminder Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Reminder Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final title = widget.animalName != null
                  ? 'Reminder for ${widget.animalName}'
                  : 'General Reminder';
              final message = _notesController.text.isNotEmpty
                  ? _notesController.text
                  : 'Reminder set for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}';
              await FirestoreService().addNotification({
                'title': title,
                'message': message,
                'type': widget.animalId != null ? 'animal_reminder' : 'general_reminder',
                'is_read': false,
              });
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder set successfully')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}