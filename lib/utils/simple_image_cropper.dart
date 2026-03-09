import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Re-using the handle enum and painter from webview_capture.dart for consistency.
enum _ResizeHandle { topLeft, topRight, bottomLeft, bottomRight, center, none }

/// A simple widget to crop an image using a draggable and resizable rectangle.
class SimpleImageCropper extends StatefulWidget {
  final Uint8List imageBytes;

  const SimpleImageCropper({super.key, required this.imageBytes});

  @override
  State<SimpleImageCropper> createState() => _SimpleImageCropperState();
}

class _SimpleImageCropperState extends State<SimpleImageCropper> {
  final GlobalKey _imageContainerKey = GlobalKey();
  ui.Image? _decodedImage;

  // State for selection rectangle
  Rect? _selectionRectLogical;
  _ResizeHandle _activeHandle = _ResizeHandle.none;
  final double _handleHitTestSize = 30.0;

  // State for drag/resize gesture
  Rect? _baseRectForResize;
  Offset? _baseFocalPoint;
  Offset? _dragStartLogical;

  @override
  void initState() {
    super.initState();
    // Decode the image to get its dimensions for layout calculations.
    ui.instantiateImageCodec(widget.imageBytes).then((codec) {
      codec.getNextFrame().then((frame) {
        if (mounted) {
          setState(() {
            _decodedImage = frame.image;
          });
          // Once the image is decoded, we can initialize the selection rectangle
          // after the first frame is built.
          WidgetsBinding.instance.addPostFrameCallback(_initSelectionRect);
        }
      });
    });
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  /// Initializes the selection rectangle in the center of the displayed image.
  void _initSelectionRect(_) {
    if (_decodedImage == null) return;
    final containerBox =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null || !containerBox.hasSize) return;

    final containerSize = containerBox.size;
    final imageSize = Size(
        _decodedImage!.width.toDouble(), _decodedImage!.height.toDouble());

    // Calculate the rect of the image as displayed on screen with BoxFit.contain
    final fittedSizes = applyBoxFit(BoxFit.contain, imageSize, containerSize);
    final destinationRect = Alignment.center.inscribe(
        fittedSizes.destination, Rect.fromLTWH(0, 0, containerSize.width, containerSize.height));

    // Set initial selection to be a centered rectangle.
    final initialSelection = Rect.fromCenter(
      center: destinationRect.center,
      width: destinationRect.width * 0.8,
      height: destinationRect.height * 0.8,
    );

    setState(() {
      _selectionRectLogical = initialSelection;
    });
  }

  /// Determines which resize handle, if any, is at a given local position.
  _ResizeHandle _getHandleAt(Offset local, Rect rect) {
    if ((local - rect.topLeft).distance <= _handleHitTestSize) return _ResizeHandle.topLeft;
    if ((local - rect.topRight).distance <= _handleHitTestSize) return _ResizeHandle.topRight;
    if ((local - rect.bottomLeft).distance <= _handleHitTestSize) return _ResizeHandle.bottomLeft;
    if ((local - rect.bottomRight).distance <= _handleHitTestSize) return _ResizeHandle.bottomRight;
    if (rect.contains(local)) return _ResizeHandle.center;
    return _ResizeHandle.none;
  }

  /// Crops the image based on the logical selection rectangle and returns the bytes.
  Future<Uint8List?> _cropImage(Rect logicalSelectionRect) async {
    if (_decodedImage == null) return null;
    final image = _decodedImage!;

    final containerBox =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return null;

    final containerSize = containerBox.size;
    final imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final fittedSizes = applyBoxFit(BoxFit.contain, imageSize, containerSize);
    final destinationRect = Alignment.center.inscribe(
        fittedSizes.destination, Rect.fromLTWH(0, 0, containerSize.width, containerSize.height));

    // Clip the selection rect to the bounds of the displayed image.
    final clippedSelectionRect = logicalSelectionRect.intersect(destinationRect);
    if (clippedSelectionRect.width <= 0 || clippedSelectionRect.height <= 0) {
      return null;
    }

    // Transform coordinates from container-space to image-pixel-space.
    // 1. Translate to be relative to the image's top-left corner on screen.
    final relativeSelectionRect =
        clippedSelectionRect.translate(-destinationRect.left, -destinationRect.top);

    // 2. Scale to pixel dimensions.
    final scaleX = image.width / destinationRect.width;
    final scaleY = image.height / destinationRect.height;

    final pixelRect = Rect.fromLTWH(
      relativeSelectionRect.left * scaleX,
      relativeSelectionRect.top * scaleY,
      relativeSelectionRect.width * scaleX,
      relativeSelectionRect.height * scaleY,
    );

    // Use PictureRecorder to perform the crop.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      image,
      pixelRect,
      Rect.fromLTWH(0, 0, pixelRect.width, pixelRect.height),
      Paint(),
    );

