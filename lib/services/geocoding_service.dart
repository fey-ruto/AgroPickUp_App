import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class GeocodingService {
  Future<GeocodingResult?> geocodeCollectionPoint({
    required String pointName,
    required String address,
    String? region,
  }) async {
    final queryParts = <String>[
      pointName.trim(),
      address.trim(),
      if (region != null && region.trim().isNotEmpty) region.trim(),
      'Ghana',
    ]..removeWhere((part) => part.isEmpty);

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': queryParts.join(', '),
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '1',
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'AgroPickupGH/1.0 (collection-point-geocoding)',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final first = decoded.first;
    if (first is! Map<String, dynamic>) return null;

    final latitude = double.tryParse('${first['lat']}');
    final longitude = double.tryParse('${first['lon']}');
    final displayName = '${first['display_name'] ?? ''}'.trim();

    if (latitude == null || longitude == null) return null;

    return GeocodingResult(
      latitude: latitude,
      longitude: longitude,
      displayName: displayName,
    );
  }
}
