import 'package:material_ui/material_ui.dart';

/// An indeterminate scan: never implies a fabricated completion percentage.
class ProcessingPhoto extends StatefulWidget {
  const ProcessingPhoto(
      {super.key,
      required this.active,
      required this.stage,
      required this.child});
  final bool active;
  final String stage;
  final Widget child;
  @override
  State<ProcessingPhoto> createState() => _ProcessingPhotoState();
}

class _ProcessingPhotoState extends State<ProcessingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController scan = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  @override
  void initState() {
    super.initState();
    if (widget.active) scan.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ProcessingPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) scan.repeat(reverse: true);
    if (!widget.active) scan.stop();
  }

  @override
  void dispose() {
    scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          widget.child,
          if (widget.active) ...[
            IgnorePointer(
                child: AnimatedBuilder(
                    animation: scan,
                    builder: (context, child) => Align(
                          alignment: Alignment(0, scan.value * 2 - 1),
                          child: Container(
                              key: const Key('processing-scanner'),
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      const Color(0x007B1FA2),
                                      const Color(0x99EE70B5),
                                      const Color(0x007B1FA2)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter),
                                border: const Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFC747D6), width: 3)),
                              )),
                        ))),
            if (widget.stage.isNotEmpty) Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xE654265F),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(widget.stage,
                                style: const TextStyle(color: Colors.white)))
                      ]),
                    ))),
          ],
        ]),
      );
}
