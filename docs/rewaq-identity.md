# هوية رواق

المرجع: دليل الهوية وملفات الشعار التي قدّمها صاحب التطبيق.

- الكحلي `#0B2540`، الباب `#17375E`، الدهبي `#C9A24A`.
- الفاتح: primary كحلي وكلام أبيض. الغامق: primary دهبي وكلام كحلي.
- العناوين: Alexandria 600/700. النصوص: IBM Plex Sans Arabic 400/500/600، مضمّنة محليًا.
- الاسم العربي والإنجليزي داخل الصور الأصلية، ولا يُكتبان كبديل للشعار.
- الهيدر يستخدم القفل الأفقي الأصلي بعرض لا يقل عن 120px؛ شاشة البداية تستخدم الرأسي المعكوس.
- الاسم الظاهر رواق؛ معرّفات الحزمة والتطبيق باقية لحماية مسار التحديث والجلسات.
- النص المعتمد: «إدارة دروسك كلها من مكان واحد».
- لا نعرض وعود حضور أو رسائل تلقائية غير متاحة فعليًا.

الأصول الأصلية داخل `assets/brand/`. لإعادة توليد مقاسات أيقونات وشاشات البداية من الأصول:

```sh
python3 -m pip install Pillow
python3 tool/generate_brand_assets.py
```

التحقق:

```sh
flutter analyze
flutter test
flutter test --dart-define=SCREENSHOTS=true test/rewaq_test.dart test/course_experience_test.dart
flutter build web --dart-define=TENANT_SLUG=teachercenter-demo
```
