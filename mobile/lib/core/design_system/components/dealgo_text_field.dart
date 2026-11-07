import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

/// Labelled form field from the mockups: label above, white r12 input,
/// leading icon, inline validation after first interaction.
class DealGoTextField extends StatefulWidget {
  const DealGoTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
    this.errorText,
    this.fieldKey,
    this.textCapitalization = TextCapitalization.none,
    this.requiredMark = false,
    this.obscureToggleKey,
    this.showLabel = true,
    this.textAlign = TextAlign.start,
    this.scrollPadding = const EdgeInsets.all(20.0),
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  /// Password-style field with a show/hide toggle.
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final FocusNode? focusNode;

  /// Server-side error to show under the field (e.g. wrong password).
  final String? errorText;

  /// Key forwarded to the inner [TextFormField] (tests use it for enterText).
  final Key? fieldKey;
  final TextCapitalization textCapitalization;
  final bool requiredMark;

  /// Key for the show/hide password toggle (tests).
  final Key? obscureToggleKey;

  /// Hide the visual label (it stays as the field's semantics label).
  final bool showLabel;

  /// Text alignment inside the field (e.g. center for amount/OTP-style inputs).
  final TextAlign textAlign;

  /// Padding around the field when scrolling it into view on focus.
  final EdgeInsets scrollPadding;

  @override
  State<DealGoTextField> createState() => _DealGoTextFieldState();
}

class _DealGoTextFieldState extends State<DealGoTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    Widget? suffix = widget.suffix;
    if (widget.obscure) {
      suffix = IconButton(
        key: widget.obscureToggleKey,
        tooltip: _hidden ? l10n.fieldShowPassword : l10n.fieldHidePassword,
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? DealGoIcons.visibility : DealGoIcons.visibilityOff,
          size: 20,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
            child: Text.rich(
              TextSpan(
                text: widget.label,
                children: [
                  if (widget.requiredMark)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: DealGoColors.danger),
                    ),
                ],
              ),
              style: textTheme.labelMedium,
            ),
          ),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          enableSuggestions: !widget.obscure,
          autocorrect: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          textAlign: widget.textAlign,
          scrollPadding: widget.scrollPadding,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint ?? (widget.showLabel ? null : widget.label),
            helperText: widget.helper,
            errorText: widget.errorText,
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
