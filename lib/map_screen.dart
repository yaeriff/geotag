import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'database_helper.dart';

class MapScreen extends StatefulWidget {
  final PhotoLocation location;

  const MapScreen({super.key, required this.location});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late LatLng _photoPosition;

  @override
  void initState() {
    super.initState();
    _photoPosition = LatLng(widget.location.latitude, widget.location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lokasi Media #${widget.location.id} (OSM)"),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _photoPosition,
          initialZoom: 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.namamu.gpskameraapp', // ganti ini klo perlu
          ),

          // lapisan penanda
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: _photoPosition,
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                    Text(
                      "Media #${widget.location.id}",
                      style: const TextStyle(
                          backgroundColor: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}