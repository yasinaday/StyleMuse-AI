import 'dart:math' as math;
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;

/// Matches the square cover preview and its InteractiveViewer transform.
Uint8List cropPhoto(Uint8List bytes,
    {double zoom = 1, double panX = 0, double panY = 0}) {
  final source = img.decodeImage(bytes);
  if (source == null) throw const FormatException('Fotoğraf açılamadı.');
  final oriented = img.bakeOrientation(source);
  final side = math.min(oriented.width, oriented.height) / zoom.clamp(1, 5);
  final x = ((oriented.width - side) / 2 -
          panX * math.min(oriented.width, oriented.height) / zoom)
      .clamp(0, oriented.width - side)
      .round();
  final y = ((oriented.height - side) / 2 -
          panY * math.min(oriented.width, oriented.height) / zoom)
      .clamp(0, oriented.height - side)
      .round();
  var result = img.copyCrop(oriented,
      x: x, y: y, width: side.round(), height: side.round());
  if (result.width > 1600) result = img.copyResize(result, width: 1600);
  return Uint8List.fromList(img.encodeJpg(result, quality: 90));
}

class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.bytes, required this.tr});
  final Uint8List bytes;
  final String Function(String) tr;
  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  final controller = TransformationController();
  double size = 1;
  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    setState(() => saving = true);
    try {
      final matrix = controller.value;
      final zoom = matrix.getMaxScaleOnAxis();
      // InteractiveViewer scales from the upper-left; compensate its center.
      final result = cropPhoto(widget.bytes,
          zoom: zoom,
          panX: matrix.storage[12] / size + (zoom - 1) / 2,
          panY: matrix.storage[13] / size + (zoom - 1) / 2);
      Navigator.pop(context, result);
    } catch (_) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.tr('Fotoğraf açılamadı.'))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.tr('Kırp ve devam et'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.tr(
              'Fotoğrafı kaydırıp yakınlaştırarak analiz edilecek kıyafetleri çerçeveye al.')),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (_, constraints) {
            size = constraints.maxWidth;
            return AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      InteractiveViewer(
                          transformationController: controller,
                          minScale: 1,
                          maxScale: 5,
                          child: Image.memory(widget.bytes,
                              width: size, height: size, fit: BoxFit.cover)),
                      const IgnorePointer(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  border: Border.fromBorderSide(BorderSide(
                                      color: Color(0xFFD6B7F6), width: 2))))),
                    ])));
          }),
          const SizedBox(height: 16),
          Text(widget.tr('Analizde yalnızca seçtiğin alan kullanılır.')),
          const SizedBox(height: 16),
          FilledButton.icon(
              key: const Key('crop-confirm'),
              onPressed: saving ? null : save,
              icon: const Icon(Icons.crop),
              label: Text(widget.tr('Kırp ve devam et'))),
          TextButton(
              onPressed: () =>
                  setState(() => controller.value = Matrix4.identity()),
              child: const Text('↺')),
        ])),
      );
}
