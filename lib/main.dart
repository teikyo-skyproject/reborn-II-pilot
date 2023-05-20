import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  LatLng _center = LatLng(35.681236, 139.767125);
  String speed = '速度: 0000.0000';
  String power = 'パワー: 0000.0000';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'reborn-II-pilot',
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            center: _center,
            zoom: 10.0,
            interactiveFlags: InteractiveFlag.all,
            enableScrollWheel: true,
            scrollWheelVelocity: 0.00001,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.jp/{z}/{x}/{y}.png",
              userAgentPackageName: 'land_place',
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.all(15.0),
                    child: ElevatedButton(
                        onPressed: () {},
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
                children: [
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
                                    speed,
                                    style: TextStyle(
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(
                                    power,
                                    style: TextStyle(
                                      fontSize: 20,
                                    ),
                                  ),
                                ]),
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
