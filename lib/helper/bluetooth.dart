import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class BluetoothProvider extends ChangeNotifier {
  // ReactiveBle instance
  final flutterReactiveBle = FlutterReactiveBle();
  String log = 'this is log';
  List<Map<String, String>> logs = [];
  bool watchLog = false;

  // Parameter
  String time = '0';
  String power = 'EEE.EE';
  String speed = 'EEE.EE';
  String rpm = 'EEE.EE';
  String lat = '35.28996558322712';
  String lng = '136.251955302951';
  String deg = '90';

  // Scanning related
  List<DiscoveredDevice> devices = [];
  bool scanStarted = false;
  late StreamSubscription<DiscoveredDevice> scanStream;

  // Connection related
  bool connectedSafety = false;
  late StreamSubscription<ConnectionStateUpdate> connection;
  StreamSubscription<List<int>>? readData;

  BluetoothProvider() {
    scanDevice();
  }

  // Device Scan Function
  scanDevice() async {
    log = 'Permission check...';
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        return;
      }
    }
    log = 'Scanning...';

    if (scanStarted) {
      await scanStream.cancel();
    }
    scanStarted = true;
    notifyListeners();
    scanStream =
        flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      if (!devices.any((existingDevice) => existingDevice.id == device.id)) {
        log = 'Found ${device.name}';
        devices.add(device);
        notifyListeners();
      }
    }, onError: (dynamic error) {
      log = 'Error $error';
      notifyListeners();
    });
  }

  // Connect to the select device Function
  Future<void> connectToDevice(DiscoveredDevice device) async {
    Completer<void> completer = Completer();
    log = 'Connecting to ${device.name}';
    if (scanStarted) {
      await scanStream.cancel();
      scanStarted = false;
      notifyListeners();
    }
    connection = flutterReactiveBle
        .connectToDevice(
            id: device.id, connectionTimeout: Duration(seconds: 10))
        .listen((connectionState) {
      log = 'Connection state $connectionState';
      notifyListeners();
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        log = 'Connected';
        connectedSafety = true;
        flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 250);
        if (!completer.isCompleted) {
          completer.complete();
        }
        readCharacteristic(device);
      }
    }, onError: (dynamic error) {
      log = 'Error $error';
      connectedSafety = false;
    });
    return completer.future;
  }

  // Read data from the device
  readCharacteristic(DiscoveredDevice device) async {
    log = 'Reading characteristic';
    notifyListeners();
    final txCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
        serviceId: Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
        deviceId: device.id);
    final _receivedData = <int>[];
    List<String?> appData = List.filled(3, null, growable: false);
    final readData = flutterReactiveBle
        .subscribeToCharacteristic(txCharacteristic)
        .listen((data) {
      String decodedData = utf8.decode(data);
      if (decodedData.contains("app1:")) {
        appData[0] = decodedData;
      }
      if (decodedData.contains("app2:")) {
        appData[1] = decodedData;
      }
      if (decodedData.contains("app3:")) {
        appData[2] = decodedData;
      }
      if (!appData.contains(null)) {
        time = appData[0]!.split(',')[2];
        notifyListeners();
        rpm = appData[0]!.split(',')[4];
        notifyListeners();
        power = appData[0]!.split(',')[5];
        notifyListeners();
        speed = appData[2]!.split(',')[8];
        notifyListeners();

        // GPS data
        lat = (appData[1]!.split(',')[4]).replaceAll("+", "");
        notifyListeners();
        lng = (appData[1]!.split(',')[5]).replaceAll("+", "");
        notifyListeners();
        deg = appData[1]!.split(",")[8].split(".")[0];
        notifyListeners();
        log = "${appData[1]!.split(",")[7]}, ${appData[1]!.split(",")[8]}";
        notifyListeners();
        appData = List.filled(3, null, growable: false);
      }
      notifyListeners();
      if (watchLog == true) {
        logs.add({
          'time': '${time}',
          'rpm': '${rpm}',
          'power': '${power}',
          'speed': '${speed}',
          'lat': '${lat}',
          'lng': '${lng}',
          'deg': '${deg}',
        });
      }
      notifyListeners();
    }, onError: (dynamic error) {
      log = 'Error $error';
      connectedSafety = false;
      notifyListeners();
    });
  }

  // Disconnect from the device
  disconnectToDevice() async {
    log = 'Disconnecting';
    await readData?.cancel();
    await connection.cancel();
    scanStarted = true;
    connectedSafety = false;
    notifyListeners();
  }

  actionMeasurement(bool isStart) async {
    if (isStart == true) {
      watchLog = true;
    } else {
      watchLog = false;
    }
  }

  // Save log
  saveLog() async {
    log = 'Saving log';
    notifyListeners();
    if (await Permission.storage.status.isDenied) {
      if (await Permission.storage.request().isDenied) {
        return false;
      }
    }
    final directory = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS);
    final file = File(
        '$directory/${DateFormat("yyyy-MM-dd-Hms").format(DateTime.now())}.txt');
    final logText = logs.join('\n');
    logs = [];
    await file.writeAsString(logText);
    notifyListeners();
    return true;
  }
}
