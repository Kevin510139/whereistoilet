import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_yt/consts.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

// 先讀取圖示檔案
BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;


class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class Toilet {
  final String name;
  final double latitude;
  final double longitude;

  Toilet({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class _MapPageState extends State<MapPage> {
  final Location _locationController = Location();
  final Completer<GoogleMapController> _mapController =
  Completer<GoogleMapController>();

  LatLng? _currentLocation; // 用於存儲當前位置
  LatLng? _nearestMarkerLocation;//存最近廁所位置
  List<Marker> _markers = []; // 存儲廁所標記的列表
  Map<PolylineId, Polyline> _polylines = {}; // 存儲路線的映射

  @override
  void initState() {
    super.initState();
    _getCustomIcon().then((icon) {
      setState(() {
        customIcon = icon;
      });
    });
    _getLocationUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(25.01375889109773, 121.54050015140857),
              zoom: 16,
            ),
            markers: {
              if (_currentLocation != null)
                Marker(
                  markerId: MarkerId('currentLocation'),
                  position: _currentLocation!,
                  infoWindow: InfoWindow(title: '目前位置'),
                ),
              ..._markers.map((marker) => marker),
            },
            polylines: Set<Polyline>.of(_polylines.values),
          ),
          Positioned(
            bottom: 100.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              child: Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  // 將 Google 地圖控制器保存在 _mapController 中
  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
  }
  // 计算最近的标记位置
  void _calculateNearestMarkerLocation(List<Marker> markers, LatLng currentLocation) {
    double minDistance = double.infinity;
    LatLng? nearestLocation;

    for (var marker in markers) {
      double distance = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        marker.position.latitude,
        marker.position.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestLocation = marker.position;
      }
    }

    setState(() {
      _nearestMarkerLocation = nearestLocation;
    });
  }

  // 计算两个地理坐标之间的距离（单位：米）
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radius = 6371; // 地球半径，单位为公里
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = radius * c * 1000; // 转换为米
    return distance;
  }

// 将角度转换为弧度
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
  Future<BitmapDescriptor> _getCustomIcon() async {
    final ByteData customIconData = await rootBundle.load('assets/images/toilet.png');
    final Uint8List bytes = customIconData.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }
  // 在地圖上移動相機到當前位置
  Future<void> _goToCurrentLocation() async {
    final GoogleMapController controller = await _mapController.future;
    if (_currentLocation != null) {
      final CameraPosition _newCameraPosition = CameraPosition(
        target: _currentLocation!,
        zoom: 16,
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(_newCameraPosition),
      );
    }
  }

  // 監聽位置變化，更新 _currentLocation，廁所標記和路線
  Future<void> _getLocationUpdates() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // 檢查並啟用位置服務
    _serviceEnabled = await _locationController.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    // 檢查並獲取位置權限
    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // 監聽位置變化
    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });
      _updatePolyline(); // 更新路線
      _fetchToilets(_currentLocation!); // 獲取附近廁所
      _getCustomIcon().then((icon) {
        setState(() {
          customIcon = icon;
        });
      });
    });
  }

  // 從服務器獲取附近的廁所資訊
  Future<void> _fetchToilets(LatLng currentLocation) async {
    final url = Uri.parse('https://find-public-toilet.adaptable.app/nearby_toilet');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "longitude": currentLocation.longitude,
        "latitude": currentLocation.latitude,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> toiletsData = json.decode(response.body);
      final List<Marker> markers = [];
      for (final toiletData in toiletsData) {
        final Toilet toilet = Toilet(
          name: toiletData['Name'],
          latitude: toiletData['Latitude'],
          longitude: toiletData['Longitude'],
        );
        final Marker marker = Marker(
          markerId: MarkerId(toilet.name),
          position: LatLng(toilet.latitude, toilet.longitude),
          icon: customIcon,
          infoWindow: InfoWindow(title: toilet.name),
        );
        markers.add(marker);
      }
      setState(() {
        _markers = markers;
        _calculateNearestMarkerLocation(_markers, _currentLocation!);
      });
    } else {
      throw Exception('Failed to load toilets');
    }
  }

  // 從 Google 地圖服務獲取路線點
  Future<void> _updatePolyline() async {
    if (_currentLocation != null && _nearestMarkerLocation != null) {
      final List<LatLng> coordinates = await _getPolylinePoints(_currentLocation!, _nearestMarkerLocation!);
      _generatePolyLineFromPoints(coordinates);
    }
  }

  // 獲取路線點
  Future<List<LatLng>> _getPolylinePoints(LatLng start, LatLng end) async {
    final List<LatLng> polylineCoordinates = [];
    final PolylinePoints polylinePoints = PolylinePoints();
    final PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      GOOGLE_MAPS_API_KEY,
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
      travelMode: TravelMode.walking, // 设置为步行模式
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    } else {
      print(result.errorMessage);
    }
    return polylineCoordinates;
  }

  // 從路線點生成路線
  void _generatePolyLineFromPoints(List<LatLng> polylineCoordinates) {
    final PolylineId id = PolylineId("poly");
    final Polyline polyline = Polyline(
      polylineId: id,
      color: Color.fromARGB(255, 93, 162, 205),
      points: polylineCoordinates,
      width: 8,
    );
    setState(() {
      _polylines[id] = polyline;
    });
  }
}
