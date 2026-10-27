import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. '
      'Ejecute con --dart-define-from-file=env.json',
    );
  }

    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const ProviderScope(child: ClothesTrackerApp()));
}

class ClothesTrackerApp extends ConsumerWidget {
  const ClothesTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Clothes Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}