import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';
import 'package:reborn_ii_pilot/helper/bluetooth.dart';
import 'package:reborn_ii_pilot/screen/main.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() async {
  DefaultCacheManager().emptyCache();
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMapTileCaching.initialise(); // New line
  await FMTC.instance('mapStore').manage.createAsync(); // New line
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(ChangeNotifierProvider(
      create: (context) => BluetoothProvider(),
      child: MaterialApp(
        home: MainScreen(),
      ),
    ));
  });
}
