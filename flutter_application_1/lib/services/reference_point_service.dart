import 'dart:convert';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/http_service.dart';
import 'package:latlong2/latlong.dart';

class ReferencePointService {
  final HttpService _httpService;
  
  // Cache para puntos de referencia
  final Map<String, dynamic> _pointsCache = {};

  ReferencePointService(this._httpService);

  // Obtener un punto de referencia por ID
  Future<Map<String, dynamic>> getReferencePointById(String id) async {
    // Comprobar si ya tenemos el punto en caché
    if (_pointsCache.containsKey(id)) {
      return _pointsCache[id];
    }

    try {
      final response = await _httpService.get('${ApiConstants.baseUrl}/api/referencePoints/$id');
      final data = await _httpService.parseJsonResponse(response);
      
      // Guardar en caché
      _pointsCache[id] = data;
      
      return data;
    } catch (e) {
      print('Error obteniendo punto de referencia: $e');
      throw Exception('No se pudo cargar el punto de referencia');
    }
  }

  // Obtener múltiples puntos de referencia por sus IDs
  Future<List<Map<String, dynamic>>> getReferencePointsByIds(List<String> ids) async {
    final results = <Map<String, dynamic>>[];
    
    for (var id in ids) {
      try {
        final point = await getReferencePointById(id);
        results.add(point);
      } catch (e) {
        print('Error obteniendo punto $id: $e');
        // Continuamos con el siguiente punto
      }
    }
    
    return results;
  }

  // Convertir puntos de referencia a coordenadas LatLng para el mapa
  List<LatLng> convertToLatLng(List<Map<String, dynamic>> referencePoints) {
    return referencePoints.map((point) {
      return LatLng(
        point['latitude'] ?? 0,
        point['longitude'] ?? 0,
      );
    }).toList();
  }

  // Obtener LatLng directamente para una lista de IDs de puntos de referencia
  Future<List<LatLng>> getRoutePoints(List<String> routeIds) async {
    try {
      final points = await getReferencePointsByIds(routeIds);
      return convertToLatLng(points);
    } catch (e) {
      print('Error obteniendo puntos de ruta: $e');
      return [];
    }
  }
}