import 'package:dale_u/core/theme/look_kind.dart';
import 'package:flutter/material.dart';

/// Piel activa. [LookViewModel] la cambia; las pantallas leen estos getters.
final class VendorLook {
  const VendorLook._();

  static LookKind _kind = LookKind.bakery;

  static void apply(LookKind kind) => _kind = kind;

  static LookKind get kind => _kind;

  static bool get isBakery => _kind == LookKind.bakery;

  static const titleSize = 22.0;
  static const subtitleSize = 16.0;
  static const bodySize = 16.0;
  static const buttonLabelSize = 17.0;
  static const buttonHeight = 48.0;
  static const iconSize = 22.0;

  static const compactTitleSize = 18.0;
  static const compactSubtitleSize = 14.0;
  static const compactBodySize = 14.0;
  static const compactButtonLabelSize = 15.0;
  static const compactButtonHeight = 40.0;
  static const compactIconSize = 18.0;

  static _Palette get _p =>
      isBakery ? _Palette.bakery : _Palette.classic;

  static Color get background => _p.background;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get surface => _p.surface;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;
  static Color get danger => _p.danger;
  static Color get border => _p.border;
  static Color get wheat => _p.wheat;
  static Color get route => _p.route;
  static Color get disabledAccent => _p.disabledAccent;
  static Color get shadow => _p.shadow;

  static double get radius => isBakery ? 20 : 12;
  static double get buttonRadius => isBakery ? 24 : 12;
  static double get cardElevation => isBakery ? 1.5 : 0;

  static BorderSide get cardBorder {
    if (isBakery) return BorderSide(color: wheat, width: 1);
    return BorderSide(color: border, width: 2);
  }

  static BorderSide get thickBorder {
    if (isBakery) return BorderSide(color: wheat, width: 1);
    return BorderSide(color: border, width: 2.5);
  }

  static BorderSide get buttonSide {
    if (isBakery) return BorderSide.none;
    return BorderSide(color: border, width: 2);
  }

  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: cardBorder,
  );

  static TextStyle get title => TextStyle(
    fontSize: titleSize,
    fontWeight: FontWeight.w800,
    color: ink,
    height: 1.2,
  );

  static TextStyle get subtitle => TextStyle(
    fontSize: subtitleSize,
    fontWeight: FontWeight.w600,
    color: muted,
  );

  static TextStyle get body => TextStyle(
    fontSize: bodySize,
    color: muted,
    height: 1.3,
  );

  static TextStyle get dangerText => TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w700,
    color: danger,
  );

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: onAccent,
        secondary: route,
        onSecondary: onAccent,
        surface: surface,
        onSurface: ink,
        error: danger,
        onError: onAccent,
      ),
    );
  }
}

final class _Palette {
  const _Palette({
    required this.background,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.border,
    required this.wheat,
    required this.route,
    required this.disabledAccent,
    required this.shadow,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color surface;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color border;
  final Color wheat;
  final Color route;
  final Color disabledAccent;
  final Color shadow;

  /// El original: negro, borde duro, crema.
  static const classic = _Palette(
    background: Color(0xFFFFFBEA),
    ink: Color(0xFF111111),
    muted: Color(0xFF2A2A2A),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF111111),
    onAccent: Color(0xFFFFFBEA),
    danger: Color(0xFF8B0000),
    border: Color(0xFF111111),
    wheat: Color(0xFF111111),
    route: Color(0xFF111111),
    disabledAccent: Color(0xFF4A4A4A),
    shadow: Color(0x00000000),
  );

  /// Cálido: café oscuro para leer, oliva solo en "en ruta".
  static const bakery = _Palette(
    background: Color(0xFFFDFBF7),
    ink: Color(0xFF2C1810),
    muted: Color(0xFF5C4033),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF4A2C11),
    onAccent: Color(0xFFFDFBF7),
    danger: Color(0xFF8B0000),
    border: Color(0xFF4A2C11),
    wheat: Color(0xFFE4D4BC),
    route: Color(0xFF5F6D3E),
    disabledAccent: Color(0xFF8D6E63),
    shadow: Color(0x294A2C11),
  );
}

enum VendorButtonTone { accent, route }

