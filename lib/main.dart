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
  final CameraDescription camera;

  const LaserTurretApp({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  _LaserTurretAppState createState() => _LaserTurretAppState(camera);
}

class _LaserTurretAppState extends State<LaserTurretApp> {
  final CameraDescription camera;
  final OverlayPainter painter = new OverlayPainter();

  _LaserTurretAppState(this.camera);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
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
          child: CustomPaint(
            foregroundPainter: painter,
            child: CameraScreen(
              camera: camera,
            ),
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({
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
    return Row(
      children: [
        RotatedBox(
          quarterTurns: 2,
          child: FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (!streamStarted) {
                  _controller.startImageStream((image) {
                    setState(() {
                      this.width = image.width;
                      this.height = image.height;
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
        Text("width: " + width.toString() + ", height" + height.toString()),
      ],
    );
  }
}
