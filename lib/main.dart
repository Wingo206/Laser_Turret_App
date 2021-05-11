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
  int res = 5;
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
  final int res = 4;
  List rgb;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: 720,
        height: 480,
        child: CustomPaint(
          foregroundPainter: OverlayPainter(rgb),
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
    );
  }

  static const int aShift = 0xFF000000;
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
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel;

    final int scaledWidth = width ~/ res;
    final int scaledHeight = height ~/ res;
    if (rgb == null || rgb.length != scaledWidth) {
      this.rgb = List.generate(
          scaledWidth, (i) => List.filled(scaledHeight, 0, growable: false),
          growable: false);
    }
    final int t1 = DateTime.now().microsecondsSinceEpoch;
    for (int x = 0; x < width; x += res) {
      for (int y = 0; y < height; y += res) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * uvRowStride + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color

        rgb[x ~/ res][y ~/ res] = aShift |
            ((yp + vp * rMult / div1 + rConst).round().clamp(0, 255)).toInt() << 16 |
            ((yp - up * gMult1 / div2 + gConst1 - vp * gMult2 / div2 + gConst2).round().clamp(0, 255)).toInt() << 8 |
            (yp + up * bMult / div1 + bConst).round().clamp(0, 255).toInt();
      }
    }
    final int t2 = DateTime.now().microsecondsSinceEpoch;
    print("calculation "+(t2-t1).toString());
  }
}
