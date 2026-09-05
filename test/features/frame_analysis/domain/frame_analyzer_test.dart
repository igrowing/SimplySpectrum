import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analyzer.dart';

/// Builds a tiny fully-planar YUV420 frame where every pixel has the same
/// Y/U/V value, so the whole frame analyzes as one uniform color/luma.
RawCameraFrame _uniformFrame({
  required int width,
  required int height,
  required int y,
  required int u,
  required int v,
}) {
  final yPlane = Uint8List(width * height)..fillRange(0, width * height, y);
  final chromaWidth = width ~/ 2;
  final chromaHeight = height ~/ 2;
  final uPlane = Uint8List(chromaWidth * chromaHeight)
    ..fillRange(0, chromaWidth * chromaHeight, u);
  final vPlane = Uint8List(chromaWidth * chromaHeight)
    ..fillRange(0, chromaWidth * chromaHeight, v);

  return RawCameraFrame(
    width: width,
    height: height,
    format: RawFrameFormat.yuv420,
    planes: [
      RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
      RawFramePlane(
        bytes: uPlane,
        bytesPerRow: chromaWidth,
        pixelStride: 1,
      ),
      RawFramePlane(
        bytes: vPlane,
        bytesPerRow: chromaWidth,
        pixelStride: 1,
      ),
    ],
  );
}

/// Builds a YUV420 frame where the top [topRows] rows are one color and
/// the remaining rows are another, for testing multi-color scenarios.
RawCameraFrame _twoColorFrame({
  required int width,
  required int height,
  required int topRows,
  required int y1,
  required int u1,
  required int v1,
  required int y2,
  required int u2,
  required int v2,
}) {
  final yPlane = Uint8List(width * height);
  final chromaWidth = width ~/ 2;
  final chromaHeight = height ~/ 2;
  final uPlane = Uint8List(chromaWidth * chromaHeight);
  final vPlane = Uint8List(chromaWidth * chromaHeight);

  for (var y = 0; y < height; y++) {
    final isTop = y < topRows;
    final yVal = isTop ? y1 : y2;
    for (var x = 0; x < width; x++) {
      yPlane[y * width + x] = yVal;
    }
  }
  for (var y = 0; y < chromaHeight; y++) {
    final isTop = (y * 2) < topRows;
    for (var x = 0; x < chromaWidth; x++) {
      uPlane[y * chromaWidth + x] = isTop ? u1 : u2;
      vPlane[y * chromaWidth + x] = isTop ? v1 : v2;
    }
  }

  return RawCameraFrame(
    width: width,
    height: height,
    format: RawFrameFormat.yuv420,
    planes: [
      RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
      RawFramePlane(
        bytes: uPlane,
        bytesPerRow: chromaWidth,
        pixelStride: 1,
      ),
      RawFramePlane(
        bytes: vPlane,
        bytesPerRow: chromaWidth,
        pixelStride: 1,
      ),
    ],
  );
}

