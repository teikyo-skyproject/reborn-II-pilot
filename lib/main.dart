import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'reborn-II-pilot',
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
          appBar: AppBar(
            title: Text('reborn-II-pilot'),
          ),
          body: FlutterMap(
            options: MapOptions(
              center: LatLng(35.2401, 136.0210),
              zoom: 10.0,
              interactiveFlags: InteractiveFlag.all,
              enableScrollWheel: true,
              scrollWheelVelocity: 0.00001,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.jp/{z}/{x}/{y}.png",
                userAgentPackageName: 'land_place',
              )
            ],
          )),
    );
  }
}
