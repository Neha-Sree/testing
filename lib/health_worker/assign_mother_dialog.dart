import 'package:flutter/material.dart';

/// Asks the health worker for a patient ID to assign to themselves.
class AssignMotherDialog extends StatefulWidget {
  const AssignMotherDialog({super.key});

  @override
  State<AssignMotherDialog> createState() => _AssignMotherDialogState();
}

class _AssignMotherDialogState extends State<AssignMotherDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign a mother'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Patient ID (e.g. MUM12345)',
            hintText: 'MUMxxxxx',
          ),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return 'Patient ID is required';
            if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value)) {
              return 'Letters and digits only';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, _controller.text.trim().toUpperCase());
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
