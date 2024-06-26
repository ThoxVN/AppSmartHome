import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothControlPage(),
    );
  }
}

class BluetoothControlPage extends StatefulWidget {
  @override
  _BluetoothControlPageState createState() => _BluetoothControlPageState();
}

class _BluetoothControlPageState extends State<BluetoothControlPage> {
  late BluetoothConnection connection;
  bool isConnected = false;
  late stt.SpeechToText _speech;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void connectToBluetooth() async {
    BluetoothDevice? selectedDevice = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SelectBluetoothDevicePage()),
    );

    if (selectedDevice == null) return;

    try {
      connection = await BluetoothConnection.toAddress(selectedDevice.address);
      print('Connected to device ${selectedDevice.name}');
      setState(() {
        isConnected = true;
      });
    } catch (error) {
      print('Cannot connect, error: $error');
    }
  }

  void startListening() {
    if (!_speech.isListening) {
      _speech.listen(
        onResult: (result) {
          setState(() {
            _currentText = result.recognizedWords.toLowerCase();
            sendCommandToArduino(_currentText);
          });
        },
      );
    }
  }

  void sendCommandToArduino(String command) {
    if (connection.isConnected) {
      connection.output.add(utf8.encode(command + "\r\n"));
      connection.output.allSent.then((_) {
        print('Sent: $command');
      });
    } else {
      print('Not connected to any device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Control with Speech to Text'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(isConnected ? 'Connected' : 'Not Connected'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: connectToBluetooth,
              child: Text('Connect to Bluetooth'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: startListening,
              child: Text('Start Listening'),
            ),
            SizedBox(height: 20),
            Text('Current Command: $_currentText'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    if (connection.isConnected) {
      connection.dispose();
    }
  }
}

class SelectBluetoothDevicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Bluetooth Device'),
      ),
      body: FutureBuilder<List<BluetoothDevice>>(
        future: FlutterBluetoothSerial.instance.getBondedDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error.toString()}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No bonded devices found.'));
          } else {
            List<BluetoothDevice>? devices = snapshot.data;
            return ListView.builder(
              itemCount: devices!.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = devices[index];
                return ListTile(
                  title: Text(device.name ?? "Unknown Device"),
                  subtitle: Text(device.address),
                  onTap: () {
                    Navigator.pop(context, device);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
