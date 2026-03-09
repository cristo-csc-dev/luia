import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

enum _ResizeHandle { topLeft, topRight, bottomLeft, bottomRight, center, none }

// Widget principal de ejemplo
class WebViewCapture extends StatefulWidget {
  final String initialUrl;

  const WebViewCapture({super.key, required this.initialUrl});

  @override
  State<WebViewCapture> createState() => _WebViewCaptureState();
}

class _WebViewCaptureState extends State<WebViewCapture> {
  // Controlador para manejar el WebView
  InAppWebViewController? webViewController;

  // Variable para mostrar una barra de carga
  double progress = 0;

  // Key para medir el tamaño y posición del WebView
  final GlobalKey _webViewKey = GlobalKey();

  // Selección de región
  bool _selectionMode = false;
  Offset? _dragStartLogical;
  Rect? _selectionRectLogical;

  _ResizeHandle _activeHandle = _ResizeHandle.none;
  final double _handleHitTestSize = 30.0;

  // Variables para manipulación de la selección (mover/escalar)
  Rect? _baseRectForResize;
  Offset? _baseFocalPoint;

  _ResizeHandle _getHandleAt(Offset local, Rect rect) {
    if ((local - rect.topLeft).distance <= _handleHitTestSize) return _ResizeHandle.topLeft;
    if ((local - rect.topRight).distance <= _handleHitTestSize) return _ResizeHandle.topRight;
    if ((local - rect.bottomLeft).distance <= _handleHitTestSize) return _ResizeHandle.bottomLeft;
    if ((local - rect.bottomRight).distance <= _handleHitTestSize) return _ResizeHandle.bottomRight;
    if (rect.contains(local)) return _ResizeHandle.center;
    return _ResizeHandle.none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navega y Captura"),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Capturar selección',
              onPressed: _selectionRectLogical == null
                  ? null
                  : () async {
                      final bytes = await _captureRegion(
                        _selectionRectLogical!,
                      );
                      if (bytes != null) _showPreviewDialog(bytes);
                      setState(() {
                        _selectionMode = false;
                        _selectionRectLogical = null;
                        _dragStartLogical = null;
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar selección',
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectionRectLogical = null;
                  _dragStartLogical = null;
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.crop_free),
              tooltip: 'Seleccionar región',
              onPressed: () {
                final renderBox = _webViewKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                  final size = renderBox.size;
                  final width = size.width * 0.5;
                  final height = size.height * 0.2;
                  final rect = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: width,
                    height: height,
                  );
                  setState(() {
                    _selectionMode = true;
                    _selectionRectLogical = rect;
                  });
                } else {
                  setState(() {
                    _selectionMode = true;
                  });
                }
              },
            ),
            // Botón extra para recargar si es necesario
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                webViewController?.reload();
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // 1. El WebView ocupa todo el fondo (envuelto para medir su tamaño)
          Container(
            key: _webViewKey,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(
                  widget.initialUrl,
                ),
              ),
              // Configuración inicial para permitir zoom y scroll fluido
              initialSettings: InAppWebViewSettings(
                isInspectable: kDebugMode,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone",
                iframeAllowFullscreen: true,
                // Habilitar soporte de zoom nativo
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls:
                    false, // Ocultar los botones feos de zoom +/-
              ),
              onWebViewCreated: (controller) {
                // Guardamos el controlador cuando se crea la vista
                webViewController = controller;
              },
              onProgressChanged: (controller, count) {
                setState(() {
                  progress = count / 100;
                });
              },
            ),
          ),

          // 2. Barra de progreso simple mientras carga
          progress < 1.0
              ? LinearProgressIndicator(value: progress)
              : Container(),

          // Overlay para seleccionar región (captura de área)
          if (_selectionMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  final box =
                      _webViewKey.currentContext?.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(details.focalPoint);

                  if (_selectionRectLogical != null) {
                    _activeHandle = _getHandleAt(local, _selectionRectLogical!);
                  } else {
                    _activeHandle = _ResizeHandle.none;
                  }

                  if (_activeHandle == _ResizeHandle.none) {
                    // Crear nueva selección
                    _dragStartLogical = local;
                    _selectionRectLogical = Rect.fromPoints(local, local);
                  } else if (_activeHandle == _ResizeHandle.center) {
                    // Mover
                    _baseFocalPoint = local;
                    _baseRectForResize = _selectionRectLogical;
                  } else {
                    // Redimensionar una esquina
                    // Definimos el punto de ancla (la esquina opuesta)
                    switch (_activeHandle) {
                      case _ResizeHandle.topLeft:
                        _dragStartLogical = _selectionRectLogical!.bottomRight;
                        break;
                      case _ResizeHandle.topRight:
                        _dragStartLogical = _selectionRectLogical!.bottomLeft;
                        break;
                      case _ResizeHandle.bottomLeft:
                        _dragStartLogical = _selectionRectLogical!.topRight;
                        break;
                      case _ResizeHandle.bottomRight:
                        _dragStartLogical = _selectionRectLogical!.topLeft;
                        break;
                      default:
                        break;
                    }
                  }
                },
                onScaleUpdate: (details) {
                  final box =
                      _webViewKey.currentContext?.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(details.focalPoint);

                  if (_activeHandle == _ResizeHandle.center) {
                    // Mover
                    if (_baseRectForResize != null && _baseFocalPoint != null) {
                      final delta = local - _baseFocalPoint!;
                      setState(() {
                        _selectionRectLogical = _baseRectForResize!.shift(delta);
                      });
                    }
                  } else {
                    // Redimensionar o Crear (ambos usan _dragStartLogical como ancla)
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
                          borderColor: Theme.of(context).colorScheme.primary,
                        ),
                        size: Size.infinite,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
      // 3. El botón "Obturador"
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _takeScreenshotOfVisibleArea,
      //   label: const Text("Capturar Vista Actual"),
      //   icon: const Icon(Icons.camera_alt),
      // ),
    );
  }

  // Captura una región lógica (coordenadas dentro del WebView) y devuelve PNG recortado
  Future<Uint8List?> _captureRegion(Rect logicalRect) async {
    if (webViewController == null) return null;

    // 1) Tomamos captura completa
    final Uint8List? bytes = await webViewController!.takeScreenshot(
      screenshotConfiguration: ScreenshotConfiguration(
        compressFormat: CompressFormat.PNG,
        quality: 90,
      ),
    );
    if (bytes == null) return null;

    // 2) Decodificamos la imagen y obtenemos dimensiones
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 3) Medimos el WebView en pantalla para mapear coordenadas lógicas a píxeles
    final box = _webViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final widgetSize = box.size;

    final scaleX = image.width / widgetSize.width;
    final scaleY = image.height / widgetSize.height;

    final double px = (logicalRect.left * scaleX)
        .clamp(0, image.width.toDouble())
        .toDouble();
    final double py = (logicalRect.top * scaleY)
        .clamp(0, image.height.toDouble())
        .toDouble();
    final double pwidth = (logicalRect.width * scaleX)
        .clamp(0, image.width - px)
        .toDouble();
    final double pheight = (logicalRect.height * scaleY)
        .clamp(0, image.height - py)
        .toDouble();

    final pixelRect = Rect.fromLTWH(px, py, pwidth, pheight);

    // 4) Recortamos usando un PictureRecorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final dst = Rect.fromLTWH(0, 0, pixelRect.width, pixelRect.height);
    canvas.drawImageRect(image, pixelRect, dst, paint);

    final croppedImage = await recorder.endRecording().toImage(
      pixelRect.width.toInt(),
      pixelRect.height.toInt(),
    );

    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // Liberar recursos nativos manualmente para evitar presión en el GC
    image.dispose();
    croppedImage.dispose();

    return byteData?.buffer.asUint8List();
  }

  // La función mágica
  Future<void> _takeScreenshotOfVisibleArea() async {
    if (webViewController == null) return;

    // Muestra un indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // TOMA LA FOTO: Esto captura el viewport visible actual
      final Uint8List? screenshotBytes = await webViewController!
          .takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.PNG,
              quality: 90,
            ),
          );

      // Cerrar el indicador de carga
      Navigator.of(context).pop();

      if (screenshotBytes != null) {
        // Mostramos el resultado
        _showPreviewDialog(screenshotBytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al tomar la captura')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadAndReturn(Uint8List imageBytes) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final String fileName = '${const Uuid().v4()}.png';
      final imageRef = storageRef.child('wish_images/$fileName');

      // Subir imagen
      await imageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      // Obtener URL
      final downloadUrl = await imageRef.getDownloadURL();

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar carga
        Navigator.of(context).pop(); // Cerrar diálogo preview
        Navigator.of(context).pop(downloadUrl); // Volver con resultado
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la imagen: $e')),
        );
      }
    }
  }

  // Diálogo simple para mostrar la imagen capturada
  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Captura realizada"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                const SizedBox(height: 10),
                // Mostrar la imagen desde la memoria
                Image.memory(imageBytes),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Guardar"),
              onPressed: () => _uploadAndReturn(imageBytes),
            ),
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Aquí podrías añadir otro botón para "Guardar" o "Compartir" la imagen
          ],
        );
      },
    );
  }
}

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

    // Dibujar manejadores en las esquinas
    final paintHandle = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    final paintBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double radius = 6.0;
    for (final offset in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
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
