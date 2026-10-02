/// Result of `GET /food/zones/detect`.
///
/// Out-of-coverage is still HTTP 200 with `status: "OUT_OF_SERVICE"` — always
/// branch on [isInService], never on the status code.
class ZoneModel {
  final String status;
  final String? zoneId;
  final String? name;

  const ZoneModel({required this.status, this.zoneId, this.name});

  bool get isInService => status == 'IN_SERVICE' && (zoneId?.isNotEmpty ?? false);

  static const ZoneModel unknown = ZoneModel(status: 'UNKNOWN');

  factory ZoneModel.fromApi(Map<String, dynamic> json) {
    final zone = json['zone'];
    return ZoneModel(
      status: (json['status'] ?? 'UNKNOWN').toString(),
      zoneId: json['zoneId']?.toString(),
      name: zone is Map ? (zone['zoneName'] ?? zone['name'])?.toString() : null,
    );
  }
}

/// A serviceable zone configured in the admin panel.
///
/// Used when listing all available zones so the user can manually pick their
/// delivery area rather than relying solely on GPS auto-detection.
class ServiceableZone {
  final String id;
  final String name;
  final String? city;
  final String? description;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const ServiceableZone({
    required this.id,
    required this.name,
    this.city,
    this.description,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  /// Whether this zone has coordinates we can navigate to.
  bool get hasCoordinates => latitude != null && longitude != null;

  factory ServiceableZone.fromApi(Map<String, dynamic> json) {
    // Coordinates may be in a nested location/coordinates GeoJSON or flat lat/lng.
    double? lat;
    double? lng;

    final loc = json['location'];
    if (loc is Map) {
      final coords = loc['coordinates'];
      if (coords is List && coords.length >= 2) {
        // GeoJSON: [lng, lat]
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      } else {
        lat = (loc['latitude'] as num?)?.toDouble();
        lng = (loc['longitude'] as num?)?.toDouble();
      }
    }

    lat ??= (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble();
    lng ??= (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble();

    final id = (json['_id'] ?? json['id'] ?? json['zoneId'] ?? '').toString();
    final name = (json['zoneName'] ?? json['name'] ?? json['title'] ?? '').toString();
    final city = (json['city'] ?? json['area'] ?? json['region'] ?? '').toString();
    final desc = (json['description'] ?? '').toString();
    final isActive = json['isActive'] != false && json['status']?.toString() != 'inactive';

    return ServiceableZone(
      id: id,
      name: name.isNotEmpty ? name : 'Zone $id',
      city: city.isNotEmpty ? city : null,
      description: desc.isNotEmpty ? desc : null,
      latitude: lat,
      longitude: lng,
      isActive: isActive,
    );
  }
}
