import 'dart:io';
import 'package:flutter/foundation.dart';
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
    debugPrint('PiP Service: enterPipMode called');
    if (!Platform.isAndroid) {
      debugPrint('PiP Service: Not Android, returning false');
      return false;
    }

    try {
      debugPrint('PiP Service: Invoking enterPipMode method channel...');
      final bool? result = await _channel.invokeMethod('enterPipMode');
      debugPrint('PiP Service: Method channel returned: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('PiP Service: Error calling enterPipMode: $e');
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
