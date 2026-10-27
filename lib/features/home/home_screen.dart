import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session_controller.dart';

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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).profile!;
    final info = ref.watch(pairInfoProvider);

    return Scaffold(
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: info.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (data) => data.partnerName != null
                ? Text('Vinculado con ${data.partnerName}.',
                    style: Theme.of(context).textTheme.titleLarge)
                : Column(
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
                          Clipboard.setData(
                              ClipboardData(text: data.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado')));
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}