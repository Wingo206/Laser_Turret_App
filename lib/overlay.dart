import 'package:camera/camera.dart';

import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  List rgb;
  int res = 4;
  OverlayPainter(this.rgb);

  @override
  void paint(Canvas canvas, Size size) {
    if (rgb == null) {
      return;
    }
    final int t1 = DateTime.now().microsecondsSinceEpoch;
    for (int x = 0; x < rgb.length; x++) {
      for (int y = 0; y < rgb[0].length; y++) {
        Paint paint = new Paint()
          ..color = new Color(rgb[x][y])
          ..style = PaintingStyle.fill;
        canvas.drawRect(
            new Rect.fromPoints(
                Offset((x * res).toDouble(), (y * res).toDouble()),
                Offset(((x + 1) * res).toDouble(), ((y + 1) * res).toDouble())),
            paint);
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
