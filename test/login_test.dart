import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_centers_mobile/core/api.dart';
import 'package:teacher_centers_mobile/features/login.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets(
    'Arabic login switches between student OTP and teacher password',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ar')],
          home: LoginPage(api: Api()),
        ),
      );
      expect(find.text('إرسال رمز التحقق'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsNothing);
      await tester.tap(find.text('مدرس'));
      await tester.pumpAndSettle();
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('دخول المدرس'), findsOneWidget);
    },
  );
}
