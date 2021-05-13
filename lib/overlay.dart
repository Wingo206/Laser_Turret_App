import 'dart:ui';

import 'package:flutter/material.dart';

const int aShift = 0xFF000000;

class OverlayPainter extends CustomPainter {
  final List rgb;
  final int drawMode;
  final int res;
  OverlayPainter(this.rgb, this.res, this.drawMode);

  @override
  void paint(Canvas canvas, Size size) {
    if (rgb == null) {
      return;
    }
    final int t1 = DateTime.now().microsecondsSinceEpoch;
    if (drawMode >= 1) { //
      for (int x = 0; x < rgb.length; x++) {
        for (int y = 0; y < rgb[0].length; y++) {
          var c = rgb[x][y];
          Paint paint = new Paint()
            ..color = new Color((drawMode == 1) ? c :  (aShift | c << 16 | c << 8 | c))
            ..style = PaintingStyle.fill;
          canvas.drawRect(
              new Rect.fromPoints(
                  Offset((x * res).toDouble(), (y * res).toDouble()),
                  Offset(((x + 1) * res).toDouble(), ((y + 1) * res).toDouble())),
              paint);
        }
      }
    }
    canvas.drawRect(new Rect.fromPoints(Offset(0,0),Offset(720,480)), Paint()..color=Color(0xFFFF0000)..style = PaintingStyle.stroke..strokeWidth = 2);
    final int t2 = DateTime.now().microsecondsSinceEpoch;
    //print("rendering"+(t2-t1).toString());
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) =>
    //rgb != oldDelegate.rgb;
    true;


}
