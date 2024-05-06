import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_yt/consts.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Location _locationController = new Location();

  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  static const LatLng _phome = LatLng(25.01375889109773, 121.54050015140857);
  static const LatLng _pID227 = LatLng(25.041483, 121.542995);
  static const LatLng _pID228 = LatLng(25.033086, 121.543828);
  static const LatLng _pID229 = LatLng(25.026136, 121.543645);
  static const LatLng _pID230 = LatLng(25.02379, 121.553126);
  LatLng? _currentP = null;

  Map<PolylineId, Polyline> polylines = {};

  void _updatePolyline() {
    if (_currentP != null) {
      getPolylinePoints(_currentP!, _pID227).then((coordinates) {
        generatePolyLineFromPoints(coordinates);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getLocationUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) =>
                _mapController.complete(controller),
            initialCameraPosition: CameraPosition(
              target: _phome,
              zoom: 13,
            ),
            markers: {
              Marker(
                markerId: MarkerId("_currentLocation"),
                icon: BitmapDescriptor.defaultMarker,
                position: _currentP ?? _phome,
                infoWindow: InfoWindow(
                  title: '目前位置'
                )
              ),
              Marker(
                markerId: MarkerId("_destionationLocation"),
                icon: BitmapDescriptor.defaultMarker,
                position: _pID227,
                infoWindow: InfoWindow(
                    title: '捷運忠孝復興站(文湖線)'
                )
              ),
              Marker(
                markerId: MarkerId("_destionationLocation"),
                icon: BitmapDescriptor.defaultMarker,
                position: _pID228,
                infoWindow: InfoWindow(
                    title: '捷運大安站(文湖線)'
                )
              ),
              Marker(
                markerId: MarkerId("_destionationLocation"),
                icon: BitmapDescriptor.defaultMarker,
                position: _pID229,
                infoWindow: InfoWindow(
                    title: '捷運科技大樓站(文湖線)'
                )
              ),
              Marker(
                markerId: MarkerId("_destionationLocation"),
                icon: BitmapDescriptor.defaultMarker,
                position: _pID230,
                infoWindow: InfoWindow(
                    title: '捷運六張犁站(文湖線)'
                )
              ),
            },
            polylines: Set<Polyline>.of(polylines.values),
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

  Future<void> _goToCurrentLocation() async {
    final GoogleMapController controller = await _mapController.future;
    if (_currentP != null) {
      CameraPosition _newCameraPosition = CameraPosition(
        target: _currentP!,
        zoom: 15,
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(_newCameraPosition),
      );
    }
  }

  Future<void> getLocationUpdates() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationController.serviceEnabled();
    if (_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
    } else {
      return;
    }

    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentP =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _updatePolyline(); // 更新路線
        });
      }
    });
    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        setState(() {
          _currentP = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _updatePolyline(); // 更新路線
        });

        // 調用 fetchToilets 方法並處理結果
        fetchToilets(_currentP!).then((toilets) {
          // 處理來自 API 的公共廁所資料
          print(toilets);
        }).catchError((error) {
          // 處理錯誤情況
          print('Error fetching toilets: $error');
        });
      }
    });
  }
  Future<List<dynamic>> fetchToilets(LatLng currentLocation) async {
    var url = Uri.parse('https://find-public-toilet.adaptable.app/nearby_toilet');
    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "longitude": currentLocation.longitude,
        "latitude": currentLocation.latitude,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load toilets');
    }
  }

  Future<List<LatLng>> getPolylinePoints(LatLng start, LatLng end) async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      GOOGLE_MAPS_API_KEY,
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
      travelMode: TravelMode.driving,
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

  void generatePolyLineFromPoints(List<LatLng> polylineCoordinates) async {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id,
        color: Color.fromARGB(255, 93, 162, 205),
        points: polylineCoordinates,
        width: 8);
    setState(() {
      polylines[id] = polyline;
    });
  }
}
