import 'package:flutter/material.dart';

/// Original supplied artwork; never typeset, redraw or mirror the wordmark.
class RewaqLogo extends StatelessWidget {
  const RewaqLogo({
    super.key,
    this.size = 64,
    this.wordmark = true,
    this.inverse = false,
    this.stacked = false,
  });

  final double size;
  final bool wordmark, inverse, stacked;

  @override
  Widget build(BuildContext context) {
    final reversed = inverse || Theme.of(context).brightness == Brightness.dark;
    final variant = reversed ? 'reverse' : 'primary';
    final layout = stacked ? 'stacked' : 'horizontal';
    final small = !wordmark && size < 40;
    final asset = wordmark
        ? 'rewaq-logo-$layout-$variant-1024.png'
        : small && !reversed
        ? 'rewaq-mark-small-128.png'
        : 'rewaq-mark-$variant-512.png';
    // The horizontal lockup must be at least 120px wide.
    final height = wordmark && !stacked && size < 64 ? 64.0 : size;
    final ratio = wordmark
        ? (stacked ? 1024 / 2117 : 1024 / 546)
        : (small && !reversed ? 32 / 41 : 512 / 663);
    return Semantics(
      label: 'رواق',
      image: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/brand/$asset',
          height: height,
          width: height * ratio,
          fit: BoxFit.contain,
          matchTextDirection: false,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
