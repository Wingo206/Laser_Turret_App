import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(new LaserTurretApp());
}

class LaserTurretApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Laser Turret App",
      home: CameraScreen(

      )
    );
  }
}

class CameraScreen extends StatefulWidget {

}