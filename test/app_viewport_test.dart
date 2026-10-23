import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/app_viewport.dart';
import 'package:teacher_centers_mobile/core/design.dart';

void main() {
  Widget app({
    required EdgeInsets padding,
    EdgeInsets keyboard = EdgeInsets.zero,
    bool footer = false,
  }) => MaterialApp(
    theme: appTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(padding: padding, viewPadding: padding, viewInsets: keyboard),
      child: AppViewport(child: child!),
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('صفحة تجريبية')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 40,
              itemBuilder: (context, i) => ListTile(title: Text('عنصر $i')),
            ),
          ),
          if (!footer)
            Builder(
              builder: (context) => FilledButton(
                key: const ValueKey('action'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: FilledButton(
                          key: const ValueKey('detail-action'),
                          onPressed: () {},
                          child: const Text('حفظ التفاصيل'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('فتح التفاصيل'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: footer
          ? SafeArea(
              top: false,
              child: SizedBox(
                key: const ValueKey('footer'),
                height: 60,
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('تأكيد'),
                ),
              ),
            )
          : null,
    ),
  );

  for (final bottom in [0.0, 24.0, 34.0]) {
    testWidgets(
      'last content and pushed detail stay above bottom inset $bottom',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          app(padding: EdgeInsets.only(top: 24, bottom: bottom)),
        );
        await tester.pumpAndSettle();
        final safeBottom = bottom > 12 ? bottom : 12.0;
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('action'))).dy,
          lessThanOrEqualTo(844 - safeBottom),
        );
        await tester.scrollUntilVisible(find.text('عنصر 39'), 300);
        expect(
          tester.getBottomLeft(find.text('عنصر 39')).dy,
          lessThan(844 - safeBottom),
        );
        await tester.tap(find.byKey(const ValueKey('action')));
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('detail-action'))).dy,
          lessThanOrEqualTo(844 - safeBottom),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('existing safe footer consumes bottom inset only once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(padding: const EdgeInsets.only(bottom: 34), footer: true),
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byKey(const ValueKey('footer'))).dy, 810);
    expect(tester.getSize(find.byKey(const ValueKey('footer'))).height, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard inset remains available to resize the scaffold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        padding: EdgeInsets.zero,
        keyboard: const EdgeInsets.only(bottom: 300),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('action'))).dy,
      lessThanOrEqualTo(544),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape side cutouts are kept clear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(padding: const EdgeInsets.fromLTRB(44, 0, 44, 21)),
    );
    await tester.pumpAndSettle();
    final scaffold = tester.getRect(find.byType(Scaffold));
    expect(scaffold.left, 44);
    expect(scaffold.right, 800);
    expect(scaffold.bottom, 369);
    expect(tester.takeException(), isNull);
  });
}
