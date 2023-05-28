import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';

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
  List<CircleMarker> circlemarkers = [];
  LatLng currentPosition = LatLng(35.28891762055586, 136.2466526902753);
  bool serviceEnabled = false;
  String text = '';
  String power = '000.000';
  String speed = '000.000';
  LocationPermission permission = LocationPermission.denied;
  MapController mapController = MapController();
  double currentHeading = 0;
  bool isMeasuring = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    updateLocation();
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
    updateLocation();
  }

  void handleMeasurement() {
    setState(() {
      isMeasuring = !isMeasuring;
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
