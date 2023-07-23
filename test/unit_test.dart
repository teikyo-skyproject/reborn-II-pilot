import 'package:flutter_test/flutter_test.dart';
import 'package:reborn_ii_pilot/helper/bluetooth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('lat,lng and deg unit test', () async {
    // String lat = '35.28996558322712';
    // String lng = '136.251955302951';
    // String deg = '90';
    // expect(
    //     BluetoothProvider().isValidLatLng(
    //         double.tryParse(lat), double.tryParse(lng), int.tryParse(deg)),
    //     true);

    // 複数のテストケースをテストしたい。
    List<Map<String, dynamic>> cases = [
      // 正常系
      {
        'lat': '35.28996558322712',
        'lng': '136.251955302951',
        'deg': '90',
        'expected': true
      },
      // latのみ異常
      {
        'lat': '200.28996558322712',
        'lng': '136.251955302951',
        'deg': '90',
        'expected': false
      },
      // lngのみ異常
      {
        'lat': '35.28996558322712',
        'lng': '200.251955302951',
        'deg': '90',
        'expected': false
      },
      // degのみ異常
      {
        'lat': '35.28996558322712',
        'lng': '136.251955302951',
        'deg': '1000',
        'expected': false
      },
      // degのみ異常（アルファベット）
      {
        'lat': '35.28996558322712',
        'lng': '136.251955302951',
        'deg': 'deg',
        'expected': false
      },
    ];

    for (var i = 0; i < cases.length; i++) {
      expect(
          BluetoothProvider().isValidLatLng(
              double.tryParse(cases[i]['lat']),
              double.tryParse(cases[i]['lng']),
              double.tryParse(cases[i]['deg'])),
          cases[i]['expected']);
    }
  });
}
