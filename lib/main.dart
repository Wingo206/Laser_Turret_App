import 'dart:math';

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
  var rgb;
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
  int width = 0;
  int height = 0;
  bool streamStarted = false;
  final int res = 6;
  double maxCircleSize = 30;
  double minCircleSize = 7;
  double upperThreshold = 50;
  List rgb;
  List<String> modes = ['none', 'rgb', 'grayscale', 'gaussian filter', 'edges', 'Gradient Magnitude Threshold', 'double threshold', 'Hough Transform'];
  int mode = 0;
  bool calculating = false;
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
                foregroundPainter: OverlayPainter(rgb, res, mode, circleX, circleY, circleR),
                child: RotatedBox(
                  quarterTurns: 2,
                  child: FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (!streamStarted) {
                          _controller.startImageStream((image) {
                            setState(() {
                              if (!calculating) {
                                setImage(image);
                              }
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
                        value: upperThreshold,
                        min: 0,
                        max: 255,
                        divisions: 32,
                        label: upperThreshold.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            upperThreshold = value;
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
  static const int angleSamples = 18;
  static const double angleInc = 2 * pi/angleSamples;
  List<List<int>>houghXPoints;
  List<List<int>>houghYPoints;
  calculateCirclePoints() {
    houghXPoints = List<List<int>>.generate(
        (maxCircleSize - minCircleSize).toInt(),
        (r) => List<int>.generate(
            angleSamples, (i) => ((r + minCircleSize) * cos(i * angleInc)).round()));
    houghYPoints = List<List<int>>.generate(
        (maxCircleSize - minCircleSize).toInt(),
        (r) => List<int>.generate(
            angleSamples, (i) => ((r + minCircleSize) * sin(i * angleInc)).round()));
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

    calculating = true;
    final int t1 = DateTime.now().microsecondsSinceEpoch;

    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel;

    final int scaledWidth = width ~/ res;
    final int scaledHeight = height ~/ res;
    if (rgb == null || rgb.length != scaledWidth) {
      this.rgb = List<List<int>>.generate(
          scaledWidth, (i) => List<int>.filled(scaledHeight, 0, growable: false),
          growable: false);
    }
    if (mode == 1) { // rgb conversion
      for (int x = 0; x < width; x += res) {
        for (int y = 0; y < height; y += res) {
          final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * uvRowStride + x;
          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          rgb[x ~/ res][y ~/ res] = aShift |
            ((yp + vp * rMult / div1 + rConst).round().clamp(0, 255)).toInt() << 16 |
            ((yp - up * gMult1 / div2 + gConst1 - vp * gMult2 / div2 + gConst2).round().clamp(0, 255)).toInt() << 8 |
            (yp + up * bMult / div1 + bConst).round().clamp(0, 255).toInt();
        }
      }
    } else if (mode >= 2) { // grayscale
      List<List> buffer = List<List<int>>.from(rgb);
      for (int x = 0; x < width; x += res) {
        for (int y = 0; y < height; y += res) {
           buffer[x ~/ res][y ~/ res] = image.planes[0].bytes[y * uvRowStride + x];
        }
      }
      if (mode >= 3) {//apply blur
        buffer = convolution(buffer, gaussianKernel, gaussianScale, true);
        if (mode >= 4) {//edges
          final List<List<int>> dx = convolution(buffer, xKernel, 1, false);
          final List<List<int>> dy = convolution(buffer, yKernel, 1, false);
          for (int x = 0; x < scaledWidth; x++) {
            for (int y = 0; y < scaledHeight; y++) {
              buffer[x][y] = sqrt(pow(dx[x][y], 2) + pow(dy[x][y], 2)).toInt().clamp(0, 255);
            }
          }
          if (mode >= 5) {//gradient-magnitude threshold
            for (int x = 1; x < scaledWidth - 1; x++) {
              for (int y = 1; y < scaledHeight - 1; y++) {
                final double angle = atan2(dy[x][y], dx[x][y]);
                final int xOffset = cos(angle).round();
                final int yOffset = sin(angle).round();
                final int curMagnitude = buffer[x][y];
                if (curMagnitude < buffer[x + xOffset][y + yOffset] || curMagnitude < buffer[x - xOffset][y - yOffset]) {
                  buffer[x][y] = 0;
                }
              }
            }
            if (mode >= 6) {//double threshold
              final List<List<bool>> boolBuffer = create2DArray<bool>(scaledWidth, scaledHeight, false);
              for (int x = 0; x < scaledWidth; x++) {
                for (int y = 0; y < scaledHeight; y++) {
                  final int value = buffer[x][y];
                  if (value > upperThreshold) {
                    boolBuffer[x][y] = true;
                  }
                }
              }
              if (mode >= 7) {//hough transform
                List<List<List<int>>> houghAccum = List<List<List<int>>>.generate(
                        (maxCircleSize - minCircleSize).toInt(),
                        (r) => List<List<int>>.generate(
                            scaledWidth,
                            (i) => List<int>.filled(scaledHeight, 0,
                                growable: false),
                            growable: false),
                        growable: false);
                for (int r = 0; r < (maxCircleSize - minCircleSize).toInt(); r++) {//r = min + current radius
                  List<int> xPoints = houghXPoints[r];
                  List<int> yPoints = houghYPoints[r];
                  for (int x = 0; x < scaledWidth; x++) {
                    for (int y = 0; y < scaledHeight; y++) {
                      if (boolBuffer[x][y]) {
                        for (int i = 0; i < angleSamples; i++) {
                          final int x2 = x + xPoints[i];
                          final int y2 = y + yPoints[i];
                          if (x2 >= 0 && x2 < scaledWidth && y2 >= 0 &&
                              y2 < scaledHeight) {
                            houghAccum[r][x2][y2]++;
                          }
                        }
                      }
                    }
                  }
                }
                int maxValue = 0;
                int maxX = 0;
                int maxY = 0;
                int maxR = 0;
                for (int r = 0; r < (maxCircleSize - minCircleSize).toInt(); r++) {
                  for (int x = 0; x < scaledWidth; x++) {
                    for (int y = 0; y < scaledHeight; y++) {
                      if (houghAccum[r][x][y] > maxValue) {
                        maxX = x;
                        maxY = y;
                        maxR = r;
                        maxValue = houghAccum[r][x][y];
                      }
                    }
                  }
                }
                this.circleX = maxX.toDouble();
                this.circleY = maxY.toDouble();
                this.circleR = maxR.toDouble() + minCircleSize;
              } else {
                //convert boolean image to grayscale
                for (int x = 0; x < scaledWidth; x++) {
                  for (int y = 0; y < scaledHeight; y++) {
                    if (boolBuffer[x][y]) {
                      buffer[x][y] = 255;
                    } else {
                      buffer[x][y] = 0;
                    }
                  }
                }
              }
            }
          }
        }
      }
      rgb = buffer;
    }

    calculating = false;
    final int t2 = DateTime.now().microsecondsSinceEpoch;
    print("calculation "+(t2-t1).toString());
  }
}

const gaussianKernel = [1, 2, 1, 2, 4, 2, 1, 2, 1];
const xKernel = [1, 0, -1, 2, 0, -2, 1, 0, -1];
const yKernel = [1, 2, 1, 0, 0, 0, -1, -2, -1];
const gaussianScale = 16;
List<List<int>> convolution (List<List<int>> p, List<int> k, int scale, bool copyEdges) {
  final int width = p.length;
  final int height = p[0].length;

  List<List<int>> buffer = create2DArray<int>(p.length, p[0].length, 0);

  for (int x = 0; x < width-2; x++) {
    for (int y = 0; y < height-2; y++) {
      int accum =
          p[x][y]*k[0] + p[x+1][y]*k[1] + p[x+2][y]*k[2] +
          p[x][y+1]*k[3] + p[x+1][y+1]*k[4] + p[x+2][y+1]*k[5] +
          p[x][y+2]*k[6] + p[x+1][y+2]*k[7] + p[x+2][y+2]*k[8];

        /*int accum = 0;
        for(int i = 0; i < k.length; i++) {
          accum += p[i % 3 + x][i ~/ 3 + y] * k[i];
        }*/

      buffer[x+1][y+1] = (accum / scale).round();
    }
  }
  if (copyEdges) {
    for (int i = 0; i < width; i++) {
      buffer[i][0] = p[i][0];
      buffer[i][height-1] = p[i][height-1];
    }
    for (int i = 0; i < height; i++) {
      buffer[0][i] = p[0][i];
      buffer[width-1][i] = p[width-1][i];
    }
  }
  return buffer;
}

List<List<T>> create2DArray<T>(int w, int h, T defaultValue) {
  return List<List<T>>.generate(
      w, (i) => List<T>.filled(h, defaultValue, growable: false),
      growable: false);
}