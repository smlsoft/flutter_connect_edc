import 'dart:convert';
import 'dart:typed_data';

import 'package:connectusb/edc_message.dart';
import 'package:connectusb/edc_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Communication',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('com.example.app/usb');
  EventChannel streamChannel = const EventChannel('com.example.app/stream');
  Stream<dynamic>? _stream;
  String _response = 'No response yet';
  List<dynamic> driversList = [];
  List<dynamic> driversAvailableList = [];
  EDCResponse? response;
  Future<void> getListOfAvailableDrivers() async {
    try {
      final List<dynamic> drivers = await platform.invokeMethod('listAvailableDrivers');
      setState(() {
        driversAvailableList = drivers;
      });
      print("listAvailableDrivers of devices: $drivers");
    } on PlatformException catch (e) {
      print("Failed to get drivers: ${e.message}");
    }
  }

  Future<void> connectToDevice() async {
    try {
      final result = await platform.invokeMethod('connectToDevice');
      setState(() {
        _response = result;
      });

      print('Connection result: $result');
    } on PlatformException catch (e) {
      print('Failed to connect to the device: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    try {
      final result = await platform.invokeMethod('disconnect');
      setState(() {
        _response = result;
      });
      print('Disconnect result: $result');
    } on PlatformException catch (e) {
      print('Failed to connect to the device: ${e.message}');
    }
  }

  Future<void> sendDataToDevice() async {
    try {
      await connectToDevice();
      await _startDataStreaming();
      EdcMessage message = EdcMessage();
      List<int> datas = message.createSaleCreditCardMessage(35, "5432", "6666");

      Uint8List saleData = Uint8List.fromList(datas);
      platform.invokeMethod('sendData', {
        "dataToSend": saleData,
      });
    } on PlatformException catch (e) {
      print('Failed to connect to the device: ${e.message}');
    }
  }

  @override
  void initState() {
    super.initState();
    getListOfAvailableDrivers();
    _stream = streamChannel.receiveBroadcastStream();
    //connectToDevice();

    // eventChannel.receiveBroadcastStream().listen((dynamic data) {
    //   print("xxxxx");
    // });
  }

  Uint8List stringToBytes(String input) {
    var parts = input.substring(1, input.length - 1).split(', ');
    var intList = parts.map(int.parse).toList();
    return Uint8List.fromList(intList);
  }

  Future<void> _startDataStreaming() async {
    try {
      // Call the receiveDataFromDevice method on the native side
      final String message = await platform.invokeMethod('startDataStreaming');
      print('Data streaming started: $message');
    } on PlatformException catch (e) {
      print('Error starting data streaming: ${e.message}');
    }
  }

  Future<void> _stopDataStreaming() async {
    try {
      // Call the stopDataStreaming method on the native side
      final String message = await platform.invokeMethod('stopDataStreaming');
      print('Data streaming stopped: $message');
      Future.delayed(const Duration(seconds: 2), () {
        disconnect();
      });
    } on PlatformException catch (e) {
      print('Error stopping data streaming: ${e.message}');
    }
  }

// Call this method when you want to stop data streaming
  void _stopStreaming() {
    _stopDataStreaming();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('USB Communication')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text("Drivers List"),
            ...driversAvailableList.map((e) => Text(e["deviceId"].toString() + "-" + e["productName"])),
            Text("Response :$_response"),
            ElevatedButton(
              onPressed: () {
                sendDataToDevice();
              },
              child: const Text("SendData"),
            ),
            ElevatedButton(
              onPressed: () {
                _stopStreaming();
              },
              child: const Text("Disconnect"),
            ),
            StreamBuilder<dynamic>(
              stream: _stream,
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Awaiting data...');
                } else {
                  EDCResponse resp = EDCResponse();
                  resp.loadResponseBytes(stringToBytes(snapshot.data));
                  if (resp.isResponseSuccess()) {
                    return Text('Success: ${resp.responseCode}');
                  } else if (resp.isResponseCancel()) {
                    return Text('Cancel: ${resp.responseCode}');
                  } else if (resp.isMessageSuccessACK()) {
                    return const Text('Wait for Payment');
                  } else if (resp.isDuplicateSend()) {
                    return const Text('Duplicate Send');
                  } else {
                    return Text('Error: ${resp.responseCode}');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
