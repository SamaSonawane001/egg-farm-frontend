import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common.dart';

enum FieldType { text, number, integer, date, multiline, select, phone }

class FieldSpec {
  final String key, label;
  final FieldType type;
  final bool required;
  final bool clearZeroOnFocus;
  final bool normalizeLeadingZeros;
  final List<MapEntry<String, String>> options; // value -> label (select)
  final String? hint;
  final String? Function(String? value, Map<String, String> values)? validator;
  const FieldSpec(this.key, this.label,
      {this.type = FieldType.text,
      this.required = true,
      this.clearZeroOnFocus = false,
      this.normalizeLeadingZeros = false,
      this.options = const [],
      this.hint,
      this.validator});
}

/// Generic add/edit dialog. Returns true when saved. `preview` is recomputed on every keystroke
/// (used for live totals such as batch cost or egg valuation).
Future<bool> showFormDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, dynamic> initial = const {},
  String Function(Map<String, String> values)? preview,
  required Future<void> Function(Map<String, String> values) onSubmit,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FormDialog(
        title: title,
        fields: fields,
        initial: initial,
        preview: preview,
        onSubmit: onSubmit),
  );
  return r == true;
}

class _FormDialog extends StatefulWidget {
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;
  final String Function(Map<String, String>)? preview;
  final Future<void> Function(Map<String, String>) onSubmit;
  const _FormDialog(
      {required this.title,
      required this.fields,
      required this.initial,
      this.preview,
      required this.onSubmit});
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _v = {}; // select + date values
  bool _saving = false;
  String? _error;

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return '$v';
  }

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final init = _str(widget.initial[f.key]);
      if (f.type == FieldType.select) {
        _v[f.key] = init.isNotEmpty
            ? init
            : (f.options.isNotEmpty ? f.options.first.key : '');
      } else if (f.type == FieldType.date) {
        _v[f.key] = init.isNotEmpty ? init : today();
        _c[f.key] = TextEditingController(text: _v[f.key]);
      } else {
        _c[f.key] = TextEditingController(text: init);
        if (f.clearZeroOnFocus) {
          final focusNode = FocusNode();
          focusNode.addListener(() {
            if (focusNode.hasFocus && _c[f.key]?.text.trim() == '0') {
              _c[f.key]!.clear();
              if (mounted) setState(() {});
            }
          });
          _focusNodes[f.key] = focusNode;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collect() => {
        for (final f in widget.fields)
          f.key: (f.type == FieldType.select || f.type == FieldType.date)
              ? (_v[f.key] ?? '')
              : (_c[f.key]?.text.trim() ?? ''),
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_collect());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  Widget _field(FieldSpec f) {
    String? req(String? s) =>
        (f.required && (s == null || s.trim().isEmpty)) ? 'Required' : null;
    switch (f.type) {
      case FieldType.select:
        return DropdownButtonFormField<String>(
          initialValue:
              f.options.any((o) => o.key == _v[f.key]) ? _v[f.key] : null,
          isExpanded: true,
          decoration: dec(context, f.label),
          items: [
            for (final o in f.options)
              DropdownMenuItem(
                  value: o.key,
                  child: Text(o.value, overflow: TextOverflow.ellipsis))
          ],
          validator: (s) =>
              (f.required && (s == null || s.isEmpty)) ? 'Required' : null,
          onChanged: (s) => setState(() => _v[f.key] = s ?? ''),
        );
      case FieldType.date:
        return TextFormField(
          controller: _c[f.key],
          readOnly: true,
          decoration:
              dec(context, f.label, icon: Icons.calendar_today_outlined),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(_v[f.key] ?? '') ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setState(() {
                _v[f.key] = DateFormat('yyyy-MM-dd').format(d);
                _c[f.key]!.text = _v[f.key]!;
              });
            }
          },
        );
      case FieldType.number:
      case FieldType.integer:
        return TextFormField(
          controller: _c[f.key],
          focusNode: _focusNodes[f.key],
          keyboardType: TextInputType.numberWithOptions(
              decimal: f.type == FieldType.number),
          decoration: dec(context, f.label,
              hint: f.hint ?? (f.type == FieldType.integer ? '0' : null)),
          onChanged: (value) {
            if (f.type == FieldType.integer &&
                f.normalizeLeadingZeros &&
                value.isNotEmpty) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed.toString() != value) {
                _c[f.key]!.value = TextEditingValue(
                  text: parsed.toString(),
                  selection:
                      TextSelection.collapsed(offset: parsed.toString().length),
                );
              }
            }
            setState(() {});
          },
          validator: (s) {
            final r = req(s);
            if (r != null) return r;
            final custom = f.validator?.call(s, _collect());
            if (custom != null) return custom;
            if (s == null || s.trim().isEmpty) return null;
            final n = f.type == FieldType.integer
                ? int.tryParse(s.trim())
                : double.tryParse(s.trim());
            return (n == null || n < 0) ? 'Enter a valid number' : null;
          },
        );
      case FieldType.multiline:
        return TextFormField(
          controller: _c[f.key],
          minLines: 2,
          maxLines: 4,
          decoration: dec(context, f.label, hint: f.hint),
          validator: req,
        );
      case FieldType.phone:
        return TextFormField(
          controller: _c[f.key],
          keyboardType: TextInputType.phone,
          decoration:
              dec(context, f.label, hint: f.hint, icon: Icons.phone_outlined),
          validator: req,
        );
      case FieldType.text:
        return TextFormField(
          controller: _c[f.key],
          decoration: dec(context, f.label, hint: f.hint),
          onChanged: (_) => setState(() {}),
          validator: req,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 96).clamp(240.0, 440.0);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: w,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 4),
              for (final f in widget.fields)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _field(f)),
              if (widget.preview != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.preview!(_collect()),
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w700)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
