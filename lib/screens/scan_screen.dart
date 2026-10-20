import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/cyber_theme.dart';
import '../core/haptics.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../services/database_service.dart';
import '../services/dataset_repository.dart';
import '../services/food_recognizer.dart';
import '../services/scan_camera.dart';
import '../services/vn_food_repository.dart';
import '../widgets/food_log_sheet.dart';
import '../widgets/scan_button_face.dart';
import '../widgets/scan_sweep.dart';
import 'scan_result_screen.dart';

/// Returns the path of a photo picked from the gallery, or null when
/// cancelled.
typedef GalleryPicker = Future<String?> Function();

Future<String?> _pickFromGallery() async {
  // Recognition only needs a modest resolution; smaller files are faster.
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  return file?.path;
}

ScanCamera _deviceCamera() => DeviceScanCamera();

/// Full-screen in-app camera for scanning a plate, with the gallery on the
/// left of the shutter and manual logging on the right. Falls back to those
/// two actions when no camera can be used. Pops with `true` once something
/// was logged.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.datasets,
    this.vnFood,
    this.recognizer = const NoModelRecognizer(),
    this.camera = _deviceCamera,
    this.pickFromGallery = _pickFromGallery,
    this.database,
  });

  final DatasetRepository datasets;
  final VnFoodRepository? vnFood;
  final FoodRecognizer recognizer;
  final ScanCameraFactory camera;
  final GalleryPicker pickFromGallery;
  final DatabaseService? database;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final VnFoodRepository _vnFood = widget.vnFood ?? VnFoodRepository();
  ScanCamera? _camera;
  bool _cameraReady = false;

  /// True while a camera is being opened; the permission dialog itself
  /// pauses and resumes the app, which must not open a second camera.
  bool _opening = false;
  ScanCameraProblem? _problem;
  bool _torch = false;
  bool _busy = false;

  /// True while the result screen covers the camera.
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    // Load the sweep's shader now, so it is ready when the photo is.
    ScanSweep.warmUp();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera in the background and reopen it on return, as the
    // camera plugin requires.
    if (state == AppLifecycleState.inactive && _camera != null) {
      final camera = _camera!;
      _camera = null;
      setState(() {
        _cameraReady = false;
        _torch = false;
      });
      camera.dispose();
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        !_opening &&
        !_reviewing &&
        _problem == null) {
      // While the result screen is up the camera stays closed; it reopens
      // when the user comes back to it.
      _openCamera();
    }
  }

  Future<void> _openCamera() async {
    if (_opening) return;
    _opening = true;
    final camera = widget.camera();
    setState(() => _problem = null);
    try {
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraReady = true;
      });
    } on ScanCameraException catch (error) {
      await camera.dispose();
      if (mounted) setState(() => _problem = error.problem);
    } catch (_) {
      await camera.dispose();
      if (mounted) setState(() => _problem = ScanCameraProblem.failed);
    } finally {
      _opening = false;
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setTorch(!_torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      // A torch that cannot switch is not worth interrupting the user.
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !_cameraReady || _busy) return;
    setState(() => _busy = true);
    String path;
    try {
      path = await camera.takePicture();
      Haptics.strong();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _message(context.l10n.scanCaptureFailed);
      }
      return;
    }
    await _review(path);
  }

  Future<void> _gallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? path;
    try {
      path = await widget.pickFromGallery();
    } catch (_) {
      if (mounted) _message(context.l10n.scanPickFailed);
    }
    if (path == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await _review(path);
  }

  /// Opens the result for [path]; closes Scan when the plate was logged.
  /// The photo is a copy in the app cache and is deleted afterwards, so
  /// meal photos never pile up on the phone.
  Future<void> _review(String path) async {
    try {
      final data = await _vnFood.load();
      if (!mounted) return;
      await _camera?.pause();
      if (!mounted) return;
      _reviewing = true;
      final logged = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            imagePath: path,
            data: data,
            recognizer: widget.recognizer,
            database: widget.database,
          ),
        ),
      );
      _reviewing = false;
      if (!mounted) return;
      if (logged == true) {
        Navigator.pop(context, true);
        return;
      }
      if (_camera != null) {
        await _camera!.resume();
      } else if (_problem == null) {
        // The app went to the background during the review.
        await _openCamera();
      }
    } catch (_) {
      if (mounted) _message(context.l10n.scanDataFailed);
    } finally {
      _reviewing = false;
      File(path).delete().ignore();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logManually() async {
    if (_busy) return;
    List<Map<String, dynamic>> foods;
    try {
      foods = (await widget.datasets.load()).foods;
    } catch (_) {
      foods = const [];
    }
    if (!mounted) return;
    final entry = await showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => FoodLogSheet(foods: foods, date: DateTime.now()),
    );
    if (entry == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await (widget.database ?? DatabaseService.instance)
          .addFoodLogEntries([entry]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(context.l10n.diarySaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_problem != null) {
      return _Fallback(
        problem: _problem!,
        busy: _busy,
        modelAvailable: widget.recognizer.isAvailable,
        onGallery: _gallery,
        onManual: _logManually,
        onRetry: _openCamera,
      );
    }
    final l10n = context.l10n;
    final style = CyberColors.style;
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && camera != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1000,
                  height: 1000 / camera.aspectRatio,
                  child: camera.buildPreview(),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // Dark edges keep the controls readable on bright food.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
                stops: [0, 0.22, 0.68, 1],
              ),
            ),
          ),
          // Centred like the preview: the photo's centre, and the centre
          // square the model reads, sit exactly behind the frame. Placed
          // higher, a plate framed here landed low in the photo.
          Align(
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: AspectRatio(
                aspectRatio: 1,
                child: ViewfinderFrame(style: style),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      _TopButton(
                        key: const ValueKey('scan-close'),
                        icon: Icons.close_rounded,
                        tooltip: l10n.scanClose,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (camera != null && camera.hasFlash)
                        _TopButton(
                          key: const ValueKey('scan-torch'),
                          icon: _torch
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          tooltip:
                              _torch ? l10n.scanTorchOff : l10n.scanTorchOn,
                          onPressed: _toggleTorch,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.scanFrameHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6)],
                  ),
                ),
                if (!widget.recognizer.isAvailable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
                    child: Text(
                      l10n.scanModelPending,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          shadows: [Shadow(blurRadius: 6)]),
                    ),
                  ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SideAction(
                        key: const ValueKey('scan-gallery'),
                        style: style,
                        icon: Icons.photo_library_rounded,
                        label: l10n.scanGalleryShort,
                        onTap: _busy ? null : _gallery,
                      ),
                      Semantics(
                        button: true,
                        label: l10n.scanTakePhoto,
                        excludeSemantics: true,
                        child: PressScale(
                          key: const ValueKey('scan-shutter'),
                          onTap: _capture,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 4)),
                            ),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 72,
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                          color: Colors.white),
                                    ),
                                  )
                                : ScanButtonFace(
                                    style: style,
                                    size: 72,
                                    ringColor: Colors.transparent,
                                  ),
                          ),
                        ),
                      ),
                      _SideAction(
                        key: const ValueKey('scan-manual'),
                        style: style,
                        icon: Icons.edit_note_rounded,
                        label: l10n.scanManualShort,
                        onTap: _busy ? null : _logManually,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      );
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppStyle style;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: PressScale(
            onTap: onTap ?? () {},
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StyledCameraButton(style: style, icon: icon),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Shown when the in-app camera cannot be used: gallery and manual logging
/// still work.
class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.problem,
    required this.busy,
    required this.modelAvailable,
    required this.onGallery,
    required this.onManual,
    required this.onRetry,
  });

  final ScanCameraProblem problem;
  final bool busy;
  final bool modelAvailable;
  final VoidCallback onGallery;
  final VoidCallback onManual;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ScanButtonFace(style: CyberColors.style, size: 104),
                ),
                const SizedBox(height: 20),
                Text(l10n.scanTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  problem == ScanCameraProblem.permissionDenied
                      ? l10n.scanCameraDenied
                      : l10n.scanNoCamera,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CyberColors.muted),
                ),
                if (!modelAvailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.scanModelPending,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CyberColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('scan-gallery'),
                  onPressed: busy ? null : onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.scanPickGallery),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('scan-manual'),
                  onPressed: busy ? null : onManual,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(l10n.scanManual),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  key: const ValueKey('scan-retry'),
                  onPressed: busy ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.scanRetryCamera),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
