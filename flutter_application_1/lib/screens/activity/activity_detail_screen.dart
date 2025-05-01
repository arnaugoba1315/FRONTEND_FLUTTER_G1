import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/activity.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Activity activity;

  const ActivityDetailScreen({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determinar el tipo de actividad y colores asociados
    String activityTypeText;
    IconData activityIcon;
    Color activityColor;

    switch (activity.type) {
      case ActivityType.running:
        activityTypeText = 'Carrera';
        activityIcon = Icons.directions_run;
        activityColor = Colors.green;
        break;
      case ActivityType.cycling:
        activityTypeText = 'Ciclismo';
        activityIcon = Icons.directions_bike;
        activityColor = Colors.blue;
        break;
      case ActivityType.walking:
        activityTypeText = 'Caminata';
        activityIcon = Icons.directions_walk;
        activityColor = Colors.purple;
        break;
      case ActivityType.hiking:
        activityTypeText = 'Senderismo';
        activityIcon = Icons.terrain;
        activityColor = Colors.orange;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.name),
        backgroundColor: activityColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen visual (header)
            Container(
              color: activityColor,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityTypeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                activityIcon,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm').format(activity.startTime),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Añadir botón para compartir, editar, etc.
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () {
                          // Función para compartir actividad
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compartir actividad (función pendiente)')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tarjetas con estadísticas principales
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estadísticas principales
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Distancia',
                          activity.formatDistance(),
                          Icons.straighten,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Tiempo',
                          activity.formatDuration(),
                          Icons.timer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Ritmo Medio',
                          _calculatePace(),
                          Icons.speed,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Detalles de la actividad
                  const Text(
                    'Detalles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildDetailRow('Inicio', DateFormat('dd/MM/yyyy HH:mm:ss').format(activity.startTime)),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Fin', DateFormat('dd/MM/yyyy HH:mm:ss').format(activity.endTime)),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Duración', activity.formatDuration()),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Distancia', activity.formatDistance()),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Velocidad Media', '${(activity.averageSpeed * 3.6).toStringAsFixed(1)} km/h'),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Desnivel Positivo', '${activity.elevationGain.toStringAsFixed(0)} m'),
                  const Divider(height: 1),
                  
                  _buildDetailRow('Calorías', activity.caloriesBurned != null 
                      ? '${activity.caloriesBurned!.toStringAsFixed(0)} kcal' 
                      : 'No disponible'),
                  
                  const SizedBox(height: 24),
                  
                  // Mapa de la ruta (si hay puntos de ruta)
                  if (activity.route.isNotEmpty) ...[
                    const Text(
                      'Ruta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _buildRouteMap(),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap() {
    // Simulación de puntos de ruta
    // En una implementación real, habría que convertir los puntos de ruta de activity.route
    // a una lista de LatLng para mostrar la ruta real en el mapa
    
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: FlutterMap(
        options: MapOptions(
          center: LatLng(41.3851, 2.1734), // Barcelona por defecto
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  // Puntos de ejemplo (en una implementación real estos vendrían de activity.route)
                  LatLng(41.3851, 2.1734),
                  LatLng(41.3901, 2.1854),
                  LatLng(41.3921, 2.1834),
                  LatLng(41.3951, 2.1934),
                ],
                color: Colors.blue,
                strokeWidth: 3.0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Calcular ritmo en minutos por kilómetro
  String _calculatePace() {
    if (activity.distance <= 0 || activity.duration <= 0) {
      return '--:--';
    }
    
    // Convertir a minutos por kilómetro
    final paceInMinutes = (activity.duration / 60) / (activity.distance / 1000);
    final minutes = paceInMinutes.floor();
    final seconds = ((paceInMinutes - minutes) * 60).round();
    
    return '$minutes:${seconds.toString().padLeft(2, '0')} min/km';
  }
}