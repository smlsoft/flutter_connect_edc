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
  String selectedDevice = "";
  TextEditingController ref1Controller = TextEditingController();
  TextEditingController ref2Controller = TextEditingController();
  TextEditingController amountController = TextEditingController();
  bool isStoping = false;

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
    if (selectedDevice == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select device'),
        ),
      );
      return;
    }
    try {
      final result = await platform.invokeMethod('connectToDevice', {
        "productName": selectedDevice,
      });
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
        isStoping = false;
      });
      print('Disconnect result: $result');
    } on PlatformException catch (e) {
      setState(() {
        isStoping = false;
      });
      print('Failed to connect to the device: ${e.message}');
    }
  }

  Future<void> sendDataToDevice() async {
    if (selectedDevice == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select device'),
        ),
      );
      return;
    }
    if (ref1Controller.text.isEmpty || ref2Controller.text.isEmpty || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
        ),
      );
      return;
    }
    try {
      await connectToDevice();
      await _startDataStreaming();
      EdcMessage message = EdcMessage();
      List<int> datas = message.createSaleCreditCardMessage(double.parse(amountController.text), ref1Controller.text, ref2Controller.text);

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
    if (isStoping) {
      return;
    }
    setState(() {
      isStoping = true;
    });
    try {
      // Call the stopDataStreaming method on the native side
      final String message = await platform.invokeMethod('stopDataStreaming');
      print('Data streaming stopped: $message');
      Future.delayed(const Duration(seconds: 2), () {
        disconnect();
      });
    } on PlatformException catch (e) {
      setState(() {
        isStoping = false;
      });
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
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text('Available Serial Ports:'),
            ...driversAvailableList.map((port) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  title: Text(port["deviceId"].toString() + "-" + port["productName"]),
                  onTap: () {
                    setState(() {
                      selectedDevice = port["productName"];
                    });

                    connectToDevice();
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            Text("selectedDevice:$selectedDevice"),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.only(top: 20),
              width: 300,
              child: TextField(
                controller: ref1Controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ref 1',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              width: 300,
              child: TextField(
                controller: ref2Controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ref 2',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              width: 300,
              child: TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Amount',
                ),
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  sendDataToDevice();
                },
                child: const Text('Pay!!')),
            const SizedBox(height: 20),
            Text("Response :$_response"),
            // ElevatedButton(
            //   onPressed: () {
            //     _stopStreaming();
            //   },
            //   child: const Text("Disconnect"),
            // ),
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
                    Future.delayed(const Duration(seconds: 1), () {
                      _stopStreaming();
                    });
                  }
                  return Column(
                    children: [
                      if (resp.isResponseSuccess()) Text('Success: ${resp.responseCode}'),
                      if (resp.isResponseCancel()) Text('Cancel: ${resp.responseCode}'),
                      if (resp.isMessageSuccessACK()) const Text('Wait for Payment'),
                      if (resp.isDuplicateSend()) const Text('Duplicate Send'),
                      Text('Transaction Code: ${resp.transactionCode ?? ''}'),
                      Text('Ref 1: ${resp.ref1 ?? ''}'),
                      Text('Ref 2: ${resp.ref2 ?? ''}'),
                      Text('Amount: ${resp.amount ?? ''}'),
                      Text('Cart Number: ${resp.cardNumber ?? ''}'),
                      Text('Holder Name: ${resp.cardHolderName ?? ''}'),
                      Text('Type: ${resp.cardIssuerName ?? ''}'),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
