import 'dart:math';
import 'dart:typed_data';

import 'package:bit_array/bit_array.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(
    LaserTurretApp(camera: firstCamera),
  );
}

class LaserTurretApp extends StatefulWidget {
  Uint32List rgb;
  final CameraDescription camera;

  LaserTurretApp({Key key, @required this.camera}) : super(key: key);

  @override
  _LaserTurretAppState createState() => _LaserTurretAppState();
}

class _LaserTurretAppState extends State<LaserTurretApp>
    with SingleTickerProviderStateMixin {
  Animation<double> animation;
  AnimationController aController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);

    Tween<double> tween = new Tween(begin: 0.0, end: 0.0);
    aController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    animation = tween.animate(aController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          aController.repeat();
        } else if (status == AnimationStatus.dismissed) {
          aController.forward();
        }
      });
  }

  @override
  dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Laser Turret App",
      theme: ThemeData.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, snapshot) {
              return CameraScreen(camera: widget.camera);
            },
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  CameraScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  int fullWidth, fullHeight, w, h = 0;
  bool streamStarted = false;
  final int res = 6;
  double maxCircleSize = 30;
  double minCircleSize = 15;
  double threshold = 50;
  Uint32List rgb;
  List<String> modes = ['None', 'RGB', 'Grayscale', 'Gaussian Blur', 'Edge Detection', 'Edge Thinning', 'Threshold', 'Hough Transform'];
  int mode = 0;
  double circleX, circleY, circleR = 0;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    calculateCirclePoints();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
      child: Row(
        children: [
          FittedBox(
            child: SizedBox(
              width: 720,
              height: 480,
              child: CustomPaint(
                foregroundPainter: OverlayPainter(rgb, w, h, res, mode, circleX, circleY, circleR),
                child: RotatedBox(
                  quarterTurns: 2,
                  child: FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (!streamStarted) {
                          _controller.startImageStream((image) {
                            setState(() {
                              setImage(image);
                            });
                          });
                          streamStarted = true;
                        }
                        return CameraPreview(_controller);
                      } else {
                        return Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: modes
                        .map(
                          (String s) => Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  mode = modes.indexOf(s);
                                });
                              },
                              child: SizedBox(
                                width: 180,
                                height: 20,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEEEEEE),
                                  ),
                                  child: Center(
                                    child: Text(s),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  Column(
                    children: [
                      Slider(
                        value: threshold,
                        min: 0,
                        max: 255,
                        divisions: 32,
                        label: threshold.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            threshold = value;
                          });
                        },
                      ),
                      Slider(
                        value: maxCircleSize,
                        min: 10,
                        max: 50,
                        divisions: 40,
                        label: maxCircleSize.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            maxCircleSize = value;
                            calculateCirclePoints();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  static const int angleSamples = 32;
  static const double angleInc = 2 * pi/angleSamples;
  Int8List houghXPoints;
  Int8List houghYPoints;
  calculateCirclePoints() {
    final int numRadius = (maxCircleSize - minCircleSize).toInt();
    houghXPoints = new Int8List(angleSamples * numRadius);
    houghYPoints = new Int8List(angleSamples * numRadius);
    for (int r = 0; r < numRadius; r++) {
      for (int i = 0; i < angleSamples; i++) {
        houghXPoints[r * angleSamples + i] = ((r + minCircleSize) * cos(i * angleInc)).round();
        houghYPoints[r * angleSamples + i] = ((r + minCircleSize) * sin(i * angleInc)).round();
      }
    }
  }

  static const int aShift = 0xff000000;
  static const int div1 = 1024;
  static const int div2 = 131072;
  static const int rMult = 1436;
  static const int rConst = -179;
  static const int gMult1 = 46549;
  static const int gConst1 = 44;
  static const int gMult2 = 93604;
  static const int gConst2 = 91;
  static const int bMult = 1814;
  static const int bConst = -227;
  void setImage(CameraImage image) {

    //speedTest();

    final int t1 = DateTime.now().microsecondsSinceEpoch;

    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel;

    w = width ~/ res;
    h = height ~/ res;
    if (rgb == null || rgb.length != w) {
      this.rgb = new Uint32List(w * h);
    }
    if (mode == 1) { // rgb conversion
      for (int x = 0; x < width; x += res) {
        for (int y = 0; y < height; y += res) {
          final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * uvRowStride + x;
          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          rgb[(x ~/ res) + w*(y ~/ res)] = aShift |
            ((yp + vp * rMult / div1 + rConst).round().clamp(0, 255)).toInt() << 16 |
            ((yp - up * gMult1 / div2 + gConst1 - vp * gMult2 / div2 + gConst2).round().clamp(0, 255)).toInt() << 8 |
            (yp + up * bMult / div1 + bConst).round().clamp(0, 255).toInt();
        }
      }
    } else if (mode >= 2) { // grayscale
      Int32List buffer = new Int32List(w * h);
      for (int x = 0; x < width; x += res) {
        for (int y = 0; y < height; y += res) {
          buffer[x ~/ res + (y ~/ res)*w] = image.planes[0].bytes[y * uvRowStride + x];
        }
      }
      if (mode >= 3) {//apply blur
        buffer = convolution (buffer, w, h, gaussianKernel, gaussianScale, true);
        if (mode >= 4) {//edges
          final Int32List dx = convolution (buffer, w, h, xKernel, 1, false);
          final Int32List dy = convolution (buffer, w, h, yKernel, 1, false);
          for (int i = 0; i < w * h; i++) {
            buffer[i] = sqrt(pow(dx[i], 2) + pow(dy[i], 2)).toInt().clamp(0, 255);
          }
          if (mode >= 5) {//gradient-magnitude threshold
            for (int x = 1; x < w - 1; x++) {
              for (int y = 1; y < h - 1; y++) {
                final double angle = atan2(dy[x+y*w], dx[x+y*w]);
                final int xOffset = cos(angle).round();
                final int yOffset = sin(angle).round();
                final int curMagnitude = buffer[x+y*w];
                if (curMagnitude < buffer[x + xOffset+(y + yOffset)*w] || curMagnitude < buffer[x - xOffset+(y - yOffset)*w]) {
                  buffer[x+y*w] = 0;
                }
              }
            }
            if (mode >= 6) {//double threshold
              final BitArray boolBuffer = new BitArray(w * h);
              for (int i = 0; i < w * h; i++) {
                final int value = buffer[i];
                if (value > threshold) {
                  boolBuffer[i] = true;
                }
              }
              if (mode >= 7) {//hough transform
                final int numRadius = (maxCircleSize - minCircleSize).toInt();
                Uint32List houghAccum = new Uint32List(numRadius * w * h);
                for (int r = 0; r < numRadius; r++) {//r = min + current radius
                  for (int x = 0; x < w; x++) {
                    for (int y = 0; y < h; y++) {
                      if (boolBuffer[x+y*w]) {
                        for (int i = 0; i < angleSamples; i++) {
                          final int x2 = x + houghXPoints[r * angleSamples + i];
                          final int y2 = y + houghYPoints[r * angleSamples + i];
                          if (x2 >= 0 && x2 < w && y2 >= 0 &&
                              y2 < h) {
                            houghAccum[r*w*h + x2 + y2 * w]++;
                          }
                        }
                      }
                    }
                  }
                }
                int maxValue = 0;
                int maxIndex = 0;
                for (int i = 0; i < numRadius * w * h; i++) {
                  if (houghAccum[i] > maxValue) {
                    maxIndex = i;
                    maxValue = houghAccum[i];
                  }
                }
                final int r = maxIndex ~/ (w * h);
                this.circleR = r.toDouble() + minCircleSize;
                this.circleX = ((maxIndex % (w * h))%w).toDouble();
                this.circleY = ((maxIndex % (w * h))~/w).toDouble();
              } else {
                //convert boolean image to grayscale
                for (int i = 0; i < w * h; i++) {
                  if (boolBuffer[i]) {
                    buffer[i] = 255;
                  } else {
                    buffer[i] = 0;
                  }
                }
              }
            }
          }
        }
      }
      for (int i = 0; i < buffer.length; i++) {
        final int c = buffer[i];
        rgb[i] = aShift | c << 16 | c << 8 | c;
      }
    }

    final int t2 = DateTime.now().microsecondsSinceEpoch;
    print("calculation "+(t2-t1).toString());
  }
}

const int aShift = 0xFF000000;
Int8List gaussianKernel = Int8List.fromList([1, 2, 1, 2, 4, 2, 1, 2, 1]);
Int8List xKernel = Int8List.fromList([1, 0, -1, 2, 0, -2, 1, 0, -1]);
Int8List yKernel = Int8List.fromList([1, 2, 1, 0, 0, 0, -1, -2, -1]);
const gaussianScale = 16;
Int32List convolution (Int32List p, int w, int h, Int8List k, int scale, bool copyEdges) {

  Int32List buffer = new Int32List(w * h);

  for (int x = 0; x < w-2; x++) {
    for (int y = 0; y < h-2; y++) {
      int accum =
          p[x+y*w]*k[0] + p[x+1+y*w]*k[1] + p[x+2+y*w]*k[2] +
          p[x+(y+1)*w]*k[3] + p[x+1+(y+1)*w]*k[4] + p[x+2+(y+1)*w]*k[5] +
          p[x+(y+2)*w]*k[6] + p[x+1+(y+2)*w]*k[7] + p[x+2+(y+2)*w]*k[8];

      buffer[x+1+(y+1)*w] = (accum / scale).round();
    }
  }
  if (copyEdges) {
    for (int i = 0; i < w; i++) {
      buffer[i] = p[i];
      buffer[i+(h-1)*w] = p[i+(h-1)*w];
    }
    for (int i = 0; i < h; i++) {
      buffer[i*w] = p[i*w];
      buffer[(i+1)*w-1] = p[(i+1)*w-1];
    }
  }
  return buffer;
}

List<List<T>> create2DArray<T>(int w, int h, T defaultValue) {
  return List<List<T>>.generate(
      w, (i) => List<T>.filled(h, defaultValue, growable: false),
      growable: false);
}

void speedTest() {
  final int w = 360;
  final int h = 240;

  //1D array
  final int t1 = DateTime.now().microsecondsSinceEpoch;
  BitArray l1 = new BitArray(w*h);
  for (int x = 0; x < w * h; x++) {
    l1.setBit(x);
  }
  int sum1 = 0;
  for (int x = 0; x < w * h; x++) {
      if (l1[x]) {
        sum1++;
      }
  }

  //2D array
  final int t2 = DateTime.now().microsecondsSinceEpoch;
  List<List<bool>> l2 = List<List<bool>>.generate(w, (i) => List<bool>.filled(h, false, growable: false), growable: false);
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      l2[x][y] = true;
    }
  }
  int sum2 = 0;
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      if (l2[x][y]) {
        sum2++;
      }
    }
  }
  print(sum2);

  final int t3 = DateTime.now().microsecondsSinceEpoch;
  final int dt1 = t2-t1;
  final int dt2 = t3-t2;
  print("1d: "+dt1.toString() + " \t 2d: " + dt2.toString() + " \t difference: " + (dt2 - dt1).toString() + "\t " + ((dt2 / dt1)*100).toString());
}