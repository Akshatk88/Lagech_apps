class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String type; // 'Home', 'Office', 'Other'
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;

  // Backend fields — the order payload needs the raw parts and GeoJSON, while
  // the saved-address DTO takes flat latitude/longitude. The server converts.
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  const AddressModel({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.type,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
  });

  /// Maps `GET/POST /food/user/addresses`. The response carries every
  /// coordinate representation at once (latitude/longitude, lat/lng, location).
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    final parts = [
      json['street'],
      json['additionalDetails'],
      json['city'],
      json['state'],
      json['zipCode'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

    return AddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['label'] ?? 'Home').toString(),
      fullAddress: parts.join(', '),
      type: (json['label'] ?? 'Home').toString(),
      isDefault: json['isDefault'] as bool? ?? false,
      contactPhone: json['phone']?.toString(),
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Body for POST/PATCH /food/user/addresses (flat coordinates).
  Map<String, dynamic> toApiPayload() => {
        'label': title,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        if (contactPhone != null) 'phone': contactPhone,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  /// Body for the order payload's `address` (GeoJSON `[lng, lat]`).
  Map<String, dynamic> toOrderPayload({String? customerName}) => {
        'label': title,
        'name': ?customerName,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        if (contactPhone != null) 'phone': contactPhone,
        if (latitude != null && longitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fullAddress': fullAddress,
        'type': type,
        'isDefault': isDefault,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Home',
        fullAddress: json['fullAddress'] as String? ?? '',
        type: json['type'] as String? ?? 'Home',
        isDefault: json['isDefault'] as bool? ?? false,
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        street: json['street'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        zipCode: json['zipCode'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  AddressModel copyWith({
    String? id,
    String? title,
    String? fullAddress,
    String? type,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) {
    return AddressModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