void main() {
  group('analyzeFrame', () {
    test('a bright, saturated red frame fills the red end of the spectrum', () {
      // Y=150 (bright), U=90 (<128), V=200 (>128) skews strongly red.
      final frame = _uniformFrame(
        width: 32,
        height: 32,
        y: 150,
        u: 90,
        v: 200,
      );

      final result = analyzeFrame(frame, sampleStep: 4);

      expect(result.spectrum.totalOccurrences, greaterThan(0));
      final avgNm = result.spectrum.weightedAverageNm;
      expect(avgNm, isNotNull);
      expect(avgNm, greaterThan(600)); // red end of 400-700nm range
    });

    test('a mid-grey frame contributes to luminosity but not the spectrum', () {
      // U=V=128 is exactly neutral grey (zero chroma).
      final frame = _uniformFrame(
        width: 32,
        height: 32,
        y: 128,
        u: 128,
        v: 128,
      );

      final result = analyzeFrame(frame, sampleStep: 4);

      expect(result.luminosity.totalOccurrences, greaterThan(0));
      expect(result.spectrum.totalOccurrences, 0);
      // Neutral grey Y=U=V=128 should decode to a roughly-equal R/G/B
      // average color.
      final average = result.averageColor;
      expect(average, isNotNull);
      expect(average!.r, closeTo(average.g, 5));
      expect(average.g, closeTo(average.b, 5));
    });

    test('locates the brightest and darkest regions when requested', () {
      const width = 96;
      const height = 96;
      // Mid-grey background with a bright block near the top-right and a
      // dark block near the bottom-left.
      final yPlane = Uint8List(width * height)
        ..fillRange(0, width * height, 120);
      void fillBlock(int x0, int y0, int x1, int y1, int value) {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            yPlane[y * width + x] = value;
          }
        }
      }

      fillBlock(60, 12, 84, 36, 235); // bright, centered around (72, 24)
      fillBlock(12, 60, 36, 84, 12); // dark, centered around (24, 72)

      const chromaWidth = width ~/ 2;
      const chromaHeight = height ~/ 2;
      final neutral = Uint8List(chromaWidth * chromaHeight)
        ..fillRange(0, chromaWidth * chromaHeight, 128);

      final frame = RawCameraFrame(
        width: width,
        height: height,
        format: RawFrameFormat.yuv420,
        planes: [
          RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
        ],
      );

      final result = analyzeFrame(
        frame,
        locateBrightestPoint: true,
        locateDarkestPoint: true,
      );

      final brightest = result.brightestRegion;
      final darkest = result.darkestRegion;
      expect(brightest, isNotNull);
      expect(darkest, isNotNull);

      // Marker centroid lands on the block, not on background noise.
      expect(brightest!.point.normalizedX, closeTo(72 / width, 0.08));
      expect(brightest.point.normalizedY, closeTo(24 / height, 0.08));
      expect(darkest!.point.normalizedX, closeTo(24 / width, 0.08));
      expect(darkest.point.normalizedY, closeTo(72 / height, 0.08));

      // Region mean luma reflects the block, not the mid-grey field.
      expect(brightest.meanLuma, greaterThan(200));
      expect(darkest.meanLuma, lessThan(40));

      // Bounds enclose the centroid.
      expect(
        brightest.bounds.left,
        lessThanOrEqualTo(brightest.point.normalizedX),
      );
      expect(
        brightest.bounds.right,
        greaterThanOrEqualTo(brightest.point.normalizedX),
      );
    });

    test('a single hot cell does not outvote a real bright region', () {
      const width = 96;
      const height = 96;
      final yPlane = Uint8List(width * height)
        ..fillRange(0, width * height, 100);
      // A genuine bright region...
      for (var y = 20; y < 44; y++) {
        for (var x = 20; x < 44; x++) {
          yPlane[y * width + x] = 200;
        }
      }
      // ...and one lone blown-out pixel in the far corner.
      yPlane[(height - 1) * width + (width - 1)] = 255;

      const chromaWidth = width ~/ 2;
      const chromaHeight = height ~/ 2;
      final neutral = Uint8List(chromaWidth * chromaHeight)
        ..fillRange(0, chromaWidth * chromaHeight, 128);
      final frame = RawCameraFrame(
        width: width,
        height: height,
        format: RawFrameFormat.yuv420,
        planes: [
          RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
        ],
      );

      final brightest = analyzeFrame(
        frame,
        locateBrightestPoint: true,
      ).brightestRegion;

      expect(brightest, isNotNull);
      // Centroid is on the region near (32, 32), not the corner pixel.
      expect(brightest!.point.normalizedX, closeTo(32 / width, 0.15));
      expect(brightest.point.normalizedY, closeTo(32 / height, 0.15));
    });

    test('a near-black edge band is ignored by darkest-region detection', () {
      const width = 120;
      const height = 120;
      // Mid-grey field, a 3px pure-black border (padding / optical-black
      // artifact), and a genuinely dark - but not black - block in the
      // interior.
      final yPlane = Uint8List(width * height)
        ..fillRange(0, width * height, 140);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final onBorder = x < 3 || x >= width - 3 || y < 3 || y >= height - 3;
          if (onBorder) yPlane[y * width + x] = 0;
        }
      }
      for (var y = 50; y < 74; y++) {
        for (var x = 50; x < 74; x++) {
          yPlane[y * width + x] = 45;
        }
      }

      const chromaWidth = width ~/ 2;
      const chromaHeight = height ~/ 2;
      final neutral = Uint8List(chromaWidth * chromaHeight)
        ..fillRange(0, chromaWidth * chromaHeight, 128);
      final frame = RawCameraFrame(
        width: width,
        height: height,
        format: RawFrameFormat.yuv420,
        planes: [
          RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
          RawFramePlane(
            bytes: neutral,
            bytesPerRow: chromaWidth,
            pixelStride: 1,
          ),
        ],
      );

      final darkest = analyzeFrame(
        frame,
        locateDarkestPoint: true,
      ).darkestRegion;

      expect(darkest, isNotNull);
      // Marker is on the interior block (~62, 62), not stuck on an edge.
      expect(darkest!.point.normalizedX, closeTo(62 / width, 0.12));
      expect(darkest.point.normalizedY, closeTo(62 / height, 0.12));
      expect(darkest.meanLuma, closeTo(45, 10));
    });

    test(
      'a big region with a black core beats a small uniformly-dim patch',
      () {
        const width = 160;
        const height = 160;
        final yPlane = Uint8List(width * height)
          ..fillRange(0, width * height, 86);

        // Region A: large, mean slightly higher, but with a genuinely
        // black core - like a deep shadow under a desk broken up by
        // brighter clutter.
        for (var y = 40; y < 100; y++) {
          for (var x = 30; x < 90; x++) {
            yPlane[y * width + x] = 13;
          }
        }
        for (var y = 60; y < 80; y++) {
          for (var x = 50; x < 70; x++) {
            yPlane[y * width + x] = 6; // black core, centered ~(60, 70)
          }
        }

        // Region B: smaller, uniformly dim with a *lower mean* than A but
        // no truly-black cell - like a shadowed shelf cubby. Must not win.
        for (var y = 40; y < 64; y++) {
          for (var x = 110; x < 134; x++) {
            yPlane[y * width + x] = 11;
          }
        }

        const chromaWidth = width ~/ 2;
        const chromaHeight = height ~/ 2;
        final neutral = Uint8List(chromaWidth * chromaHeight)
          ..fillRange(0, chromaWidth * chromaHeight, 128);
        final frame = RawCameraFrame(
          width: width,
          height: height,
          format: RawFrameFormat.yuv420,
          planes: [
            RawFramePlane(bytes: yPlane, bytesPerRow: width, pixelStride: 1),
            RawFramePlane(
              bytes: neutral,
              bytesPerRow: chromaWidth,
              pixelStride: 1,
            ),
            RawFramePlane(
              bytes: neutral,
              bytesPerRow: chromaWidth,
              pixelStride: 1,
            ),
          ],
        );

        final darkest = analyzeFrame(
          frame,
          locateDarkestPoint: true,
        ).darkestRegion;

        expect(darkest, isNotNull);
        // Marker sits on region A's black core, not region B.
        expect(darkest!.point.normalizedX, closeTo(60 / width, 0.1));
        expect(darkest.point.normalizedY, closeTo(70 / height, 0.1));
      },
    );

    test('non-yuv420 frames return empty histograms rather than throwing', () {
      final frame = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.bgra8888,
        planes: [
          RawFramePlane(bytes: Uint8List(64), bytesPerRow: 16, pixelStride: 4),
        ],
      );

      final result = analyzeFrame(frame);

      expect(result.spectrum.totalOccurrences, 0);
      expect(result.luminosity.totalOccurrences, 0);
      expect(result.averageColor, isNull);
    });

    test(
      'a dark colored frame is excluded from the spectrum (luma threshold '
      'filters sensor noise)',
      () {
        // Y=30, U=200, V=128 produces a dim blue-violet with luma ~30
        // and chroma well above 0.12 — it would have passed the old
        // luma>=8 threshold but is filtered by luma>=40.
        final frame = _uniformFrame(
          width: 32,
          height: 32,
          y: 30,
          u: 200,
          v: 128,
        );

        final result = analyzeFrame(frame, sampleStep: 4);

        // Luminosity still records these pixels — only the spectrum
        // histogram filters by luma.
        expect(result.luminosity.totalOccurrences, greaterThan(0));
        expect(result.spectrum.totalOccurrences, 0);
      },
    );

    test(
      'violet-end bins are capped to the max of the remaining bins',
      () {
        // A frame that is 75% bright violet (maps to ~400nm) and 25%
        // bright red (maps to ~650nm). Without the cap, bin 0 would
        // dwarf every other bin and crush the Y-axis scale.
        //
        // Violet: Y=60, U=196, V=179 -> RGB ~(131, 0, 181) -> 400nm
        // Red:    Y=76, U=85,  V=255 -> RGB ~(254, 0, 0)   -> ~650nm
        final frame = _twoColorFrame(
          width: 32,
          height: 32,
          topRows: 24,
          y1: 60,
          u1: 196,
          v1: 179, // top 24 rows = violet
          y2: 76,
          u2: 85,
          v2: 255, // bottom 8 rows = red
        );

        final result = analyzeFrame(frame, sampleStep: 4);
        final bins = result.spectrum.bins;

        // The violet signal must still be present (not zeroed).
        expect(bins[0], greaterThan(0));

        // The red signal must be present in the ~645nm region.
        const redBin = 645 - 400; // bin index 245
        expect(bins[redBin], greaterThan(0));

        // After capping, no bin 0-3 may exceed the max of bins 4+.
        final realSignalMax = bins
            .sublist(4)
            .fold(0, (max, v) => v > max ? v : max);
        for (var i = 0; i < 4; i++) {
          expect(bins[i], lessThanOrEqualTo(realSignalMax));
        }
      },
    );
  });
}
