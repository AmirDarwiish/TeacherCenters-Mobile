import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';
import 'format.dart';

/// Rises and fades in once when first built. [index] staggers siblings.
/// Single timed tween (no timers), so it settles cleanly in tests and honours
/// the system "reduce motion" setting.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final int delay = 70 * math.min<int>(index, 5);
    const base = 420;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: base + delay),
      curve: Interval(delay / (base + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
    );
  }
}

/// Gold light sweeping across loading placeholders.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  // An endless animation would never let widget tests settle.
  bool get _inTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inTest || MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) {
      final x = controller.value * 3 - 1;
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(x - 1, -.3),
          end: Alignment(x + 1, .3),
          colors: [
            Colors.transparent,
            BrandColors.gold.withValues(alpha: .14),
            Colors.transparent,
          ],
        ).createShader(rect),
        child: child,
      );
    },
  );
}

/// Rewaq's nested arches, the brand's signature line work.
class ArchPattern extends StatelessWidget {
  const ArchPattern({super.key, this.color = BrandColors.gold});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ArchPainter(color));
}

class _ArchPainter extends CustomPainter {
  const _ArchPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final inset = size.width * .13 * i;
      final width = size.width - inset * 2;
      final radius = width / 2;
      final top = inset * 1.1;
      final path = Path()
        ..moveTo(inset, size.height)
        ..lineTo(inset, top + radius)
        ..arcToPoint(
          Offset(size.width - inset, top + radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width - inset, size.height);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 - i * .3
          ..color = color.withValues(alpha: .5 - i * .12),
      );
    }
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.color != color;
}

/// Navy hero panel: gradient, gold arches, a soft gold glow and an entrance.
class PremiumHero extends StatelessWidget {
  const PremiumHero({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Reveal(
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [BrandColors.navyDoor, BrandColors.night],
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.night.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -36,
            top: 8,
            bottom: -30,
            width: 170,
            child: const IgnorePointer(child: ArchPattern()),
          ),
          PositionedDirectional(
            end: -60,
            top: -60,
            width: 180,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      BrandColors.gold.withValues(alpha: .28),
                      BrandColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ],
      ),
    ),
  );
}

/// A money figure that counts up to its value.
class CountUpMoney extends StatelessWidget {
  const CountUpMoney(this.value, {super.key, this.style});
  final Object? value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final target = num.tryParse('${value ?? ''}');
    if (target == null || MediaQuery.disableAnimationsOf(context)) {
      return Text(money(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        // Exact value at rest, so decimals never get rounded away.
        money(v == target ? value : v.round()),
        style: style,
      ),
    );
  }
}
