import 'dart:ui';

import 'package:flutter/material.dart';
import 'motion.dart';

/// Rewaq identity tokens. Navy leads; gold is reserved for emphasis.
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors(this.values);
  final Map<String, Color> values;
  Color get bg => values['bg']!;
  Color get surface => values['surface']!;
  Color get glass => values['surfaceGlass']!;
  Color get line => values['line']!;
  Color get ink => values['ink']!;
  Color get muted => values['muted']!;
  Color get primary => values['primary']!;
  Color get primaryHover => values['primaryHover']!;
  Color get primaryInk => values['primaryInk']!;
  Color get primaryTint => values['primaryTint']!;
  Color get primarySoft => values['primarySoft']!;
  Color get focus => values['focus']!;
  Color get info => values['info']!;
  Color get infoTint => values['infoTint']!;
  Color get goldText => values['goldText']!;
  Color get accent => values['accent']!;
  Color get accentText => values['accentText']!;
  Color get accentTint => values['accentTint']!;
  Color get success => values['success']!;
  Color get successTint => values['successTint']!;
  Color get warning => values['warning']!;
  Color get warningTint => values['warningTint']!;
  Color get danger => values['danger']!;
  Color get dangerTint => values['dangerTint']!;
  Color get overlay => values['overlay']!;
  Color get skeleton => values['skeleton']!;
  static const primaryHoverFixed = Color(0xff17375e);
  static const primaryTintFixed = Color(0xffeaf1ff);
  static const darkPrimaryFixed = Color(0xffc9a24a);
  static const darkSurfaceFixed = Color(0xff0e1b2c);
  static const successFixed = Color(0xff0e7a5a);
  static const whiteMuted = Color(0xb3ffffff),
      whiteFaint = Color(0x61ffffff),
      whiteSubtle = Color(0x1fffffff);
  static const nightOverlay = Color(0x730b2540), nightDense = Color(0xdf0b2540);
  static const transparent = Color(0x000b2540);
  static const white = Color(0xffffffff);
  static const night = Color(0xff0b2540);
  static const gold = Color(0xffc9a24a);
  static const navyDoor = Color(0xff17375e);
  static const link = Color(0xff1d5bf0);
  static const onNavyMuted = Color(0xffbcd0fb);
  static const light = BrandColors({
    'goldText': Color(0xff8a6a1f),
    'bg': Color(0xfff4f8fc),
    'surface': white,
    'surfaceGlass': Color(0xe0ffffff),
    'line': Color(0xffe1e9f2),
    'ink': night,
    'muted': Color(0xff526b84),
    'primary': night,
    'primaryHover': Color(0xff17375e),
    'primaryInk': white,
    'primaryTint': Color(0xffe8eef6),
    'primarySoft': Color(0xffbcd0fb),
    'accent': gold,
    'accentText': Color(0xff8a6a1f),
    'accentTint': Color(0xfffaf5e8),
    'accentLight': Color(0xffd9b65e),
    'success': Color(0xff0e7a5a),
    'successHover': Color(0xff0a5f46),
    'successTint': Color(0xffe3f5ee),
    'warning': Color(0xff9a5b00),
    'warningHover': Color(0xff7a4800),
    'warningTint': Color(0xfffff3dc),
    'danger': Color(0xffb42318),
    'dangerHover': Color(0xff912018),
    'dangerTint': Color(0xfffdecea),
    'info': link,
    'infoTint': Color(0xffeaf1ff),
    'overlay': Color(0x730b2540),
    'skeleton': Color(0xffe9eff6),
    'focus': link,
    'night': night,
    'gold': gold,
  });
  static const dark = BrandColors({
    'goldText': gold,
    'bg': Color(0xff08121f),
    'surface': Color(0xff0e1b2c),
    'surfaceGlass': Color(0xdb0e1b2c),
    'line': Color(0xff1d3048),
    'ink': Color(0xffe6eef7),
    'muted': Color(0xff93a9c0),
    'primary': Color(0xffc9a24a),
    'primaryHover': Color(0xffd9b65e),
    'primaryInk': Color(0xff0b2540),
    'primaryTint': Color(0xff17375e),
    'primarySoft': Color(0xff526b84),
    'accent': Color(0xffc9a24a),
    'accentText': gold,
    'accentTint': Color(0xff302914),
    'accentLight': Color(0xffd9b65e),
    'success': Color(0xff3fc79a),
    'successHover': Color(0xff62d4ae),
    'successTint': Color(0xff0f3328),
    'warning': Color(0xfff0b44c),
    'warningHover': Color(0xfff4c670),
    'warningTint': Color(0xff3a2a0d),
    'danger': Color(0xfff2766b),
    'dangerHover': Color(0xfff59a91),
    'dangerTint': Color(0xff3d1512),
    'info': Color(0xff6a98fa),
    'infoTint': Color(0xff13254a),
    'overlay': Color(0x99000000),
    'skeleton': Color(0xff1d3048),
    'focus': Color(0xff6a98fa),
  });
  @override
  BrandColors copyWith({Map<String, Color>? values}) =>
      BrandColors(values ?? this.values);
  @override
  BrandColors lerp(covariant BrandColors? other, double t) => other == null
      ? this
      : BrandColors({
          for (final key in values.keys)
            key: Color.lerp(values[key], other.values[key] ?? values[key], t)!,
        });
}

