// lib/widgets/milk_entry_dialog.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

class MilkEntryDialog extends StatefulWidget {
  final String animalId;
  final String earTag;
  final String breed;
  final String name; // ✅ NEW: animal name
  final double currentMorning;
  final double currentMidday;
  final double currentEvening;
  final Future<void> Function(double morning, double midday, double evening) onSave;
  final Future<void> Function()? onDelete;

  const MilkEntryDialog({
    super.key,
    required this.animalId,
    required this.earTag,
    required this.breed,
    required this.name, // ✅ required
    required this.currentMorning,
    required this.currentMidday,
    required this.currentEvening,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<MilkEntryDialog> createState() => _MilkEntryDialogState();
}

class _MilkEntryDialogState extends State<MilkEntryDialog> {
  late TextEditingController _morningController;
  late TextEditingController _middayController;
  late TextEditingController _eveningController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _morningController = TextEditingController(
      text: widget.currentMorning > 0 ? widget.currentMorning.toStringAsFixed(1) : '',
    );
    _middayController = TextEditingController(
      text: widget.currentMidday > 0 ? widget.currentMidday.toStringAsFixed(1) : '',
    );
    _eveningController = TextEditingController(
      text: widget.currentEvening > 0 ? widget.currentEvening.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _morningController.dispose();
    _middayController.dispose();
    _eveningController.dispose();
    super.dispose();
  }

  double _getDoubleValue(TextEditingController controller) {
    if (controller.text.isEmpty) return 0.0;
    return double.tryParse(controller.text) ?? 0.0;
  }

  Future<void> _save() async {
    final morning = _getDoubleValue(_morningController);
    final midday = _getDoubleValue(_middayController);
    final evening = _getDoubleValue(_eveningController);

    if (morning < 0 || midday < 0 || evening < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Values cannot be negative')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.onSave(morning, midday, evening);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (widget.onDelete == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete the milk record for ${widget.name}?'), // ✅ uses name
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.onDelete!();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecord = widget.currentMorning > 0 || widget.currentMidday > 0 || widget.currentEvening > 0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header – now shows name prominently
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name, // ✅ show animal name
                        style: const TextStyle(
                          fontSize: AppFontSizes.medium,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Ear Tag: #${widget.earTag} · ${widget.breed}', // ✅ includes ear tag & breed
                        style: const TextStyle(
                          fontSize: AppFontSizes.small,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Morning
            const Text(
              '🌅 Morning (Litres)',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _morningController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'L',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Midday
            const Text(
              '☀️ Midday (Litres)',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _middayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'L',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Evening
            const Text(
              '🌙 Evening (Litres)',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _eveningController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'L',
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Buttons
            Row(
              children: [
                if (hasRecord && widget.onDelete != null) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _delete,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  flex: hasRecord && widget.onDelete != null ? 1 : 2,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: hasRecord && widget.onDelete != null ? 1 : 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}