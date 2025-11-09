import 'package:flutter/material.dart';

/// Animation duration constants for consistent timing throughout the app
class AppDurations {
  AppDurations._();

  /// Fast animations (150ms) - micro-interactions, button presses
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal animations (250ms) - default for most transitions
  static const Duration normal = Duration(milliseconds: 250);

  /// Slow animations (400ms) - modals, page transitions
  static const Duration slow = Duration(milliseconds: 400);

  /// Recording button animation
  static const Duration recordingButton = Duration(milliseconds: 220);

  /// Recording button inner animation
  static const Duration recordingButtonInner = Duration(milliseconds: 180);

  /// Pulse animation for recording state
  static const Duration pulse = Duration(milliseconds: 1500);

  /// Page transition duration
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// List item animation stagger
  static const Duration stagger = Duration(milliseconds: 100);
}

/// Spacing constants for consistent layout throughout the app
class AppSpacing {
  AppSpacing._();

  /// Extra small spacing (4px)
  static const double xs = 4;

  /// Small spacing (8px)
  static const double sm = 8;

  /// Medium spacing (12px)
  static const double md = 12;

  /// Large spacing (16px)
  static const double lg = 16;

  /// Extra large spacing (24px)
  static const double xl = 24;

  /// Extra extra large spacing (32px)
  static const double xxl = 32;

  /// Extra extra extra large spacing (48px)
  static const double xxxl = 48;
}

/// Animation curve constants
class AppCurves {
  AppCurves._();

  /// Elastic out curve for bouncy feel
  static const Curve elasticOut = Curves.elasticOut;

  /// Ease out cubic - smooth deceleration
  static const Curve easeOutCubic = Curves.easeOutCubic;

  /// Ease in out - standard Material curve
  static const Curve easeInOut = Curves.easeInOut;

  /// Ease out back - slight overshoot
  static const Curve easeOutBack = Curves.easeOutBack;

  /// Material motion curve
  static const Curve materialMotion = Cubic(0.4, 0.0, 0.2, 1.0);
}
