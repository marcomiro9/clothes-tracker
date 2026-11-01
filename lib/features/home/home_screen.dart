import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/session_controller.dart';
import '../../models/garment.dart';
import '../garments/garment_form_sheet.dart';
import '../garments/garment_repository.dart';
import '../garments/grouped_garment_list.dart';

class PairInfo {
  const PairInfo({required this.inviteCode, this.partnerName});
  final String inviteCode;
  final String? partnerName;
}

final pairInfoProvider = FutureProvider.autoDispose<PairInfo>((ref) async {
  final client = ref.watch(supabaseProvider);
  final me = ref.watch(sessionProvider).profile!;

  final pair = await client
      .from('pairs')
      .select('invite_code')
      .eq('id', me.pairId!)
      .single();

  final members = await client
      .from('profiles')
      .select('id, display_name')
      .eq('pair_id', me.pairId!);

  final partner = members
      .where((m) => m['id'] != me.id)
      .map((m) => m['display_name'] as String)
      .firstOrNull;

  return PairInfo(
    inviteCode: pair['invite_code'] as String,
    partnerName: partner,
  );
});

/// Ejecuta una operación sobre la base y muestra el error, si lo hay.
Future<void> _runWithFeedback(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).profile!;
    final pairInfo = ref.watch(pairInfoProvider);
    final garments = ref.watch(garmentsProvider);

    final partnerName = pairInfo.when(
      data: (p) => p.partnerName,
      loading: () => null,
      error: (_, _) => null,
    );
    final partnerLabel = partnerName ?? 'la pareja';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Hola, ${me.displayName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: () => ref.invalidate(pairInfoProvider),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () => ref.read(supabaseProvider).auth.signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Mis prendas'), Tab(text: 'En mi casa')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Agregar prenda'),
          onPressed: () => _addGarment(context, ref, me.pairId!, partnerLabel),
        ),
        body: garments.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Error al cargar las prendas: $e')),
          data: (all) {
            final mine = all.where((g) => g.ownerId == me.id).toList();
            final partnersHere = all
                .where((g) => g.ownerId != me.id && g.atPartnerHome)
                .toList();

            return TabBarView(
              children: [
                GroupedGarmentList(
                  garments: mine,
                  emptyMessage: 'Todavía no registró prendas.\n'
                      'Use el botón "Agregar prenda".',
                  header: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '${mine.where((g) => g.atPartnerHome).length} de '
                      '${mine.length} prendas en casa de $partnerLabel',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  itemBuilder: (ctx, g) => ListTile(
                    title: Text(g.name),
                    subtitle: g.color == null ? null : Text(g.color!),
                    trailing: Switch(
                      value: g.atPartnerHome,
                      onChanged: (v) => _runWithFeedback(
                        ctx,
                        () => ref
                            .read(garmentRepositoryProvider)
                            .setAtPartnerHome(g.id, v),
                      ),
                    ),
                    onTap: () => _editGarment(ctx, ref, g, partnerLabel),
                  ),
                ),
                partnerName == null
                    ? _InviteCodeView(pairInfo: pairInfo)
                    : GroupedGarmentList(
                        garments: partnersHere,
                        emptyMessage:
                            'No hay prendas de $partnerName en esta casa.',
                        itemBuilder: (ctx, g) => ListTile(
                          leading: const Icon(Icons.checkroom),
                          title: Text(g.name),
                          subtitle: g.color == null ? null : Text(g.color!),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addGarment(BuildContext context, WidgetRef ref,
      String pairId, String partnerLabel) async {
    final result = await showGarmentForm(context, partnerLabel: partnerLabel);
    if (result == null || !context.mounted) return;

    await _runWithFeedback(
      context,
      () => ref.read(garmentRepositoryProvider).add(
            pairId: pairId,
            name: result.name,
            category: result.category,
            color: result.color,
            atPartnerHome: result.atPartnerHome,
          ),
    );
  }

  Future<void> _editGarment(BuildContext context, WidgetRef ref,
      Garment garment, String partnerLabel) async {
    final result = await showGarmentForm(context,
        initial: garment, partnerLabel: partnerLabel);
    if (result == null || !context.mounted) return;

    final repo = ref.read(garmentRepositoryProvider);
    await _runWithFeedback(
      context,
      () => result.delete
          ? repo.delete(garment.id)
          : repo.update(
              garment.id,
              name: result.name,
              category: result.category,
              color: result.color,
              atPartnerHome: result.atPartnerHome,
            ),
    );
  }
}

class _InviteCodeView extends StatelessWidget {
  const _InviteCodeView({required this.pairInfo});

  final AsyncValue<PairInfo> pairInfo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: pairInfo.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (data) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comparta este código con su pareja:'),
              const SizedBox(height: 12),
              SelectableText(data.inviteCode,
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: data.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado')));
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuando su pareja se una, presione el ícono de actualizar.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}