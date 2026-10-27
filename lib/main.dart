import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. '
      'Ejecute la aplicación con --dart-define-from-file=env.json',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(const ProviderScope(child: ClothesTrackerApp()));
}

class ClothesTrackerApp extends StatelessWidget {
  const ClothesTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clothes Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ConnectionTestPage(),
    );
  }
}

class ConnectionTestPage extends StatefulWidget {
  const ConnectionTestPage({super.key});

  @override
  State<ConnectionTestPage> createState() => _ConnectionTestPageState();
}

class _ConnectionTestPageState extends State<ConnectionTestPage> {
  late final Future<String> _resultado;

  @override
  void initState() {
    super.initState();
    _resultado = _probarConexion();
  }

  Future<String> _probarConexion() async {
    try {
      final filas = await Supabase.instance.client
          .from('garments')
          .select('id')
          .limit(1);
      return 'Conexión correcta con Supabase.\n'
          'Filas visibles sin sesión: ${filas.length} '
          '(se esperan 0 por las políticas RLS).';
    } on PostgrestException catch (e) {
      return 'Error de la base de datos: ${e.message}';
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clothes Tracker')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<String>(
            future: _resultado,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              return Text(
                snapshot.data ?? 'Sin resultado',
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
    );
  }
}