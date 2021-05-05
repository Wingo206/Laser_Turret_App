import 'package:camera/camera.dart';

import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  var rgb;
  int res = 2;
  OverlayPainter(this.rgb);

  @override
  void paint(Canvas canvas, Size size) {
    if (rgb == null) {
      return;
    }
    for (int x = 0; x < rgb.length; x++) {
      for (int y = 0; y < rgb[0].length; y++) {
        var c = rgb[x][y];
        Paint paint = new Paint()
          ..strokeWidth = 3.0
          ..color = Color.fromARGB(255, c[0], c[1], c[2])
          ..style = PaintingStyle.fill;
        canvas.drawRect(
            new Rect.fromPoints(
                Offset((x * res).toDouble(), (y * res).toDouble()),
                Offset(((x + 1) * res).toDouble(), ((y + 1) * res).toDouble())),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) =>
    rgb != oldDelegate.rgb;


}
