import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reborn_ii_pilot/helper/bluetooth.dart';
import 'package:reborn_ii_pilot/screen/main.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Consumer<BluetoothProvider>(
            builder: (context, bluetoothProvider, child) {
              return Expanded(
                child: ListView.builder(
                  itemCount: bluetoothProvider.devices.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(bluetoothProvider.devices[index].name),
                      subtitle: Text(bluetoothProvider.devices[index].id),
                      onTap: () async {
                        Future<void> connectionFuture = bluetoothProvider
                            .connectToDevice(bluetoothProvider.devices[index]);
                        await connectionFuture;
                        if (bluetoothProvider.connectedSafety) {
                          // ignore: use_build_context_synchronously
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MainScreen()),
                          );
                        } else {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connection failed'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            },
          )
        ],
      )),
    );
  }
}
