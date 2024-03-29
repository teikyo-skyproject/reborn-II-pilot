import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:reborn_ii_pilot/helper/bluetooth.dart';
import 'package:reborn_ii_pilot/screen/scan.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Local Notification Setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool isMeasuring = false; // 計測開始・停止のフラグ
  bool isTimerStarted = false;
  int elapsedTime = 0;
  Timer? lifecyecleTimer;
  Timer? timer;
  Timer? sec1Timer;
  List<LatLng> coordinates = [];
  String rpm = 'EEE.EE';
  String power = 'EEE.EE';
  String speed = 'EEE.EE';
  double lat = 35.28996558322712;
  double lng = 136.251955302951;
  double deg = 0;

  // Map Setup
  MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _requestIOSPermission();
    _initializePlatformSpecifics();
    mapController = MapController();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      lifecycle();
    });
  }

  @override
  void dispose() {
    lifecyecleTimer?.cancel();
    super.dispose();
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

  void lifecycle() {
    if (mounted) {
      lifecyecleTimer =
          Timer.periodic(Duration(milliseconds: 500), (lifecycleTime) {
        setState(() {
          rpm = Provider.of<BluetoothProvider>(context, listen: true).rpm;
          power = Provider.of<BluetoothProvider>(context, listen: true).power;
          speed = Provider.of<BluetoothProvider>(context, listen: true).speed;
          lat = double.parse(
              Provider.of<BluetoothProvider>(context, listen: true).lat);
          lng = double.parse(
            Provider.of<BluetoothProvider>(context, listen: true).lng,
          );
          deg = double.parse(
              Provider.of<BluetoothProvider>(context, listen: true).deg);
          mapController.move(LatLng(lat, lng), 14.0);
        });
      });
    }
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
        Provider.of<BluetoothProvider>(context, listen: true)
            .actionMeasurement(true);
        _showNotification('計測開始', currentTime);
      }
      if (isMeasuring) {
        timer?.cancel();
        Provider.of<BluetoothProvider>(context, listen: true)
            .actionMeasurement(false);
        Provider.of<BluetoothProvider>(context).saveLog();
        _showNotification('計測終了', currentTime);
      }
      isMeasuring = !isMeasuring;
      isTimerStarted = !isTimerStarted;
    });
  }

  void handleTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedTime++;
        coordinates.add(LatLng(lat, lng));
      });
    });
  }

  void handleDisconnect() {
    Provider.of<BluetoothProvider>(context, listen: true).disconnectToDevice();
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
                  center: LatLng(lat, lng),
                  zoom: 14.0,
                  interactiveFlags: InteractiveFlag.all,
                  enableScrollWheel: true,
                  scrollWheelVelocity: 0.00001,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                          point: LatLng(lat, lng),
                          width: 60,
                          height: 60,
                          builder: (ctx) => Transform.rotate(
                                angle: deg * pi / 180.0,
                                child: SvgPicture.asset(
                                  'images/airplane.svg',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                          anchorPos: AnchorPos.align(AnchorAlign.center))
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                          points: coordinates,
                          color: Colors.blue,
                          strokeWidth: 3.0),
                      Polyline(points: [
                        LatLng(35.29200671826664, 136.25410089667272),
                        LatLng(35.4137191012542, 136.11774778263523)
                      ], color: Colors.red, strokeWidth: 3.0),
                      Polyline(points: [
                        LatLng(35.29207844771564, 136.25454987209068),
                        LatLng(35.23025002646102, 136.06847046082993)
                      ], color: Colors.red, strokeWidth: 3.0),
                    ],
                  )
                ],
              ),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        if (Provider.of<BluetoothProvider>(context,
                                listen: true)
                            .connectedSafety)
                          Column(
                            children: [
                              ElevatedButton(
                                  onPressed: handleMeasurement,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(120, 40),
                                  ),
                                  child: Text(
                                    isMeasuring ? '計測終了' : '計測開始',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  )),
                              Container(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    '経過時間: $elapsedTime s',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                  onPressed: () => handleDisconnect(),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(120, 40),
                                  ),
                                  child: const Text(
                                    '切断',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  )),
                              ElevatedButton(
                                  onPressed: () {
                                    Provider.of<BluetoothProvider>(context,
                                            listen: true)
                                        .reconectWebSocket();
                                  },
                                  child: const Text('ws再接続')),
                              ElevatedButton(
                                  onPressed: () {
                                    Provider.of<BluetoothProvider>(context,
                                            listen: true)
                                        .disconnectWebSocket();
                                  },
                                  child: const Text('ws切断')),
                            ],
                          )
                        else
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ScanScreen()),
                                  );
                                },
                                child: const Text(
                                  'Bluetooth接続',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          )
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 25,
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text('パワー: ${power} w',
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        child: Text(
                            '${Provider.of<BluetoothProvider>(context, listen: true).log}'),
                      ),
                      Container(
                        color: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(10.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 250,
                            ),
                            child: Text('スピード: ${speed} m/s',
                                style: const TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )
                    ],
                  )),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text('ペラ回転数： ${rpm} rpm',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              )
            ],
          ),
        ));
  }
}