extension BrandContext on BuildContext {
  BrandColors get brand =>
      Theme.of(this).extension<BrandColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? BrandColors.dark
          : BrandColors.light);
}

class BrandMotion {
  static const curve = Cubic(.2, .7, .2, 1);
  static Duration duration(BuildContext context, [int milliseconds = 250]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

class BrandGlass extends StatelessWidget {
  const BrandGlass({super.key, required this.child, this.radius = 24});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: ColoredBox(color: context.brand.glass, child: child),
    ),
  );
}

class BrandCard extends StatefulWidget {
  const BrandCard({
    super.key,
    this.child,
    this.color,
    this.margin,
    this.clipBehavior,
    this.shape,
  });
  final Widget? child;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  @override
  State<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<BrandCard> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Reveal(
      child: Listener(
        onPointerDown: (_) => setState(() => pressed = true),
        onPointerUp: (_) => setState(() => pressed = false),
        onPointerCancel: (_) => setState(() => pressed = false),
        child: AnimatedContainer(
          duration: BrandMotion.duration(context, 150),
          curve: BrandMotion.curve,
          transform: Matrix4.translationValues(0, pressed ? -4 : 0, 0),
          margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
          decoration: ShapeDecoration(
            color: widget.color ?? b.surface,
            shape:
                widget.shape ??
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: pressed ? b.accent : b.line),
                ),
            shadows: [
              BoxShadow(
                color: BrandColors.night.withValues(alpha: .04),
                blurRadius: pressed ? 4 : 2,
                offset: Offset(0, pressed ? 2 : 1),
              ),
              BoxShadow(
                color: (pressed ? BrandColors.night : BrandColors.night)
                    .withValues(alpha: pressed ? .16 : .06),
                blurRadius: pressed ? 40 : 24,
                offset: Offset(0, pressed ? 18 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: widget.clipBehavior ?? Clip.antiAlias,
            child: Material(
              color: widget.color ?? b.surface,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: ColoredBox(color: context.brand.glass),
    ),
  );
}

/// Architectural ornament only; the logo always uses the supplied artwork.
class BrandArchPainter extends CustomPainter {
  const BrandArchPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final arch = Path()
      ..moveTo(size.width * .08, size.height)
      ..lineTo(size.width * .08, size.height * .48)
      ..cubicTo(
        size.width * .08,
        size.height * .28,
        size.width * .28,
        size.height * .12,
        size.width * .5,
        size.height * .02,
      )
      ..cubicTo(
        size.width * .72,
        size.height * .12,
        size.width * .92,
        size.height * .28,
        size.width * .92,
        size.height * .48,
      )
      ..lineTo(size.width * .92, size.height);
    canvas.drawPath(
      arch,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant BrandArchPainter oldDelegate) =>
      color != oldDelegate.color;
}