enum VendorControlSize { regular, compact }

/// Misma paleta que el vendedor, letras y botones más chicos.
final class BuyerLook {
  const BuyerLook._();

  static TextStyle get title => TextStyle(
    fontSize: VendorLook.compactTitleSize,
    fontWeight: FontWeight.w800,
    color: VendorLook.ink,
    height: 1.2,
  );

  static TextStyle get subtitle => VendorLook.subtitle.copyWith(
    fontSize: VendorLook.compactSubtitleSize,
  );

  static TextStyle get body => VendorLook.body.copyWith(
    fontSize: VendorLook.compactBodySize,
  );

  static TextStyle get dangerText => VendorLook.dangerText.copyWith(
    fontSize: VendorLook.compactBodySize,
  );
}

class VendorSurface extends StatelessWidget {
  const VendorSurface({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final box = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Material(
      color: VendorLook.surface,
      elevation: VendorLook.cardElevation,
      shadowColor: VendorLook.shadow,
      shape: VendorLook.cardShape,
      clipBehavior: Clip.antiAlias,
      child: box,
    );
  }
}

class VendorPrimaryButton extends StatelessWidget {
  const VendorPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.tone = VendorButtonTone.accent,
    this.size = VendorControlSize.regular,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final VendorButtonTone tone;
  final VendorControlSize size;

  bool get _compact => size == VendorControlSize.compact;

  @override
  Widget build(BuildContext context) {
    final fill = tone == VendorButtonTone.route
        ? VendorLook.route
        : VendorLook.accent;
    final labelSize = _compact
        ? VendorLook.compactButtonLabelSize
        : VendorLook.buttonLabelSize;
    final iconSize = _compact
        ? VendorLook.compactIconSize
        : VendorLook.iconSize;
    final height = _compact
        ? VendorLook.compactButtonHeight
        : VendorLook.buttonHeight;
    final child = busy
        ? SizedBox(
            width: _compact ? 18 : 22,
            height: _compact ? 18 : 22,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: VendorLook.onAccent,
            ),
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w800,
              color: VendorLook.onAccent,
            ),
          );

    final style = FilledButton.styleFrom(
      backgroundColor: fill,
      disabledBackgroundColor: VendorLook.disabledAccent,
      foregroundColor: VendorLook.onAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
        side: VendorLook.buttonSide,
      ),
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: icon == null || busy
          ? FilledButton(
              onPressed: busy ? null : onPressed,
              style: style,
              child: child,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(
                icon,
                size: iconSize,
                color: VendorLook.onAccent,
              ),
              label: child,
            ),
    );
  }
}

class VendorSecondaryButton extends StatelessWidget {
  const VendorSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = VendorControlSize.regular,
  });

  final String label;
  final VoidCallback? onPressed;
  final VendorControlSize size;

  @override
  Widget build(BuildContext context) {
    final compact = size == VendorControlSize.compact;
    return SizedBox(
      height: compact
          ? VendorLook.compactButtonHeight
          : VendorLook.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VendorLook.ink,
          side: VendorLook.thickBorder,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact
                ? VendorLook.compactButtonLabelSize
                : VendorLook.buttonLabelSize,
            fontWeight: FontWeight.w800,
            color: VendorLook.ink,
          ),
        ),
      ),
    );
  }
}

class VendorTextAction extends StatelessWidget {
  const VendorTextAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: VendorLook.ink,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class VendorDangerButton extends StatelessWidget {
  const VendorDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = VendorControlSize.regular,
  });

  final String label;
  final VoidCallback? onPressed;
  final VendorControlSize size;

  @override
  Widget build(BuildContext context) {
    final compact = size == VendorControlSize.compact;
    return SizedBox(
      height: compact
          ? VendorLook.compactButtonHeight
          : VendorLook.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VendorLook.danger,
          side: BorderSide(
            color: VendorLook.danger,
            width: VendorLook.isBakery ? 1.5 : 2.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact
                ? VendorLook.compactButtonLabelSize
                : VendorLook.buttonLabelSize,
            fontWeight: FontWeight.w800,
            color: VendorLook.danger,
          ),
        ),
      ),
    );
  }
}
