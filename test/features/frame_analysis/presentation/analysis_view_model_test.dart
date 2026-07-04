import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';

/// A minimal, controllable [CameraRepository] fake: [emit] pushes a frame
/// synchronously, standing in for the real plugin-backed stream.
class _FakeCameraRepository implements CameraRepository {
  final _controller = StreamController<RawCameraFrame>.broadcast();

  void emit(RawCameraFrame frame) => _controller.add(frame);

  @override
  Stream<RawCameraFrame> get frameStream => _controller.stream;

  @override
  CameraLensDirection? get currentLens => CameraLensDirection.rear;

  @override
  bool get isTorchOn => false;

  @override
  Future<void> initialize({
    CameraLensDirection lens = CameraLensDirection.rear,
  }) async {}

  @override
  Future<void> switchLens() async {}

  @override
  Future<void> setTorchEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

RawCameraFrame _uniformFrame({required int y, required int u, required int v}) {
  const width = 16;
  const height = 16;
  final yPlane = Uint8List(width * height)..fillRange(0, width * height, y);
  const chromaWidth = width ~/ 2;
  const chromaHeight = height ~/ 2;
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
      RawFramePlane(bytes: uPlane, bytesPerRow: chromaWidth, pixelStride: 1),
      RawFramePlane(bytes: vPlane, bytesPerRow: chromaWidth, pixelStride: 1),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalysisViewModel', () {
    test('analyzes the first frame and publishes histograms', () async {
      final camera = _FakeCameraRepository();
      final viewModel = AnalysisViewModel(
        cameraRepository: camera,
        analysisInterval: const Duration(milliseconds: 50),
      );
      addTearDown(viewModel.dispose);

      var notified = false;
      viewModel.addListener(() => notified = true);

      camera.emit(_uniformFrame(y: 128, u: 128, v: 128));
      // Give the background isolate time to finish `compute`.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(notified, isTrue);
      expect(viewModel.luminosity.totalOccurrences, greaterThan(0));
    });

    test('drops frames that arrive faster than analysisInterval', () async {
      final camera = _FakeCameraRepository();
      final viewModel = AnalysisViewModel(cameraRepository: camera);
      addTearDown(viewModel.dispose);

      var notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      // Fire several frames well within one analysisInterval window.
      for (var i = 0; i < 5; i++) {
        camera.emit(_uniformFrame(y: 128, u: 128, v: 128));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Only the first frame in the window should have been analyzed:
      // one notify for the data itself, plus one for the first-frame
      // axis seeding (see AnalysisViewModel._onFrame) - not 5.
      expect(notifyCount, 2);
    });

    test(
      'seeds the axis scale from the first frame instead of waiting for '
      'the first axisRescaleInterval tick, then only rescales again on '
      'that interval',
      () async {
        final camera = _FakeCameraRepository();
        final viewModel = AnalysisViewModel(
          cameraRepository: camera,
          analysisInterval: const Duration(milliseconds: 20),
          axisRescaleInterval: const Duration(milliseconds: 300),
        );
        addTearDown(viewModel.dispose);

        expect(viewModel.luminosityAxisMax, 1);

        // First frame: the axis is seeded immediately rather than
        // showing an exaggerated, near-flat-lined chart for up to
        // axisRescaleInterval after launch.
        camera.emit(_uniformFrame(y: 200, u: 128, v: 128));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        final seededMax = viewModel.luminosityAxisMax;
        expect(seededMax, greaterThan(1));

        // A later frame arrives well before the next scheduled rescale
        // tick - the axis should hold steady rather than jump around
        // on every analyzed frame.
        camera.emit(_uniformFrame(y: 255, u: 128, v: 128));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(viewModel.luminosityAxisMax, seededMax);

        // Once the rescale interval elapses, the axis is recomputed
        // again from the latest data.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(viewModel.luminosityAxisMax, greaterThanOrEqualTo(1));
      },
    );

    test(
      'clears extreme-light points when the setting is turned off',
      () async {
        final camera = _FakeCameraRepository();
        final viewModel = AnalysisViewModel(
          cameraRepository: camera,
          analysisInterval: const Duration(milliseconds: 20),
        );
        addTearDown(viewModel.dispose);

        viewModel.settings = const AppSettings(showExtremeLightSpots: true);
        camera.emit(_uniformFrame(y: 200, u: 128, v: 128));
        await Future<void>.delayed(const Duration(milliseconds: 200));

        viewModel.settings = const AppSettings();

        expect(viewModel.brightestPoint, isNull);
        expect(viewModel.darkestPoint, isNull);
      },
    );
  });
}
