import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final sessionProvider = Provider<SessionController>((ref) {
  final controller = SessionController(ref.watch(supabaseProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

class SessionController extends ChangeNotifier {
  SessionController(this._client) {
    // El stream emite un evento inicial (initialSession) al suscribirse,
    // por lo que no hace falta una carga explícita en el constructor.
    _sub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed) return;
      reloadProfile();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  bool _loading = true;
  bool _disposed = false;
  Profile? _profile;

  bool get isLoading => _loading;
  bool get isSignedIn => _client.auth.currentSession != null;
  Profile? get profile => _profile;
  bool get hasPair => _profile?.pairId != null;

  Future<void> reloadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _profile = null;
      _loading = false;
      _notify();
      return;
    }

    _loading = true;
    _notify();
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      _profile = row == null ? null : Profile.fromMap(row);
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}