// ===========================================
// lib/widgets/role_selection_dialog.dart
// ===========================================
// Shared dialog widget for selecting user role during registration or login.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

/// A reusable role selection dialog with a dropdown and continue button.
class RoleSelectionDialog extends StatefulWidget {
  final Function(String) onRoleSelected;
  final List<String> roles;

  const RoleSelectionDialog({
    super.key,
    required this.onRoleSelected,
    required this.roles,
  });

  @override
  State<RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<RoleSelectionDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.roles.isNotEmpty ? widget.roles.first : '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Makes dialog overlay transparent
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Your Role',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: widget.roles.map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRoleSelected(_selectedRole);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
