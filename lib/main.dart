import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:timezone/data/latest.dart' as tz;
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

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
  // ロガー
  final logger = Logger(
    printer: PrettyPrinter(),
    output: MeasurementLogger(),
  );

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
      logger.i('Coordinates: $coordinates, Power: $power, Speed: $speed');
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
    timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        elapsedTime++;
      });
    });
  }

  @override
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
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(children: [
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: handleMeasurement,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 40),
                        ),
                        child: Text(isMeasuring ? '計測終了' : '計測開始',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      )
                    ]),
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
                    padding: const EdgeInsets.all(15.0),
                    child: ElevatedButton(
                        onPressed: () {
                          updateLocation();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[300],
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                        ),
                        child: const Icon(
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
                      padding: const EdgeInsets.all(15.0),
                      child: Container(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(children: [
                            Text(
                              '経過時間： $elapsedTime 秒',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'スピード: $speed KM/H',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'パワー: $power W',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            )
                          ]),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30, left: 20),
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: const TextStyle(
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

class MeasurementLogger extends LogOutput {
  @override
  void output(OutputEvent event) {
    _writeToLogFile(event);
  }

  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/measurement.log');
  }

  void _writeToLogFile(OutputEvent event) async {
    final file = await _getLocalFile();
    final sink = file.openWrite(mode: FileMode.append);
    event.lines.forEach(sink.writeln);
    await sink.flush();
    await sink.close();
  }
}
