import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class SelectBluetooth extends StatefulWidget {
  const SelectBluetooth({super.key});

  @override
  _SelectBluetoothState createState() => _SelectBluetoothState();
}

class _SelectBluetoothState extends State<SelectBluetooth> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Ble Scanner'),
      ),
      body: Column(children: [
        ElevatedButton(onPressed: () {}, child: const Text('Scan'))
      ]),
    ));
  }
}
