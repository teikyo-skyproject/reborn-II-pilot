import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMapTileCaching.initialise(); // New line
  await FMTC.instance('mapStore').manage.createAsync(); // New line
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(Main());
  });
}

class Main extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  // ローカル通知setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  LatLng currentPosition = LatLng(35.28891762055586, 136.2466526902753); // 現在地
  bool serviceEnabled = false; // 位置情報の有効
  String text = ''; // 緯度・経度
  String power = '000.000'; // パワー
  String speed = '000.000'; // スピード
  LocationPermission permission = LocationPermission.denied; // 位置情報の許可
  MapController mapController = MapController(); // マップコントローラー
  double currentHeading = 0; // 現在の方角
  bool isMeasuring = false; // 計測開始・停止のフラグ
  List<LatLng> coordinates = []; //座標を格納するリスト
  bool isTimerStarted = false;
  int elapsedTime = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _requestIOSPermission();
    _initializePlatformSpecifics();
    mapController = MapController();
    updateLocation();
  }

  void _requestIOSPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()!
        .requestPermissions(alert: false, badge: true, sound: false);
  }

  void _initializePlatformSpecifics() {
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) => {},
    );
    var initializationSettings =
        InitializationSettings(iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse res) {
      debugPrint('payload:${res.payload}');
    });
  }

  Future<void> _showNotification(String title, String body) async {
    var iosChannelSpecifics = DarwinNotificationDetails();
    var platformChannelSpecifics =
        NotificationDetails(iOS: iosChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'New Payload',
    );
  }

  void updateLocation() async {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        text = '位置情報が有効になっていません';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          text = '位置情報の許可がありません';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        text = '位置情報の許可がありません';
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      text = '緯度: ${position.latitude}, 経度: ${position.longitude}';
      currentPosition = LatLng(position.latitude, position.longitude);
      currentHeading = position.heading;
    });
    mapController.move(currentPosition, 14.0);
    if (isMeasuring) {
      coordinates.add(currentPosition);
    }

    updateLocation();
  }

  void handleMeasurement() {
    setState(() {
      tz.initializeTimeZones();
      var jpTime = tz.TZDateTime.now(tz.getLocation('Asia/Tokyo'));
      var formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      String currentTime = formatter.format(jpTime);
      if (!isMeasuring) {
        coordinates = [];
        elapsedTime = 0;
        handleTimer();
        _showNotification('計測開始', currentTime);
      }
      if (isMeasuring) {
        timer?.cancel();
        _showNotification('計測終了', currentTime);
      }
      isMeasuring = !isMeasuring;
      isTimerStarted = !isTimerStarted;
    });
  }

  void handleTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {
        elapsedTime++;
      });
    });
  }

  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            center: currentPosition,
            zoom: 14.0,
            interactiveFlags: InteractiveFlag.all,
            enableScrollWheel: true,
            scrollWheelVelocity: 0.00001,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.fleaflet.flutter_map.example',
              tileProvider: FMTC.instance('mapStore').getTileProvider(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: currentPosition,
                  width: 60,
                  height: 60,
                  builder: (ctx) => Transform.rotate(
                    angle: currentHeading * pi / 180,
                    child: SvgPicture.asset(
                      'images/airplane.svg',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  anchorPos: AnchorPos.align(AnchorAlign.center),
                ),
              ],
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                    points: coordinates, color: Colors.blue, strokeWidth: 3.0)
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Column(children: [
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: handleMeasurement,
                          child: Text(isMeasuring ? '計測終了' : '計測開始',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(120, 40),
                          ),
                        )
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.all(15.0),
                    child: ElevatedButton(
                        onPressed: () {
                          updateLocation();
                        },
                        style: ElevatedButton.styleFrom(
                          primary: Colors.blue[300],
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(20),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 30,
                        )),
                  )
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Container(
                        color: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(15.0),
                          child: Column(children: [
                            Text(
                              '経過時間： $elapsedTime 秒',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'スピード: $speed KM/H',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'パワー: $power W',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            )
                          ]),
                        ),
                      )),
                  Padding(
                    padding: EdgeInsets.only(bottom: 30, left: 20),
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
