import 'dart:io';
import 'package:flutter/services.dart';

/// Service to handle Picture-in-Picture mode on Android
class PipService {
  static const _channel = MethodChannel('com.porta_thoughty/pip');

  /// Check if PiP is supported on this device
  static Future<bool> isPipSupported() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool? supported = await _channel.invokeMethod('isPipSupported');
      return supported ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Enter Picture-in-Picture mode
  /// Returns true if successfully entered PiP mode
  static Future<bool> enterPipMode() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool? result = await _channel.invokeMethod('enterPipMode');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if currently in PiP mode
  static Future<bool> isInPipMode() async {
    if (!Platform.isAndroid) return false;

    try {
      final bool? inPip = await _channel.invokeMethod('isInPipMode');
      return inPip ?? false;
    } catch (e) {
      return false;
    }
  }
}
