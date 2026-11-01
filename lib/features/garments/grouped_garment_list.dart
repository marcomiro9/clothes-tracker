import 'package:flutter/material.dart';

import '../../models/garment.dart';

class GroupedGarmentList extends StatelessWidget {
  const GroupedGarmentList({
    super.key,
    required this.garments,
    required this.itemBuilder,
    required this.emptyMessage,
    this.header,
  });

  final List<Garment> garments;
  final Widget Function(BuildContext context, Garment garment) itemBuilder;
  final String emptyMessage;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (garments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }

    final theme = Theme.of(context);
    final children = <Widget>[?header];

    for (final category in GarmentCategory.values) {
      final items = garments.where((g) => g.category == category).toList();
      if (items.isEmpty) continue;

      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '${category.label} (${items.length})',
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ));
      children.addAll(items.map((g) => itemBuilder(context, g)));
    }

    // El margen inferior evita que el botón flotante tape el último elemento.
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: children,
    );
  }
}