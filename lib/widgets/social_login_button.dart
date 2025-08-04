// ===========================================
// lib/widgets/social_login_button.dart
// ===========================================
// Button for social login (Google, Facebook, etc.) with icon or image.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/constants.dart';

/// Button for social login (Google, Facebook, etc.) with icon or image.
class SocialLoginButton extends StatelessWidget {
  /// The button label text.
  final String text;
  /// The icon to display if no image is provided.
  final IconData? icon;
  /// The asset path for the image to display.
  final String? imagePath;
  /// The background color of the button.
  final Color backgroundColor;
  /// The text color of the button.
  final Color textColor;
  /// Callback when the button is pressed.
  final VoidCallback onPressed;

  /// Creates a [SocialLoginButton].
  const SocialLoginButton({
    super.key,
    required this.text,
    this.icon,
    this.imagePath,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 2,
          // ignore: deprecated_member_use
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
            side:
                backgroundColor == Colors.white
                    // ignore: deprecated_member_use
                    ? BorderSide(color: Colors.grey.withOpacity(0.3))
                    : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show image if imagePath is provided and not empty, otherwise show icon
            if (imagePath != null && imagePath!.isNotEmpty)
              Image.asset(
                imagePath!,
                width: AppConstants.socialIconSize,
                height: AppConstants.socialIconSize,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to icon if image fails to load
                  return Icon(icon ?? Icons.login, size: AppConstants.socialIconSize, color: textColor);
                },
              )
            else if (icon != null)
              Icon(icon, size: AppConstants.socialIconSize, color: textColor),
            const SizedBox(width: AppConstants.socialIconSpacing),
            Text(
              text,
              style: TextStyle(
                fontSize: AppConstants.buttonFontSize,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
