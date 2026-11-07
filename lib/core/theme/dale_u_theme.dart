import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/material.dart';

/// ThemeData global. Los colores salen de [VendorLook] según la piel activa.
ThemeData daleUTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: VendorLook.background,
    colorScheme: ColorScheme.light(
      primary: VendorLook.accent,
      onPrimary: VendorLook.onAccent,
      secondary: VendorLook.route,
      onSecondary: VendorLook.onAccent,
      surface: VendorLook.surface,
      onSurface: VendorLook.ink,
      error: VendorLook.danger,
      onError: VendorLook.onAccent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: VendorLook.background,
      foregroundColor: VendorLook.ink,
      elevation: 0,
      titleTextStyle: VendorLook.title,
    ),
    dividerColor: VendorLook.wheat,
  );
}
