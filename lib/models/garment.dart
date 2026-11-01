enum GarmentCategory {
  ropaInterior('ropa_interior', 'Ropa interior'),
  remeras('remeras', 'Remeras'),
  pantalones('pantalones', 'Pantalones'),
  buzos('buzos', 'Buzos'),
  abrigos('abrigos', 'Abrigos'),
  calzado('calzado', 'Calzado'),
  accesorios('accesorios', 'Accesorios'),
  otros('otros', 'Otros');

  const GarmentCategory(this.dbValue, this.label);

  /// Valor del enum `garment_category` en PostgreSQL.
  final String dbValue;

  /// Texto que se muestra en la interfaz.
  final String label;

  static GarmentCategory fromDb(String value) => values.firstWhere(
        (c) => c.dbValue == value,
        orElse: () => GarmentCategory.otros,
      );
}

class Garment {
  const Garment({
    required this.id,
    required this.ownerId,
    required this.pairId,
    required this.name,
    required this.category,
    required this.atPartnerHome,
    this.color,
  });

  final String id;
  final String ownerId;
  final String pairId;
  final String name;
  final GarmentCategory category;
  final bool atPartnerHome;
  final String? color;

  factory Garment.fromMap(Map<String, dynamic> map) => Garment(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        pairId: map['pair_id'] as String,
        name: map['name'] as String,
        category: GarmentCategory.fromDb(map['category'] as String),
        atPartnerHome: map['at_partner_home'] as bool,
        color: map['color'] as String?,
      );
}