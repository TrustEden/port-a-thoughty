import 'package:flutter/material.dart';

/// Professional bottom sheet with smooth animations and consistent styling
class AppBottomSheet {
  // Standardized button styling constants
  static const double buttonHeight = 52.0;
  static const double buttonBorderRadius = 16.0;
  static const double buttonFontSize = 16.0;
  static const FontWeight buttonFontWeight = FontWeight.w700;

  /// Standard filled button style for consistency across all bottom sheets
  static ButtonStyle filledButtonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: buttonFontSize,
        fontWeight: buttonFontWeight,
      ),
    );
  }

  /// Standard outlined button style for consistency across all bottom sheets
  static ButtonStyle outlinedButtonStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
      ),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
      ),
      textStyle: const TextStyle(
        fontSize: buttonFontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Shows a confirmation bottom sheet with action buttons
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    IconData? icon,
    bool isDestructive = false,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmationBottomSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
      ),
    );
  }

  /// Shows a custom content bottom sheet with smooth animations
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool usePadding = true,
    EdgeInsets? padding,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomBottomSheet(
        usePadding: usePadding,
        padding: padding,
        child: child,
      ),
    );
  }
}

class _ConfirmationBottomSheet extends StatelessWidget {
  const _ConfirmationBottomSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: AppBottomSheet.outlinedButtonStyle(context),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: AppBottomSheet.filledButtonStyle(context).copyWith(
                        backgroundColor: WidgetStateProperty.all(
                          isDestructive
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          isDestructive
                              ? theme.colorScheme.onError
                              : theme.colorScheme.onPrimary,
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomBottomSheet extends StatelessWidget {
  const _CustomBottomSheet({
    required this.child,
    this.usePadding = true,
    this.padding,
  });

  final Widget child;
  final bool usePadding;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPadding = EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      left: 24,
      right: 24,
      top: 32,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: usePadding
            ? Padding(
                padding: padding ?? defaultPadding,
                child: child,
              )
            : child,
      ),
    );
  }
}
