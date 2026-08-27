import 'package:flutter/material.dart';

/// Global navigator key.
///
/// Required so that code running *outside* the widget tree — notification tap
/// handlers (local + OneSignal), background isolates handing work back to the
/// UI isolate, deep links — can navigate without a [BuildContext].
///
/// Wired into [MaterialApp.navigatorKey] in `main.dart`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Convenience accessor for the current navigation context.
/// Returns `null` before the first frame is rendered.
BuildContext? get appNavigatorContext => appNavigatorKey.currentContext;
