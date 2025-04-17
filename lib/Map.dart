import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:burtonaletrail_app/AppApi.dart';
import 'package:burtonaletrail_app/AppDrawer.dart';
import 'package:burtonaletrail_app/AppMenuButton.dart';
import 'package:burtonaletrail_app/LoadingScreen.dart';
import 'package:burtonaletrail_app/NavBar.dart';
import 'package:burtonaletrail_app/Pubs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rive/rive.dart' as rive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/io_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';

/// MapScreen – now with tap‑to‑open pub details in PubsScreen
class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  //──────────────────────────────────────────────────
  // Mutable state
  //──────────────────────────────────────────────────
  List<dynamic> _markers = [];
  List<LatLng> _gpxPoints = [];
  LatLng? _currentLocation;
  bool _isLoading = false;

  // Map control
  late final MapController _mapController;
  bool _mapIsReady = false; // set in onMapReady
  bool _hasMovedInitial = false; // guard so we only recentre once

  // User (if you ever need it in the greeting)
  String userName = '';
  String userImage = '';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _getCurrentLocation();
    _fetchMarkers();
    _loadGpx();
  }

  //──────────────────────────────────────────────────
  // Async data fetchers
  //──────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // Silent fallback to Burton‑on‑Trent
      setState(() => _currentLocation = const LatLng(52.828872, -1.6696312));
    } finally {
      _tryMoveMap();
    }
  }

  Future<void> _loadGpx() async {
    try {
      final raw = await rootBundle.loadString('assets/Test.gpx');
      final gpx = GpxReader().fromString(raw);
      final pts = <LatLng>[];
      for (final t in gpx.trks) {
        for (final s in t.trksegs) {
          for (final p in s.trkpts) {
            if (p.lat != null && p.lon != null) pts.add(LatLng(p.lat!, p.lon!));
          }
        }
      }
      setState(() => _gpxPoints = pts);
    } catch (e) {
      debugPrint('GPX load error: $e');
    } finally {
      _tryMoveMap();
    }
  }

  Future<void> _fetchMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    final io = IOClient(httpClient);

    setState(() => _isLoading = true);
    try {
      final resp = await io.post(
        Uri.parse(apiServerMapInformation),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'access_token': token}),
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is List) setState(() => _markers = decoded);
      }
    } catch (e) {
      debugPrint('Marker fetch error: $e');
    } finally {
      setState(() => _isLoading = false);
      _tryMoveMap();
    }
  }

  //──────────────────────────────────────────────────
  // Map logic helpers
  //──────────────────────────────────────────────────

  LatLng? _deriveInitialCentre() {
    if (_currentLocation != null) return _currentLocation;

    for (final m in _markers) {
      try {
        final lat = _parseCoord(m['latitude']);
        final lon = _parseCoord(m['longitude']);
        return LatLng(lat, lon);
      } catch (_) {}
    }
    if (_gpxPoints.isNotEmpty) return _gpxPoints.first;
    return null;
  }

  void _tryMoveMap() {
    if (!_mapIsReady || _hasMovedInitial) return;
    final centre = _deriveInitialCentre();
    if (centre == null) return;
    _mapController.move(centre, 14.5);
    _hasMovedInitial = true;
  }

  void _onPubMarkerTap(dynamic pub) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PubsScreen(initialPub: pub)),
    );
  }

  //──────────────────────────────────────────────────
  // Build helpers
  //──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      drawer: const AppDrawer(activeItem: 1),
      body: Stack(
        children: [
          // Decorative background
          Positioned(
            width: size.width * 1.7,
            bottom: 100,
            left: 100,
            child: Image.asset('assets/Backgrounds/Spline.png'),
          ),
          Positioned.fill(
              child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
                  child: Container())),
          const rive.RiveAnimation.asset('assets/RiveAssets/shapes.riv'),
          Positioned.fill(
              child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 10),
                  child: const SizedBox())),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const LoadingScreen(loadingText: '')
                      : _buildMap(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(),
    );
  }

  // Greeting header
  Widget _buildGreeting() {
    return Row(
      children: [
        Builder(
            builder: (context) =>
                AppMenuButton(onTap: () => Scaffold.of(context).openDrawer())),
        const SizedBox(width: 10),
        const Text('The Map',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Spacer(),
        CircleAvatar(
          backgroundImage: userImage.isNotEmpty
              ? (userImage.startsWith('http')
                  ? NetworkImage(userImage)
                  : AssetImage(userImage) as ImageProvider)
              : null,
          child: userImage.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildMap() {
    final markerWidgets = <Marker>[];

    for (final pub in _markers) {
      late double lat, lon;
      try {
        lat = _parseCoord(pub['latitude']);
        lon = _parseCoord(pub['longitude']);
      } catch (_) {
        continue; // skip invalid coords
      }

      markerWidgets.add(
        Marker(
          point: LatLng(lat, lon),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _onPubMarkerTap(pub),
            child: _buildMarkerImage(pub['logo']),
          ),
        ),
      );
    }

    if (_currentLocation != null) {
      markerWidgets.add(
        Marker(
            point: _currentLocation!,
            width: 50,
            height: 50,
            child: const Icon(Icons.my_location, color: Colors.red, size: 30)),
      );
    }

    final initialCentre = _deriveInitialCentre() ?? const LatLng(0, 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 600,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCentre,
            initialZoom: 14.5,
            onMapReady: () {
              _mapIsReady = true;
              _tryMoveMap();
            },
          ),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app'),
            if (_gpxPoints.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(points: _gpxPoints, color: Colors.red, strokeWidth: 8)
              ]),
            MarkerLayer(markers: markerWidgets),
          ],
        ),
      ),
    );
  }

  //──────────────────────────────────────────────────
  // Utilities
  //──────────────────────────────────────────────────

  double _parseCoord(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.toLowerCase() == 'none')
        throw const FormatException('Invalid coordinate: none');
      return double.parse(value);
    }
    throw const FormatException('Invalid coordinate');
  }

  Widget _buildMarkerImage(String imageUrl, {double size = 60}) {
    Widget img;
    if (imageUrl.startsWith('http')) {
      img =
          Image.network(imageUrl, width: size, height: size, fit: BoxFit.cover);
    } else {
      img = Image.asset(imageUrl, width: size, height: size, fit: BoxFit.cover);
    }
    return ClipOval(child: img);
  }
}
