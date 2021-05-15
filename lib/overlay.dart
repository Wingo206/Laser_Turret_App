import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const int aShift = 0xFF000000;

class OverlayPainter extends CustomPainter {
  final Uint32List rgb;
  final int width;
  final int height;
  final int drawMode;
  final int res;
  final double x, y, r;
  bool finished = false;
  OverlayPainter(this.rgb, this.width, this.height, this.res, this.drawMode, this.x, this.y, this.r);

  @override
  void paint(Canvas canvas, Size size) {
    if (rgb == null) {
      return;
    }
    final int t1 = DateTime.now().microsecondsSinceEpoch;
    if (drawMode >= 1 && drawMode < 7) { //
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          var c = rgb[x + y * width];
          Paint paint = new Paint()
            ..color = new Color(c)
            ..style = PaintingStyle.fill;
          canvas.drawRect(
              new Rect.fromPoints(
                  Offset((x * res).toDouble(), (y * res).toDouble()),
                  Offset(((x + 1) * res).toDouble(), ((y + 1) * res).toDouble())),
              paint);
        }
      }
    }
    if (drawMode >= 7) {
      Paint paint = new Paint()
        ..color = Color.fromARGB(255, 255, 0, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      print("circle: " + x.toString() + ", " + y.toString() + ", " + r.toString());
      canvas.drawCircle(Offset(x * res, y * res), r * res, paint);
    }
    canvas.drawRect(new Rect.fromPoints(Offset(0,0),Offset(720,480)), Paint()..color=Color(0xFFFF0000)..style = PaintingStyle.stroke..strokeWidth = 2);
    final int t2 = DateTime.now().microsecondsSinceEpoch;
    //print("rendering"+(t2-t1).toString());
    finished = true;
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) =>
    //rgb != oldDelegate.rgb;
    true;

  bool isFinished() {
    return finished;
  }

}
