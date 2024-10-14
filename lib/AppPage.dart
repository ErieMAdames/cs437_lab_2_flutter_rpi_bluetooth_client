import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class AppPage extends StatefulWidget {
  final BluetoothDevice server;

  const AppPage({this.server});

  @override
  _AppPage createState() => new _AppPage();
}

class _AppPage extends State<AppPage> {
  BluetoothConnection connection;
  int speed = 30;
  String message = "";
  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;
  Timer _timer;
  // Example 100x100 grid (use your actual data structure)
  final int gridSize = 100;
  List<List<int>> grid = List.generate(100, (i) => List.generate(100, (j) => 0));

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
    _startSendingMessages();
  }
  void _startSendingMessages() {
    _stopTimer(); // Stop any existing timer before starting a new one

    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _sendMessage('update');  // Send message every 100ms
    });
  }

  // Stop the timer
  void _stopTimer() {
    if (_timer != null && _timer.isActive) {
      _timer.cancel();
    }
  }
  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String currentMessage = """Direction:
    Set Speed: 30
    Speed: 0.0
    Distance Traveled: 0.0
    Pi CPU Temp: 0.0
    Battery Voltage: 0.0""";
    if (message != '') {
      Map<String, dynamic> carData = jsonDecode(message);
      print(carData);
      String currentSpeed = (carData['speed'] + .0).toStringAsFixed(2);
      String distanceTraveled = (carData['distanceTraveled'] + .0).toStringAsFixed(2);
      String cpuTemp = (carData['cpuTemp'] + .0).toStringAsFixed(2);
      String battery = (carData['battery'] + .0).toStringAsFixed(2);
      int x = carData['x'];
      int y = carData['y'];
      int obstacle = carData['obstacle'];
      String current_angle = (carData['current_angle'] + .0).toStringAsFixed(2);
      String angle = (carData['angle'] + .0).toStringAsFixed(2);
      currentMessage = """
Direction: $angle
Set Speed: $speed
Speed: $currentSpeed cm/S
Distance Traveled: $distanceTraveled cm
Pi CPU Temp: $cpuTemp C
Battery Voltage: $battery""";
      if (x >= 0 && x < 100 && y >= 0 && y < 100) {
        grid[99 - y][x] = obstacle;
        int radius = 5;
        for (int i = x - radius; i <= x + radius; i++) {
          for (int j = y - radius; j <= y + radius; j++) {
            if (sqrt(pow(i - x, 2) + pow(j - y, 2)) <= radius) {  // Check if point is inside the circle
              if (i >= 0 && i < 100 && j >= 0 && j < 100) {  // Check if within grid bounds
                grid[99 - j][i] = 1;  // Mark the circle point as 1 (or any other value)
              }
            }
          }
        }
      }
    }
    final Text command = Text("$currentMessage");
    return Scaffold(
      appBar: AppBar(title: Text("Picar Controls")),
      resizeToAvoidBottomInset : false,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Section 1: Display Grid
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(0.5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double cellSize = constraints.maxWidth / gridSize;
                    return Container(
                      child: GridView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          childAspectRatio: 1,
                        ),
                        itemCount: gridSize * gridSize,
                        itemBuilder: (context, index) {
                          int row = index ~/ gridSize;
                          int col = index % gridSize;
                          return Container(
                            margin: EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              color: grid[row][col] == 1 ? Colors.red : Colors.green,
                            ),
                            width: cellSize,
                            height: cellSize,
                          );
                        },
                      ),
                      width: cellSize * 100,
                      height: cellSize * 100,
                      margin: const EdgeInsets.all(0),
                      padding: const EdgeInsets.all(0),
                    );
                  },
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Listener(
                          onPointerDown: (_) {
                            print("up button pressed");
                            _stopTimer();
                            _sendMessage("up");
                            _startSendingMessages();
                          },
                          onPointerUp: (_) {
                            print("up button released");
                            _stopTimer();
                            _sendMessage("stop");
                            _startSendingMessages();
                          },
                          child: Icon(
                            Icons.arrow_upward,
                            size: 50,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Listener(
                              onPointerDown: (_) {
                                print("Left button pressed");
                                _stopTimer();
                                _sendMessage("left");
                                _startSendingMessages();
                              },
                              onPointerUp: (_) {
                                print("Left button released");
                                _stopTimer();
                                _sendMessage("stop");
                                _startSendingMessages();
                              },
                              child: Icon(
                                Icons.arrow_back,
                                size: 50,
                              ),
                            ),
                            SizedBox(width: 50),
                            Listener(
                              onPointerDown: (_) {
                                print("Right button pressed");
                                _stopTimer();
                                _sendMessage("right");
                                _startSendingMessages();
                              },
                              onPointerUp: (_) {
                                print("Right button released");
                                _stopTimer();
                                _sendMessage("stop");
                                _startSendingMessages();
                              },
                              child: Icon(
                                Icons.arrow_forward,
                                size: 50,
                              ),
                            ),
                          ],
                        ),
                        Listener(
                          onPointerDown: (_) {
                            print("Down button pressed");
                            _stopTimer();
                            _sendMessage("down");
                            _startSendingMessages();
                          },
                          onPointerUp: (_) {
                            print("Down button released");
                            _stopTimer();
                            _sendMessage("stop");
                            _startSendingMessages();
                          },
                          child: Icon(
                            Icons.arrow_downward,
                            size: 50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [ 
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                speed = max(0, speed - 1);
                                _stopTimer();
                                _sendMessage("speed:" + speed.toString());
                                _startSendingMessages();
                              },
                              child: const Text(
                                'Slow down',
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                speed = min(100, speed + 1);
                                _stopTimer();
                                _sendMessage("speed:" + speed.toString());
                                _startSendingMessages();
                              },
                              child: const Text(
                                'Speed up',
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            print("Scan button pressed");
                            _stopTimer();
                            _sendMessage("scan");
                            grid = List.generate(100, (i) => List.generate(100, (j) => 0));
                            _startSendingMessages();
                          },
                          child: const Text(
                            'Scan',
                          ),
                      )
                    ]
                  ),
                ),
              ),

              ],
            ),
            // Section 2: Arrow Controls (Up, Down, Left, Right)

            // Section 3: Display Text
            Expanded(
              flex: 1,
              child: Center(
                child: command,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }
    String dataString = String.fromCharCodes(buffer);
    print(dataString);
    setState(() {
      message = dataString;
    });
  }

  void _sendMessage(String text) {
    text = text.trim();
    if (text.length > 0) {
      try {
        print("Sending message: $text");
        connection.output.add(utf8.encode(text));
        connection.output.allSent;
        print("Message sent");
      } catch (e) {
        print("Error sending message: $e");
        setState(() {});
      }
    }
  }
}
