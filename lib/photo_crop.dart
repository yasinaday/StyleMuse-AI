import 'package:flutter/foundation.dart' show compute;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;

/// Matches the square cover preview and its InteractiveViewer transform.
Uint8List cropPhoto(Uint8List bytes,
    {double zoom = 1, double panX = 0, double panY = 0, bool wholeFrame = false}) {
  final source = img.decodeImage(bytes);
  if (source == null) throw const FormatException('Fotoğraf açılamadı.');
  final oriented = img.bakeOrientation(source);
  final scale = zoom.clamp(1, 5);
  final side = math.min(oriented.width, oriented.height);
  final w = (wholeFrame ? oriented.width : side) / scale;
  final h = (wholeFrame ? oriented.height : side) / scale;
  final x = ((oriented.width - w) / 2 - panX * w).clamp(0, oriented.width - w).round();
  final y = ((oriented.height - h) / 2 - panY * h).clamp(0, oriented.height - h).round();
  var result = img.copyCrop(oriented, x: x, y: y,
      width: math.max(1, w.round()), height: math.max(1, h.round()));
  if (math.max(result.width, result.height) > 1600) {
    result = result.width >= result.height ? img.copyResize(result, width: 1600)
        : img.copyResize(result, height: 1600);
  }
  return Uint8List.fromList(img.encodeJpg(result, quality: 90));
}

Uint8List _cropInBackground((Uint8List, double, double, double) request) =>
    cropPhoto(request.$1, zoom: request.$2, panX: request.$3, panY: request.$4, wholeFrame: true);

class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.bytes, required this.tr});
  final Uint8List bytes;
  final String Function(String) tr;
  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  final controller = TransformationController();
  late final Future<double> aspect = readAspect();
  Size frame = const Size(1, 1);

  Future<double> readAspect() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    try {
      final decoded = (await codec.getNextFrame()).image;
      try {
        return decoded.width / decoded.height;
      } finally {
        decoded.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final matrix = controller.value;
      final zoom = matrix.getMaxScaleOnAxis();
      // InteractiveViewer scales from the upper-left; compensate its center.
      final result = await compute(_cropInBackground, (
        widget.bytes, zoom,
        matrix.storage[12] / frame.width + (zoom - 1) / 2,
        matrix.storage[13] / frame.height + (zoom - 1) / 2,
      ));
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.tr('Fotoğraf açılamadı.'))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.tr('Fotoğrafı düzenle'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.tr(
              'Fotoğrafı kaydırıp yakınlaştırarak analiz edilecek kıyafetleri çerçeveye al.')),
          const SizedBox(height: 20),
          FutureBuilder<double>(future: aspect, builder: (context, snapshot) {
            if (snapshot.hasError) return Text(widget.tr('Fotoğraf açılamadı.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return LayoutBuilder(builder: (context, constraints) {
              final ratio = snapshot.data!;
              final width = math.min(constraints.maxWidth, MediaQuery.sizeOf(context).height * .50 * ratio);
              frame = Size(width, width / ratio);
              return Center(child: SizedBox(width: frame.width, height: frame.height,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      InteractiveViewer(
                          transformationController: controller,
                          minScale: 1,
                          maxScale: 5,
                          child: Image.memory(widget.bytes,
                              fit: BoxFit.contain)),
                      const IgnorePointer(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  border: Border.fromBorderSide(BorderSide(
                                      color: Color(0xFFD6B7F6), width: 2))))),
                    ]))));
            });
          }),
          const SizedBox(height: 10),
          Text(widget.tr('Yakınlaştır')),
          ValueListenableBuilder<Matrix4>(
            valueListenable: controller,
            builder: (context, matrix, child) => Slider(
              min: 1,
              max: 5,
              value: matrix.getMaxScaleOnAxis().clamp(1.0, 5.0).toDouble(),
              onChanged: saving ? null : (zoom) {
                final ratio = zoom / matrix.getMaxScaleOnAxis();
                double offset(double length, double old) =>
                    (length / 2 + (old - length / 2) * ratio)
                        .clamp(length * (1 - zoom), 0.0).toDouble();
                controller.value = Matrix4.diagonal3Values(zoom, zoom, zoom)
                  ..setTranslationRaw(offset(frame.width, matrix.storage[12]),
                      offset(frame.height, matrix.storage[13]), 0);
              },
            ),
          ),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: Text(widget.tr('Vazgeç')),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(
              key: const Key('crop-confirm'),
              onPressed: saving ? null : save,
              child: Text(widget.tr('Kırp ve devam et'), textAlign: TextAlign.center),
            )),
          ]),
          const SizedBox(height: 8),
          Text(widget.tr('Analizde yalnızca seçtiğin alan kullanılır.'),
            textAlign: TextAlign.center),
        ])),
      );
}
