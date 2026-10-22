import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single native input preserves SMS autofill, paste and deletion semantics.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(changed);
    widget.controller.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    focus.removeListener(changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('رمز التحقق', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: FormField<String>(
            validator: (_) =>
                RegExp(r'^[0-9]{6}$').hasMatch(widget.controller.text)
                ? null
                : 'اكتب رمز التحقق المكوّن من ٦ أرقام',
            builder: (state) => Column(
              children: [
                SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          label: 'رمز التحقق، ستة أرقام',
                          child: TextField(
                            key: const ValueKey('otp-input'),
                            controller: widget.controller,
                            focusNode: focus,
                            enabled: widget.enabled,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              TextInputFormatter.withFunction((old, next) {
                                const arabic = '٠١٢٣٤٥٦٧٨٩',
                                    persian = '۰۱۲۳۴۵۶۷۸۹';
                                final normalized = next.text
                                    .split('')
                                    .map(
                                      (c) => arabic.contains(c)
                                          ? '${arabic.indexOf(c)}'
                                          : persian.contains(c)
                                          ? '${persian.indexOf(c)}'
                                          : c,
                                    )
                                    .join();
                                return TextEditingValue(
                                  text: normalized,
                                  selection: TextSelection.collapsed(
                                    offset: normalized.length,
                                  ),
                                );
                              }),
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            showCursor: false,
                            enableInteractiveSelection: true,
                            style: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 1,
                            ),
                            cursorColor: Colors.transparent,
                            decoration: const InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => state.didChange(v),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Row(
                              children: List.generate(6, (index) {
                                final value = widget.controller.text;
                                final active =
                                    focus.hasFocus &&
                                    (index == value.length ||
                                        value.length == 6 && index == 5);
                                return Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: EdgeInsets.only(
                                      right: index == 5 ? 0 : 8,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? colors.primaryContainer.withValues(
                                              alpha: .35,
                                            )
                                          : colors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: state.hasError
                                            ? colors.error
                                            : active
                                            ? colors.primary
                                            : colors.outlineVariant,
                                        width: active ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      index < value.length ? value[index] : '—',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                        color: index < value.length
                                            ? colors.onSurface
                                            : colors.outlineVariant,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
