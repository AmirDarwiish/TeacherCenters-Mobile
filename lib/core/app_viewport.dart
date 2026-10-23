import 'package:flutter/material.dart';

/// Protect every route. Descendant SafeAreas see consumed insets, avoiding duplication.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: child,
    ),
  );
}
