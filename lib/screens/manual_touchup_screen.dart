import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../core/theme.dart';
import '../models/country_spec.dart';
import '../services/photo_composer_service.dart';

enum TouchupTool {
  erase,
  restore,
}

class ManualTouchupScreen extends StatefulWidget {
  final ProcessedPhotoPackage package;
  final CountrySpec spec;
  final Uint8List rawBytes;

  const ManualTouchupScreen({
    super.key,
    required this.package,
    required this.spec,
    required this.rawBytes,
  });

  @override
  State<ManualTouchupScreen> createState() => _ManualTouchupScreenState();
}

class _ManualTouchupScreenState extends State<ManualTouchupScreen> {
  TouchupTool _activeTool = TouchupTool.erase;
  double _brushSize = 25.0;
  String _activeBgHex = '#FFFFFF';
  
  img.Image? _workingImage;
  img.Image? _aiSegmentedImage;

  final List<Uint8List> _undoStack = [];
  final List<Uint8List> _redoStack = [];
  bool _isSaving = false;
  bool _isInitialized = false;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _activeBgHex = widget.package.activeBgHex;
    _initializeImages();
  }

  Future<void> _initializeImages() async {
    final aiDecoded = img.decodeImage(widget.package.singlePhotoBytes);
    if (aiDecoded != null) {
      _workingImage = img.Image.from(aiDecoded);
      _aiSegmentedImage = img.Image.from(aiDecoded);
      _pushUndo();
    }
    setState(() {
      _isInitialized = true;
    });
  }

  void _pushUndo() {
    if (_workingImage == null) return;
    final bytes = Uint8List.fromList(img.encodeJpg(_workingImage!, quality: 95));
    _undoStack.add(bytes);
    if (_undoStack.length > 20) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.length <= 1) return;
    HapticFeedback.selectionClick();
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    final decoded = img.decodeImage(prev);
    if (decoded != null) {
      setState(() {
        _workingImage = img.Image.from(decoded);
      });
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    final decoded = img.decodeImage(next);
    if (decoded != null) {
      setState(() {
        _workingImage = img.Image.from(decoded);
      });
    }
  }

  void _reset() {
    if (_aiSegmentedImage == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _workingImage = img.Image.from(_aiSegmentedImage!);
      _undoStack.clear();
      _pushUndo();
    });
  }

  void _applyBrushStroke(Offset localPosition, Size renderSize) {
    if (_workingImage == null) return;

    final imgW = _workingImage!.width;
    final imgH = _workingImage!.height;

    final double scaleX = imgW / renderSize.width;
    final double scaleY = imgH / renderSize.height;

    final int centerImgX = (localPosition.dx * scaleX).round();
    final int centerImgY = (localPosition.dy * scaleY).round();
    final int radiusImg = (_brushSize * scaleX * 0.5).round().clamp(2, 100);

    final bgCol = _parseHexColor(_activeBgHex);

    for (int dy = -radiusImg; dy <= radiusImg; dy++) {
      final py = centerImgY + dy;
      if (py < 0 || py >= imgH) continue;

      for (int dx = -radiusImg; dx <= radiusImg; dx++) {
        final px = centerImgX + dx;
        if (px < 0 || px >= imgW) continue;

        final distSq = dx * dx + dy * dy;
        if (distSq <= radiusImg * radiusImg) {
          if (_activeTool == TouchupTool.erase) {
            // Paint background color
            _workingImage!.setPixelRgb(px, py, bgCol.r, bgCol.g, bgCol.b);
          } else {
            // Restore from original baseline
            if (_aiSegmentedImage != null) {
              final origPixel = _aiSegmentedImage!.getPixel(px, py);
              _workingImage!.setPixel(px, py, origPixel);
            }
          }
        }
      }
    }
    setState(() {});
  }

  img.Color _parseHexColor(String hex) {
    if (hex.toLowerCase() == 'original') return img.ColorRgb8(255, 255, 255);
    final clean = hex.replaceAll('#', '');
    final val = int.tryParse(clean, radix: 16) ?? 0xFFFFFF;
    return img.ColorRgb8((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF);
  }

  Future<void> _handleSave() async {
    if (_workingImage == null) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final updatedSingleBytes = Uint8List.fromList(img.encodeJpg(_workingImage!, quality: 98));

      // Recompose the 4x6 print sheet and online digital portal image
      const int sheetW = 1200;
      const int sheetH = 1800;
      final printSheet = img.Image(width: sheetW, height: sheetH, numChannels: 3);
      img.fill(printSheet, color: img.ColorRgb8(255, 255, 255));

      final int targetWidth = _workingImage!.width;
      final int targetHeight = _workingImage!.height;
      final int cols = (widget.spec.widthMm > 45) ? 2 : 2;
      final int rows = (widget.spec.widthMm > 45) ? 2 : 3;
      final int totalPhotos = cols * rows;

      final int totalPhotoW = targetWidth * cols;
      final int totalPhotoH = targetHeight * rows;
      final int marginX = (sheetW - totalPhotoW) ~/ (cols + 1);
      final int marginY = (sheetH - 120 - totalPhotoH) ~/ (rows + 1) + 80;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final int x = marginX + c * (targetWidth + marginX);
          final int y = marginY + r * (targetHeight + marginY);
          img.compositeImage(printSheet, _workingImage!, dstX: x, dstY: y);
        }
      }

      final sheetBytes = Uint8List.fromList(img.encodeJpg(printSheet, quality: 98));
      final portalBytes = PhotoComposerService.optimizeForOnlinePortal(
        source: _workingImage!,
        targetWidth: 600,
        targetHeight: 600,
        maxKb: 240,
      );

      final updatedPackage = ProcessedPhotoPackage(
        singlePhotoBytes: updatedSingleBytes,
        printSheetBytes: sheetBytes,
        digitalPortalBytes: portalBytes,
        digitalPortalKb: (portalBytes.lengthInBytes / 1024).round(),
        singleWidth: targetWidth,
        singleHeight: targetHeight,
        printSheetWidth: sheetW,
        printSheetHeight: sheetH,
        photosOnSheet: totalPhotos,
        activeBgHex: _activeBgHex,
        sensitivity: widget.package.sensitivity,
        brightness: widget.package.brightness,
        contrast: widget.package.contrast,
        rotationDegrees: widget.package.rotationDegrees,
        isBabyMode: widget.package.isBabyMode,
      );

      if (mounted) {
        Navigator.pop(context, updatedPackage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving touch-up: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            Icon(Icons.auto_fix_high, color: AppTheme.secondary, size: 20),
            const SizedBox(width: 8),
            const Text('Magic Eraser & Touch-Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white70),
            tooltip: 'Undo',
            onPressed: _undoStack.length > 1 ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo, color: Colors.white70),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white70),
            tooltip: 'Reset to AI',
            onPressed: _reset,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Apply'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: !_isInitialized
          ? Center(child: CircularProgressIndicator(color: AppTheme.secondary))
          : Column(
              children: [
                // Interactive Canvas with Zoom & Touch Painting
                Expanded(
                  child: Container(
                    color: const Color(0xFF0A0D12),
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.8,
                        maxScale: 4.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double canvasW = (constraints.maxWidth * 0.85).clamp(240.0, 480.0);
                            final double canvasH = canvasW / widget.spec.aspectRatio;

                            return Container(
                              width: canvasW,
                              height: canvasH,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.5), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    _pushUndo();
                                    _applyBrushStroke(details.localPosition, Size(canvasW, canvasH));
                                  },
                                  onPanUpdate: (details) {
                                    _applyBrushStroke(details.localPosition, Size(canvasW, canvasH));
                                  },
                                  child: _workingImage != null
                                      ? Image.memory(
                                          Uint8List.fromList(img.encodeJpg(_workingImage!, quality: 90)),
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        )
                                      : const SizedBox(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Tool Palette & Brush Settings
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161B22),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -2)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mode Selector: Erase vs Restore
                      Row(
                        children: [
                          Expanded(
                            child: _buildToolButton(
                              tool: TouchupTool.erase,
                              icon: Icons.cleaning_services,
                              label: 'Erase Wall / Spots',
                              subtitle: 'Paints pure background',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildToolButton(
                              tool: TouchupTool.restore,
                              icon: Icons.brush,
                              label: 'Restore Hair / Edge',
                              subtitle: 'Paints back original details',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Brush Size Slider with indicator
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 12, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            'Brush: ${_brushSize.round()}px',
                            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: Colors.white70),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.secondary,
                                thumbColor: AppTheme.secondary,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: _brushSize,
                                min: 5,
                                max: 60,
                                onChanged: (val) {
                                  setState(() => _brushSize = val);
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.secondary, width: 1.5),
                              color: AppTheme.secondary.withValues(alpha: 0.2),
                            ),
                            child: Center(
                              child: Container(
                                width: (_brushSize * 0.4).clamp(3.0, 20.0),
                                height: (_brushSize * 0.4).clamp(3.0, 20.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolButton({
    required TouchupTool tool,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _activeTool == tool;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTool = tool);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.secondary.withValues(alpha: 0.15) : const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.secondary : const Color(0xFF30363D),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppTheme.secondary : Colors.white60, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? AppTheme.secondary : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
