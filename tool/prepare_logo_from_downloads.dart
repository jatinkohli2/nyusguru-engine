// Reads ~/Downloads/NyusGuru_7.png and writes:
// - nyusguru_logo_source.png — full copy
// - app_logo_mark.png — square crop (center-outward, max size), downscaled
// - app_icon.png — same crop scaled to 1024² for launcher icons
//
// Crop rule: start from the geometric center of the artwork and grow a square
// symmetrically until the square hits an edge — largest centered square inside
// the bitmap (not the whole wide banner; equal trim left/right on widescreen art).
//
// Run: dart run tool/prepare_logo_from_downloads.dart
//
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _src = '/Users/jatinkohli/Downloads/NyusGuru_7.png';

/// Max pixel size for in-app PNG (square).
const int _kAppLogoExportSide = 512;

const int _kLauncherSquare = 1024;

/// Largest square centered on the image; expands evenly from the middle outward.
img.Image _squareCropCenterOutward(img.Image src) {
  final w = src.width;
  final h = src.height;
  final side = math.min(w, h);
  final x = ((w - side) / 2).floor().clamp(0, w - side);
  final y = ((h - side) / 2).floor().clamp(0, h - side);
  return img.copyCrop(src, x: x, y: y, width: side, height: side);
}

void main() {
  final f = File(_src);
  if (!f.existsSync()) {
    stderr.writeln('Missing source: $_src');
    exit(1);
  }
  final decoded = img.decodeImage(f.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Decode failed');
    exit(1);
  }

  final w = decoded.width;
  final h = decoded.height;
  if (w <= 0 || h <= 0) {
    stderr.writeln('Invalid dimensions');
    exit(1);
  }

  final square = _squareCropCenterOutward(decoded);

  img.Image appLogo = square;
  if (square.width > _kAppLogoExportSide) {
    appLogo = img.copyResize(
      square,
      width: _kAppLogoExportSide,
      height: _kAppLogoExportSide,
      interpolation: img.Interpolation.linear,
    );
  }

  final launcher = img.copyResize(
    square,
    width: _kLauncherSquare,
    height: _kLauncherSquare,
    interpolation: img.Interpolation.linear,
  );

  final repoRoot = Directory.current.path;
  final markPath = '$repoRoot/assets/images/app_logo_mark.png';
  final sourceCopyPath = '$repoRoot/assets/images/nyusguru_logo_source.png';
  final iconPath = '$repoRoot/assets/images/app_icon.png';

  File(markPath).writeAsBytesSync(img.encodePng(appLogo));
  File(sourceCopyPath).writeAsBytesSync(f.readAsBytesSync());
  File(iconPath).writeAsBytesSync(img.encodePng(launcher));

  final ox = ((w - square.width) / 2).floor();
  final oy = ((h - square.height) / 2).floor();
  stdout.writeln(
    'Center-outward square ${square.width}x${square.height} from ${w}x$h at ($ox,$oy)',
  );
  stdout.writeln('Wrote $markPath ${appLogo.width}x${appLogo.height}');
  stdout.writeln('Wrote $iconPath ${_kLauncherSquare}x$_kLauncherSquare');
  stdout.writeln('Copied full source to $sourceCopyPath');
}
