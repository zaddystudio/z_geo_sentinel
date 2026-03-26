import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart'; //

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: ZaddyHull()),
  );
}

class ZaddyHull extends StatefulWidget {
  const ZaddyHull({super.key});
  @override
  State<ZaddyHull> createState() => _ZaddyHullState();
}

class _ZaddyHullState extends State<ZaddyHull> {
  // --- HARDWARE ---
  final ScreenshotController _screenshotController = ScreenshotController();
  final Battery _battery = Battery();
  final MapController _mapController = MapController();

  // --- MASTER DATA PULSE ---
  String _speed = "0",
      _altitude = "00m",
      _currentAddress = "WARMING SENSORS...";
  Position? _currentPosition;
  int _batteryLevel = 100, _compassMode = 0;
  double? _heading = 0;
  String _direction = "N", _tempNow = "30°C", _weatherNext = "Next: Sunny";
  bool _isHudMode = false,
      _isTorchOn = false,
      _isRecording = false,
      _isPermissionGranted = false;
  bool _isCached = true;
  List<String> _tripLogs = [];

  // --- MEMORY ---
  double? _homeLat, _homeLng, _officeLat, _officeLng;
  bool _isRedScreenActive = false, _hasAlertedThisSession = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // --- CORE ENGINE ---
  Future<void> _checkPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      setState(() => _isPermissionGranted = true);
      _warmUpGPS();
      _startMasterPulse();
      _initSystemMonitor();
      _initMagneticCompass();
      _loadMemory();
    }
  }

  Future<void> _warmUpGPS() async {
    Position? lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null && mounted) {
      setState(() {
        _currentPosition = lastPos;
        _altitude = "${lastPos.altitude.toStringAsFixed(0)}m";
        _isCached = true;
      });
      _syncAddress(lastPos);
    }
  }

  void _startMasterPulse() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _speed = (pos.speed * 3.6).toStringAsFixed(0);
          _altitude = "${pos.altitude.toStringAsFixed(0)}m";
          _isCached = false;
          if (_compassMode == 0) {
            _heading = pos.heading;
            _direction = _getDirection(_heading ?? 0);
          }
          _checkProximity(pos);
          if (_isRecording) _logPosition(pos);
          _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
        });
        _syncAddress(pos);
      }
    });
  }

  Future<void> _syncAddress(Position pos) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (p.isNotEmpty)
        setState(
          () => _currentAddress =
              "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}",
        );
    } catch (_) {}
  }

  // --- TACTICAL FUNCTIONS ---
  void _share() {
    if (_currentPosition == null) return;
    String date = DateTime.now().toString().split('.')[0];
    String link =
        "http://maps.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}";
    String report =
        """
Z GEO STATUS REPORT
-------------------
📍 ADDR: $_currentAddress
📍 LOC: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}
⛰️ ELEV: $_altitude
🚀 SPEED: $_speed km/h
🧭 HEAD: $_direction (${_heading?.toStringAsFixed(0)}°)
📅 TIME: $date
🔗 MAP: $link
Proudly Cooked by: Zaddy Digital Solutions (https://wa.me/+2347060633216)
""";
    Share.share(report);
  }

  void _captureDashboard() async {
    await _screenshotController.capture().then((image) async {
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/z_snap_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(path).writeAsBytes(image);
        await Gal.putImage(path);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("DASHBOARD CAPTURED TO GALLERY"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  void _saveMemory(
    double lat,
    double lng,
    String type,
    String? manualName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'home') {
      _homeLat = lat;
      _homeLng = lng;
      prefs.setDouble('home_lat', lat);
      prefs.setDouble('home_lng', lng);
    } else {
      _officeLat = lat;
      _officeLng = lng;
      prefs.setDouble('office_lat', lat);
      prefs.setDouble('office_lng', lng);
    }
    setState(() {});
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$type UPDATED ${manualName != null ? 'TO $manualName' : '(AUTO)'}",
          ),
          backgroundColor: Colors.cyan,
        ),
      );
  }

  void _manualAddressEntry() {
    final TextEditingController aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "MANUAL OVERRIDE",
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: TextField(
          controller: aCtrl,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => _geocode(aCtrl.text, 'home'),
            child: const Text("SET HOME"),
          ),
          TextButton(
            onPressed: () => _geocode(aCtrl.text, 'office'),
            child: const Text("SET OFFICE"),
          ),
        ],
      ),
    );
  }

  Future<void> _geocode(String q, String t) async {
    try {
      List<Location> ls = await locationFromAddress(q);
      if (ls.isNotEmpty) {
        _saveMemory(ls.first.latitude, ls.first.longitude, t, q);
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("LOCATION NOT FOUND")));
    }
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted)
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    Color bg = _isRedScreenActive ? Colors.red.shade900 : Colors.black;

    return Screenshot(
      controller: _screenshotController,
      child: Transform(
        alignment: Alignment.center,
        transform: _isHudMode ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
        child: Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBentoGrid()),
                  const SizedBox(height: 12),
                  _buildInstrumentRow(),
                  const SizedBox(height: 8),
                  _buildDataFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateTime.now().toString().split(' ')[1].substring(0, 5),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const Text(
            "Z-GEO SENTINEL",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              Text(
                "$_batteryLevel%",
                style: TextStyle(
                  color: _batteryLevel < 20 ? Colors.red : Colors.greenAccent,
                  fontSize: 10,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.cyanAccent,
                  size: 18,
                ),
                onPressed: _showAbout,
              ),
              _buildMenu(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _currentPosition == null
                ? Container(
                    color: const Color(0xFF004D40),
                    child: const Center(
                      child: Text(
                        "ACQUIRING GPS LOCK...",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.zaddy.sentinel',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: _buildTile(
                  Icons.speed,
                  _speed,
                  "KM/H",
                  Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleTorch,
                  child: _buildTile(
                    Icons.flashlight_on,
                    _isTorchOn ? "ON" : "OFF",
                    "TACTICAL TORCH",
                    _isTorchOn ? Colors.yellow : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                Icons.cloud,
                _tempNow,
                _weatherNext,
                Colors.amberAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isRecording = !_isRecording),
                child: _buildTile(
                  Icons.circle,
                  _isRecording ? "REC" : "OFF",
                  "BLACK BOX",
                  _isRecording ? Colors.red : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isHudMode = !_isHudMode),
                child: _buildTile(
                  Icons.flip,
                  "HUD",
                  "MIRROR",
                  _isHudMode ? Colors.cyanAccent : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: () => _saveMemory(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  'home',
                  null,
                ),
                child: _buildStrip(
                  "HOME",
                  _getDistance(_homeLat, _homeLng),
                  Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onLongPress: () => _saveMemory(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  'office',
                  null,
                ),
                child: _buildStrip(
                  "OFFICE",
                  _getDistance(_officeLat, _officeLng),
                  Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstrumentRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInstBox(_altitude, "ELEVATION"),
        GestureDetector(
          onTap: _captureDashboard,
          child: _buildInstBox(
            "SNAP",
            "SCREENSHOT",
            icon: Icons.camera_alt,
            col: Colors.white70,
          ),
        ),
        _buildInstBox("STATUS: OK", "Z-DIGITAL", col: Colors.greenAccent),
      ],
    );
  }

  Widget _buildDataFooter() {
    String statusText = _isCached
        ? "[LAST ACQ.]"
        : "📡 LOCKED (±${_currentPosition?.accuracy.toInt() ?? 0}m)";
    return FittedBox(
      child: Text(
        "$statusText | LAT: ${_currentPosition?.latitude.toStringAsFixed(5)} | LNG: ${_currentPosition?.longitude.toStringAsFixed(5)} | ADDR: $_currentAddress",
        style: TextStyle(
          color: _isCached ? Colors.white24 : Colors.greenAccent,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildTile(IconData i, String v, String l, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(i, color: c, size: 28),
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 8)),
      ],
    ),
  );
  Widget _buildStrip(String l, String d, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_on, color: c, size: 14),
        const SizedBox(width: 8),
        Text(
          d,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 8)),
      ],
    ),
  );
  Widget _buildInstBox(
    String v,
    String l, {
    Color col = Colors.white,
    IconData? icon,
  }) => Container(
    width: 100,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        if (icon != null) Icon(icon, color: Colors.white38, size: 16),
        Text(
          v,
          style: TextStyle(color: col, fontWeight: FontWeight.bold),
        ),
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 8)),
      ],
    ),
  );
  Widget _buildMenu() => PopupMenuButton(
    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
    itemBuilder: (c) => [
      PopupMenuItem(
        onTap: _manualAddressEntry,
        child: const Text("Manual Address Setting"),
      ),
      PopupMenuItem(onTap: _showLogs, child: const Text("Black Box History")),
      PopupMenuItem(onTap: _share, child: const Text("Tactical Share")),
      PopupMenuItem(
        onTap: _clearAllMemory,
        child: const Text(
          "Clear All Memory",
          style: TextStyle(color: Colors.red),
        ),
      ),
    ],
  );
  void _showAbout() => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 50),
          const SizedBox(height: 20),
          const Text(
            "COOKED BY",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Zaddy Digital Solutions",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "hi@zaddyhost.top\n+234 706 063 3216",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.1),
              foregroundColor: Colors.cyanAccent,
              side: const BorderSide(color: Colors.cyanAccent, width: 0.5),
            ),
            onPressed: () =>
                launchUrl(Uri.parse("https://zaddyhost.top/creatives")),
            child: const Text("GET MORE APPS"),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    ),
  );
  void _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
        setState(() => _isTorchOn = false);
      } else {
        await TorchLight.enableTorch();
        setState(() => _isTorchOn = true);
      }
    } catch (_) {}
  }

  void _initSystemMonitor() async {
    _battery.onBatteryStateChanged.listen((_) async {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    });
  }

  void _initMagneticCompass() {
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          if (_compassMode != 0) {
            _heading = event.heading;
            _direction = _getDirection(_heading ?? 0);
          }
        });
      }
    });
  }

  String _getDirection(double h) {
    h %= 360;
    if (h < 0) h += 360;
    List<String> d = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    return d[((h + 22.5) % 360 / 45).floor()];
  }

  void _loadMemory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _homeLat = prefs.getDouble('home_lat');
      _homeLng = prefs.getDouble('home_lng');
      _officeLat = prefs.getDouble('office_lat');
      _officeLng = prefs.getDouble('office_lng');
      _tripLogs = prefs.getStringList('trip_logs') ?? [];
    });
  }

  void _logPosition(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    String t = DateTime.now().toString().split(' ')[1].substring(0, 5);
    _tripLogs.insert(
      0,
      "$t | ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}",
    );
    if (_tripLogs.length > 50) _tripLogs.removeLast();
    await prefs.setStringList('trip_logs', _tripLogs);
  }

  void _showLogs() => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF121212),
    builder: (c) => ListView.builder(
      itemCount: _tripLogs.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(
          _tripLogs[i],
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontFamily: 'monospace',
          ),
        ),
      ),
    ),
  );
  String _getDistance(double? tL, double? tG) {
    if (_currentPosition == null || tL == null) return "--";
    double d = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      tL,
      tG!,
    );
    return d > 1000
        ? "${(d / 1000).toStringAsFixed(1)}km"
        : "${d.toStringAsFixed(0)}m";
  }

  void _checkProximity(Position pos) {
    if (_homeLat == null || _isRedScreenActive) return;
    double d = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _homeLat!,
      _homeLng!,
    );
    if (d < 50 && !_hasAlertedThisSession) {
      setState(() {
        _isRedScreenActive = true;
        _hasAlertedThisSession = true;
      });
      HapticFeedback.heavyImpact();
      Timer(
        const Duration(seconds: 30),
        () => setState(() => _isRedScreenActive = false),
      );
    } else if (d > 100) {
      _hasAlertedThisSession = false;
    }
  }

  Future<void> _clearAllMemory() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    setState(() {
      _homeLat = null;
      _homeLng = null;
      _officeLat = null;
      _officeLng = null;
      _tripLogs = [];
    });
  }
}