    final croppedUiImage = await recorder.endRecording().toImage(
          pixelRect.width.toInt(),
          pixelRect.height.toInt(),
        );

    final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
    croppedUiImage.dispose();

    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recortar Imagen"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirmar recorte',
            onPressed: _selectionRectLogical == null
                ? null
                : () async {
                    final bytes = await _cropImage(_selectionRectLogical!);
                    if (bytes != null && mounted) {
                      Navigator.of(context).pop(bytes);
                    }
                  },
          ),
        ],
      ),
      body: Container(
        key: _imageContainerKey,
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _decodedImage == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        final box = _imageContainerKey.currentContext
                            ?.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.focalPoint);

                        if (_selectionRectLogical != null) {
                          _activeHandle =
                              _getHandleAt(local, _selectionRectLogical!);
                        } else {
                          _activeHandle = _ResizeHandle.none;
                        }

                        if (_activeHandle == _ResizeHandle.none) {
                          _dragStartLogical = local;
                          _selectionRectLogical = Rect.fromPoints(local, local);
                        } else if (_activeHandle == _ResizeHandle.center) {
                          _baseFocalPoint = local;
                          _baseRectForResize = _selectionRectLogical;
                        } else {
                          // Start resizing from a corner.
                          switch (_activeHandle) {
                            case _ResizeHandle.topLeft:
                              _dragStartLogical =
                                  _selectionRectLogical!.bottomRight;
                              break;
                            case _ResizeHandle.topRight:
                              _dragStartLogical =
                                  _selectionRectLogical!.bottomLeft;
                              break;
                            case _ResizeHandle.bottomLeft:
                              _dragStartLogical =
                                  _selectionRectLogical!.topRight;
                              break;
                            case _ResizeHandle.bottomRight:
                              _dragStartLogical =
                                  _selectionRectLogical!.topLeft;
                              break;
                            default:
                              break;
                          }
                        }
                      },
                      onScaleUpdate: (details) {
                        final box = _imageContainerKey.currentContext
                            ?.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.focalPoint);

                        if (_activeHandle == _ResizeHandle.center) {
                          if (_baseRectForResize != null &&
                              _baseFocalPoint != null) {
                            final delta = local - _baseFocalPoint!;
                            setState(() {
                              _selectionRectLogical =
                                  _baseRectForResize!.shift(delta);
                            });
                          }
                        } else {
                          if (_dragStartLogical != null) {
                            setState(() {
                              _selectionRectLogical =
                                  Rect.fromPoints(_dragStartLogical!, local);
                            });
                          }
                        }
                      },
                      onScaleEnd: (details) {
                        _activeHandle = _ResizeHandle.none;
                        _baseRectForResize = null;
                        _baseFocalPoint = null;
                        _dragStartLogical = null;
                      },
                      child: _selectionRectLogical != null
                          ? CustomPaint(
                              painter: _SelectionOverlayPainter(
                                rect: _selectionRectLogical!,
                                overlayColor: Colors.black.withOpacity(0.5),
                                borderColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              size: Size.infinite,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A custom painter to draw the cropping overlay.
class _SelectionOverlayPainter extends CustomPainter {
  final Rect rect;
  final Color overlayColor;
  final Color borderColor;

  _SelectionOverlayPainter({
    required this.rect,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = overlayColor);

    canvas.drawRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Draw resize handles at the corners.
    final paintHandle = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    final paintBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double radius = 6.0;
    for (final offset
        in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      canvas.drawCircle(offset, radius, paintHandle);
      canvas.drawCircle(offset, radius, paintBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor;
  }
}

