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
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

// 先讀取圖示檔案
BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;


class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class Toilet {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int toiletnum;
  final int excellentnum;
  final int fairnum;
  final int goodnum;
  final int familynum;
  final int poornum;
  final double rating;
  final int ratingnum;
  final String type;
  final int restroomid;

  Toilet({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.toiletnum,
    required this.excellentnum,
    required this.fairnum,
    required this.goodnum,
    required this.familynum,
    required this.poornum,
    required this.rating,
    required this.ratingnum,
    required this.type,
    required this.restroomid,
  });
}

class User {
  final String email;
  final String password;

  User({
    required this.email,
    required this.password,
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
  User? currentUser; // 假设您有方式获取当前登录用户信息
  String? accesstoken;

  @override
  void initState() {
    super.initState();
    currentUser = null; // 假设您在某处设置了当前用户
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
      appBar: AppBar(
        title: Text(currentUser != null ? currentUser!.email : "Not logged in"), // 显示用户邮箱
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () {
              currentUser != null?
              currentUser = null:null;
            },
          ),
        ],
      ),
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
  void _onMarkerTapped(BuildContext context, Toilet toilet) {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Container(
          height: 200,
          color: Color(0xFF737373),  // 背景色，可自訂
          child: Container(
            // padding: EdgeInsets.all(10),  // 增加內距，讓UI更加美观
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(Icons.place),
                  title: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: <TextSpan>[
                        TextSpan(text: '${toilet.name} ', style: TextStyle(fontSize: 20.0, color: Colors.blue)),
                        TextSpan(text: '(${toilet.type})', style: TextStyle(fontSize: 20.0, color: Colors.blue)),
                        // TextSpan(text: toilet.rating == 0? '評分: 無':'評分: ${toilet.rating} 星', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${toilet.address}', style: TextStyle(fontSize: 16.0, color: Colors.grey)),
                      SizedBox(height: 5),
                      Row(children: [
                        ..._buildRatingStars(toilet.rating),
                        SizedBox(width: 5), // Add space between rating stars and rating number
                        Text(
                          '(${toilet.ratingnum})',
                          style: TextStyle(fontSize: 16.0, color: Colors.grey),
                        )
                      ])
                    ],
                  )
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    toilet.familynum != 0 ?
                    Image.asset(
                      'assets/images/family.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ) :
                    SizedBox(width: 1,),
                    toilet.poornum != 0 ?
                    Image.asset(
                      'assets/images/poor.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ) :
                    SizedBox(width: 10,),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      child: Text("路線"),
                      onPressed: () {
                        Navigator.pop(context);  // 关闭底部弹窗
                        setState(() {
                          _nearestMarkerLocation = LatLng(toilet.latitude, toilet.longitude);
                        });
                        _updatePolyline();
                      },
                    ),
                    ElevatedButton(
                      child: Text("評分"),
                      onPressed:() async{
                        {
                          if (currentUser == null){
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("用戶登錄"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      TextField(
                                        controller: emailController,
                                        decoration: InputDecoration(
                                          labelText: "帳號",
                                          hintText: "請輸入您的帳號"
                                        ),
                                      ),
                                      TextField(
                                        controller: passwordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: "密碼",
                                          hintText: "請輸入您的密碼"
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text("註冊"),
                                      onPressed: () {
                                        _registerUser(emailController.text, passwordController.text).then((result) {
                                          Navigator.pop(context);  // 關閉對話框
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result),
                                              duration: Duration(seconds: 3),
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context).size.height - 150,
                                                  left: 10,
                                                  right: 10),
                                            )
                                          );
                                        }).catchError((error) {
                                          Navigator.pop(context);  // 出錯也要關閉對話框
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Error"),
                                              duration: Duration(seconds: 3),
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context).size.height - 150,
                                                  left: 10,
                                                  right: 10),
                                            )
                                          );
                                        });
                                      },
                                    ),
                                    TextButton(
                                      child: Text("登入"),
                                      onPressed: () {
                                        _UserLogin(emailController.text, passwordController.text).then((result) {
                                          Navigator.pop(context);  // 关闭对话框
                                          if (result["message"] == "Login successfully") {
                                            accesstoken = result["accessToken"]!;
                                            currentUser = User(email: emailController.text, password: passwordController.text);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result["message"]!),
                                                duration: Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                                margin: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context).size.height - 150,
                                                  left: 10,
                                                  right: 10
                                                ),
                                              )
                                            );
                                          } else {
                                            currentUser = null;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result["message"]!),
                                                duration: Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                                margin: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context).size.height - 150,
                                                  left: 10,
                                                  right: 10
                                                ),
                                              )
                                            );
                                          }
                                        }).catchError((error) {
                                          Navigator.pop(context);  // 出错也要关闭对话框
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $error"),  // 显示错误详情
                                              duration: Duration(seconds: 3),
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                bottom: MediaQuery.of(context).size.height - 150,
                                                left: 10,
                                                right: 10
                                              ),
                                            )
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                          else{
                            bool hasRated = await _getRated(toilet.restroomid, accesstoken);  // 使用 await 等待结果
                            print(hasRated);
                            if (!hasRated) {
                              // 用户未评分，显示评分对话框
                              _showRatingDialog(context, toilet, accesstoken);
                            } else {
                              // 用户已评分，执行其他操作或显示提示
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("您已評分過"),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text("編輯評分"),
                                      onPressed: () {
                                        _editRatingDialog(context, toilet, accesstoken);
                                      },
                                    ),
                                    TextButton(
                                      child: Text("返回"),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                            }
                          }
                        }
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<bool> _getRated(int restroomid, String? accesstoken) async {
    final url = Uri.parse('https://find-public-toilet.adaptable.app/has_rated/$restroomid');
    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accesstoken"  // 添加accessToken到请求头
      },
    );
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['HasRated'];
    } else {
      return false;
    }
  }
  // 定义显示评分对话框的函数
  void _showRatingDialog(BuildContext contextm, Toilet toilet, String? accesstoken) {
    double? _currentRating = 0.0;  // 用于存储用户的评分，初始设为3
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("評分"),
          content: RatingBar(
            initialRating: 3,
            itemCount: 5,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
            onRatingUpdate: (rating) {
              _currentRating = rating;
            },
            ratingWidget: RatingWidget(
              full: Icon(Icons.star, color: Colors.orange),  // 完整星星
              half: Icon(Icons.star_half, color: Colors.orange),  // 半星
              empty: Icon(Icons.star_border, color: Colors.orange),  // 空星
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("取消"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("提交"),
              onPressed: () {
                  _submitRating(_currentRating, toilet.restroomid, accesstoken);
                  Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _editRatingDialog(BuildContext contextm, Toilet toilet, String? accesstoken) {
    double? _currentRating = 0.0;  // 用于存储用户的评分，初始设为3
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("評分"),
          content: RatingBar(
            initialRating: 3,
            itemCount: 5,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
            onRatingUpdate: (rating) {
              _currentRating = rating;
            },
            ratingWidget: RatingWidget(
              full: Icon(Icons.star, color: Colors.orange),  // 完整星星
              half: Icon(Icons.star_half, color: Colors.orange),  // 半星
              empty: Icon(Icons.star_border, color: Colors.orange),  // 空星
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("取消"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("提交"),
              onPressed: () {
                  _editRating(_currentRating, toilet.restroomid, accesstoken);
                  Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // 廁所評分後端
  void _editRating(double? rating, int? restroomid, String? AccessToken) async {
    final url = Uri.parse('https://find-public-toilet.adaptable.app/edit_rating/${restroomid}');
    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $AccessToken"  // 添加accessToken到请求头
      },
      body: jsonEncode({
        "score": rating,
      }),
    );
    print(response.statusCode);
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rating updated successfully!"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }else if (response.statusCode == 500){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Server Error"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }else if (response.statusCode == 400){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please input score"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }
  }
  // 廁所評分後端
  void _submitRating(double? rating, int? restroomid, String? AccessToken) async {
    final url = Uri.parse('https://find-public-toilet.adaptable.app/rate/${restroomid}');
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $AccessToken"  // 添加accessToken到请求头
      },
      body: jsonEncode({
        "score": rating,
      }),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rating sent successfully!"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }else if (response.statusCode == 500){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Server Error"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }else if (response.statusCode == 400){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please input score"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You have already rated this toilet"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10
          ),
        ),
      );
    }
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
          address: toiletData['Address'],
          latitude: toiletData['Latitude'],
          longitude: toiletData['Longitude'],
          toiletnum: toiletData['ToiletNum'],
          excellentnum: toiletData['Excellent'],
          fairnum: toiletData['Fair'],
          goodnum: toiletData['Good'],
          familynum: toiletData['FamilyRestroom'],
          poornum: toiletData['Poor'],
          rating: toiletData['Rating'].toDouble(),
          ratingnum: toiletData['RatingCount'],
          type: toiletData['Type'],
          restroomid: toiletData['RestroomID'],

        );

        final Marker marker = Marker(
          markerId: MarkerId(toilet.name),
          position: LatLng(toilet.latitude, toilet.longitude),
          icon: customIcon,
          infoWindow: InfoWindow(title: toilet.name),
          onTap: () => _onMarkerTapped(context, toilet),
        );
        markers.add(marker);
      }
      setState(() {
        _markers = markers;
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
// 註冊使用者的函數
Future<String> _registerUser(String email, String password) async {
  final url = Uri.parse('https://find-public-toilet.adaptable.app/register');
  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "email": email,
      "password": password,
    }),
  );

  if (response.statusCode == 201) {
    return("User registered successfully");
  }
  else if(response.statusCode == 409){
    return("Email already exists");
  } else {
    return('Failed to register user');
  }
}
// 使用者登入
Future<Map<String, String>> _UserLogin(String email, String password) async {
  final url = Uri.parse('https://find-public-toilet.adaptable.app/login');
  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "email": email,
      "password": password,
    }),
  );
  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    if (data['access_token'] != null) {
      return {
        "message": "Login successfully",
        "accessToken": data['access_token']
      };
    } else {
      return {
        "message": "Failed to login",
        "accessToken": ""
      };
    }
  } else {
    return {
      "message": "Failed to login",
      "accessToken": ""
    };
  }
}
List<Widget> _buildRatingStars(double rating){
  if (rating == 0) {
    return List.generate(5, (index) => const Icon(Icons.star, color: Colors.grey));
  }
  else{
    return List.generate(
      5,
      (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: index < rating ? Colors.yellow[500] : Colors.grey,
      ),
    );
  }
}