// Generates a 1024×1024 square PNG for launcher_icons from the full
// `assets/images/nyusguru_logo_source.png` (e.g. exported `NyusGuru_7.png`).
// Prefer `dart run tool/prepare_logo_from_downloads.dart` after updating the
// source file, then run this if you only have a wide master asset.
// Run from repo root: dart run tool/build_square_app_icon.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int _outSide = 1024;

void main(List<String> args) {
  const srcPath = 'assets/images/nyusguru_logo_source.png';
  const outPath = 'assets/images/app_icon.png';

  final decoded = img.decodeImage(File(srcPath).readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode $srcPath');
    exit(1);
  }

  final w = decoded.width;
  final h = decoded.height;
  if (w <= 0 || h <= 0) {
    stderr.writeln('Invalid source dimensions ${w}x$h');
    exit(1);
  }

  // Cover the square: scale so both dimensions are >= _outSide, then center-crop.
  final scale = math.max(_outSide / w, _outSide / h);
  final newW = (w * scale).round();
  final newH = (h * scale).round();

  final resized = img.copyResize(
    decoded,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.linear,
  );

  final cx = (newW - _outSide) ~/ 2;
  final cy = (newH - _outSide) ~/ 2;
  final cropped = img.copyCrop(
    resized,
    x: cx,
    y: cy,
    width: _outSide,
    height: _outSide,
  );

  File(outPath).writeAsBytesSync(img.encodePng(cropped));
  stdout.writeln(
    'Wrote $outPath (${cropped.width}x${cropped.height}) from ${w}x$h → ${newW}x$newH crop@($cx,$cy)',
  );
}
