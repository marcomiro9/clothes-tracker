import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/session_controller.dart';
import '../../models/garment.dart';

final garmentRepositoryProvider = Provider<GarmentRepository>(
  (ref) => GarmentRepository(ref.watch(supabaseProvider)),
);

/// Todas las prendas de la pareja, actualizadas en tiempo real.
final garmentsProvider = StreamProvider.autoDispose<List<Garment>>(
  (ref) => ref.watch(garmentRepositoryProvider).watchVisible(),
);

class GarmentRepository {
  GarmentRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Garment>> watchVisible() => _client
      .from('garments')
      .stream(primaryKey: ['id'])
      .order('name', ascending: true)
      .map((rows) => rows.map(Garment.fromMap).toList());

  Future<void> add({
    required String pairId,
    required String name,
    required GarmentCategory category,
    required bool atPartnerHome,
    String? color,
  }) async {
    await _client.from('garments').insert({
      'owner_id': _client.auth.currentUser!.id,
      'pair_id': pairId,
      'name': name,
      'category': category.dbValue,
      'color': color,
      'at_partner_home': atPartnerHome,
    });
  }

  Future<void> update(
    String id, {
    required String name,
    required GarmentCategory category,
    required bool atPartnerHome,
    String? color,
  }) async {
    await _client.from('garments').update({
      'name': name,
      'category': category.dbValue,
      'color': color,
      'at_partner_home': atPartnerHome,
    }).eq('id', id);
  }

  Future<void> setAtPartnerHome(String id, bool value) async {
    await _client
        .from('garments')
        .update({'at_partner_home': value}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('garments').delete().eq('id', id);
  }
}