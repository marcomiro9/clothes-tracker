import 'package:flutter/material.dart';

import '../../models/garment.dart';

class GarmentFormResult {
  const GarmentFormResult({
    required this.name,
    required this.category,
    required this.atPartnerHome,
    this.color,
  }) : delete = false;

  const GarmentFormResult.delete()
      : name = '',
        category = GarmentCategory.otros,
        atPartnerHome = false,
        color = null,
        delete = true;

  final String name;
  final GarmentCategory category;
  final bool atPartnerHome;
  final String? color;
  final bool delete;
}

Future<GarmentFormResult?> showGarmentForm(
  BuildContext context, {
  required String partnerLabel,
  Garment? initial,
}) {
  return showModalBottomSheet<GarmentFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        GarmentFormSheet(initial: initial, partnerLabel: partnerLabel),
  );
}

class GarmentFormSheet extends StatefulWidget {
  const GarmentFormSheet({
    super.key,
    required this.partnerLabel,
    this.initial,
  });

  final String partnerLabel;
  final Garment? initial;

  @override
  State<GarmentFormSheet> createState() => _GarmentFormSheetState();
}

class _GarmentFormSheetState extends State<GarmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initial?.name);
  late final _colorCtrl = TextEditingController(text: widget.initial?.color);
  late GarmentCategory _category =
      widget.initial?.category ?? GarmentCategory.remeras;
  late bool _atPartnerHome = widget.initial?.atPartnerHome ?? true;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final color = _colorCtrl.text.trim();
    Navigator.of(context).pop(GarmentFormResult(
      name: _nameCtrl.text.trim(),
      category: _category,
      atPartnerHome: _atPartnerHome,
      color: color.isEmpty ? null : color,
    ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: Text('¿Eliminar "${widget.initial!.name}"? '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    Navigator.of(context).pop(const GarmentFormResult.delete());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Editar prenda' : 'Nueva prenda',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nombre', hintText: 'Ej.: Remera negra lisa'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese un nombre' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GarmentCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: GarmentCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _colorCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Color (opcional)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Está en casa de ${widget.partnerLabel}'),
              value: _atPartnerHome,
              onChanged: (v) => setState(() => _atPartnerHome = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Guardar cambios' : 'Agregar'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar prenda'),
                style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
                onPressed: _confirmDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}