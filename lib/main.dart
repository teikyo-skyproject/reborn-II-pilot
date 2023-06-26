import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:timezone/data/latest.dart' as tz;
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMapTileCaching.initialise(); // New line
  await FMTC.instance('mapStore').manage.createAsync(); // New line
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const Main());
  });
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  // ローカル通知setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Bluetooth state
  final flutterReactiveBle = FlutterReactiveBle();
  String deviceId = 'CD:4A:79:D4:64:26';
  final Uuid serviceUuid = Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  final Uuid TxCharacteristicUuid =
      Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
  bool _connected = false;
  String log = '';

  LatLng currentPosition = LatLng(35.28891762055586, 136.2466526902753); // 現在地
  String text = ''; // 緯度・経度
  String power = ''; // パワー
  String rpm = ''; // 回転数
  String speed = ''; // スピード
  String recordingTime = '00:00:00'; // 記録時間
  String lat = '00.000000'; // 緯度
  String lng = '000.000000'; // 経度
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
  }

  void _requestIOSPermission() {
    if (Platform.isIOS) {
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()!
          .requestPermissions(alert: false, badge: true, sound: false);
    } else if (Platform.isAndroid) {
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestPermission();
    }
  }

  void _initializePlatformSpecifics() {
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) => {},
    );
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse res) {
      debugPrint('payload:${res.payload}');
    });
  }

  Future<void> _showNotification(String title, String body) async {
    var iosChannelSpecifics = const DarwinNotificationDetails();
    var androidChannelSpecifics = const AndroidNotificationDetails(
      'CHANNEL_ID',
      'CHANNEL_NAME',
      channelDescription: "CHANNEL_DESCRIPTION",
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      timeoutAfter: 5000,
      styleInformation: DefaultStyleInformation(true, true),
    );
    var platformChannelSpecifics = NotificationDetails(
        android: androidChannelSpecifics, iOS: iosChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'New Payload',
    );
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
    timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        elapsedTime++;
      });
    });
  }

  _connectToDevice(String id) async {
    final connection = flutterReactiveBle.connectToDevice(
        id: id, connectionTimeout: Duration(seconds: 10));
    connection.listen((connectionState) {
      setState(() {
        log = 'Connection state: $connectionState';
      });
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        _connected = true;
        setState(() {
          log = 'Connected';
        });
        flutterReactiveBle.requestMtu(deviceId: id, mtu: 250);
        final TxCharacteristic = QualifiedCharacteristic(
            characteristicId: TxCharacteristicUuid,
            serviceId: serviceUuid,
            deviceId: id);
        final subs = flutterReactiveBle
            .subscribeToCharacteristic(TxCharacteristic)
            .listen((data) {
          setState(() {
            log = '${DateTime.now()}: ${String.fromCharCodes(data)}';
            power = String.fromCharCodes(data).split(',')[1];
            rpm = String.fromCharCodes(data).split(',')[2];
            speed = String.fromCharCodes(data).split(',')[3];
            currentPosition = LatLng(
                double.parse(String.fromCharCodes(data).split(',')[4]),
                double.parse(String.fromCharCodes(data).split(',')[5]));
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
          body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: currentPosition,
              zoom: 8.0,
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
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              child: Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      if (_connected)
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: handleMeasurement,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(120, 40),
                              ),
                              child: Text(isMeasuring ? '計測終了' : '計測開始',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ),
                            Container(
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('経過時間： $elapsedTime s',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: () {
                            _connectToDevice(deviceId);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 40),
                          ),
                          child: Text('Bluetooth接続',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              )),
                        )
                    ],
                  )),
            ),
          ),
          Positioned(
              right: 16,
              top: 25,
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text('パワー: $power w',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              )),
          Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                children: [
                  Text('$log'),
                  Container(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 120,
                        ),
                        child: Text('スピード： $speed m/s',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                ],
              )),
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text('ペラ回転数： $rpm rpm',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          )
        ],
      )),
    );
  }
}
