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

    test('locates brightest and darkest points when requested', () {
      const width = 16;
      const height = 16;
      final yPlane = Uint8List(width * height);
      // Bottom-right sampled cell is bright, top-left is dark; rest mid.
      for (var i = 0; i < yPlane.length; i++) {
        yPlane[i] = 100;
      }
      // With sampleStep=4, samples land on (0,0), (4,0)...; force one
      // sampled cell to be the brightest and one to be the darkest.
      yPlane[0] = 5; // (x=0,y=0) darkest
      yPlane[12 * width + 12] = 250; // (x=12,y=12) brightest

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
        sampleStep: 4,
        locateBrightestPoint: true,
        locateDarkestPoint: true,
      );

      expect(result.brightestPoint, isNotNull);
      expect(result.darkestPoint, isNotNull);
      expect(result.brightestPoint!.normalizedX, closeTo(12 / width, 0.001));
      expect(result.brightestPoint!.normalizedY, closeTo(12 / height, 0.001));
      expect(result.darkestPoint!.normalizedX, 0);
      expect(result.darkestPoint!.normalizedY, 0);
    });

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
  });
}
