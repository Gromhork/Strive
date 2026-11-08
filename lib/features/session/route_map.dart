import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/sport.dart';
import '../../data/models.dart';

/// Static map of a recorded route.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final pts = session.route.map((p) => LatLng(p[0], p[1])).toList();
    if (pts.length < 2) return const SizedBox.shrink();
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(28)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.gromhork.strive'),
        PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 4.5, color: session.sport.color)]),
        MarkerLayer(
          markers: [
            Marker(point: pts.first, width: 14, height: 14, child: const _Dot(Colors.green)),
            Marker(point: pts.last, width: 14, height: 14, child: const _Dot(Colors.red)),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
  );
}
