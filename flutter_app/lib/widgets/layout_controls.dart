/// Layout Controls - Comprehensive layout management interface
///
/// This widget provides layout selection, parameter controls, and animation
/// management for different mindmap layout algorithms.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/bridge_types.dart';
import '../state/providers.dart';

/// Layout configuration for different algorithms
class LayoutConfiguration {
  const LayoutConfiguration({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.parameters = const {},
    this.animationDuration = const Duration(milliseconds: 1000),
    this.previewColor = Colors.blue,
  });

  final FfiLayoutType type;
  final String name;
  final String description;
  final IconData icon;
  final Map<String, LayoutParameter> parameters;
  final Duration animationDuration;
  final Color previewColor;

  /// Create radial layout configuration
  factory LayoutConfiguration.radial() {
    return LayoutConfiguration(
      type: FfiLayoutType.radial,
      name: 'Radial',
      description: 'Nodes arranged in concentric circles around the root',
      icon: Icons.radio_button_unchecked,
      previewColor: Colors.blue,
      parameters: {
        'radius': LayoutParameter.range(
          name: 'Radius',
          value: 150.0,
          min: 50.0,
          max: 500.0,
          step: 10.0,
          unit: 'px',
        ),
        'angleSpread': LayoutParameter.range(
          name: 'Angle Spread',
          value: 360.0,
          min: 90.0,
          max: 360.0,
          step: 15.0,
          unit: '°',
        ),
        'levelSpacing': LayoutParameter.range(
          name: 'Level Spacing',
          value: 100.0,
          min: 50.0,
          max: 200.0,
          step: 5.0,
          unit: 'px',
        ),
      },
    );
  }

  /// Create tree layout configuration
  factory LayoutConfiguration.tree() {
    return LayoutConfiguration(
      type: FfiLayoutType.tree,
      name: 'Tree',
      description: 'Hierarchical tree structure with clear parent-child relationships',
      icon: Icons.account_tree,
      previewColor: Colors.green,
      parameters: {
        'nodeSpacing': LayoutParameter.range(
          name: 'Node Spacing',
          value: 80.0,
          min: 40.0,
          max: 200.0,
          step: 5.0,
          unit: 'px',
        ),
        'levelSpacing': LayoutParameter.range(
          name: 'Level Spacing',
          value: 120.0,
          min: 60.0,
          max: 300.0,
          step: 10.0,
          unit: 'px',
        ),
        'orientation': LayoutParameter.choice(
          name: 'Orientation',
          value: 'vertical',
          choices: ['vertical', 'horizontal'],
        ),
        'alignment': LayoutParameter.choice(
          name: 'Alignment',
          value: 'center',
          choices: ['left', 'center', 'right'],
        ),
      },
    );
  }

  /// Create force-directed layout configuration
  factory LayoutConfiguration.forceDirected() {
    return LayoutConfiguration(
      type: FfiLayoutType.forceDirected,
      name: 'Force Directed',
      description: 'Physics-based layout with natural node positioning',
      icon: Icons.scatter_plot,
      previewColor: Colors.orange,
      animationDuration: const Duration(milliseconds: 2000),
      parameters: {
        'springStrength': LayoutParameter.range(
          name: 'Spring Strength',
          value: 0.1,
          min: 0.01,
          max: 1.0,
          step: 0.01,
        ),
        'repulsionStrength': LayoutParameter.range(
          name: 'Repulsion Strength',
          value: 30.0,
          min: 10.0,
          max: 100.0,
          step: 5.0,
        ),
        'damping': LayoutParameter.range(
          name: 'Damping',
          value: 0.9,
          min: 0.1,
          max: 1.0,
          step: 0.05,
        ),
        'iterations': LayoutParameter.range(
          name: 'Iterations',
          value: 100.0,
          min: 50.0,
          max: 500.0,
          step: 10.0,
        ),
      },
    );
  }

  LayoutConfiguration copyWith({
    Map<String, LayoutParameter>? parameters,
    Duration? animationDuration,
  }) {
    return LayoutConfiguration(
      type: type,
      name: name,
      description: description,
      icon: icon,
      parameters: parameters ?? this.parameters,
      animationDuration: animationDuration ?? this.animationDuration,
      previewColor: previewColor,
    );
  }
}

/// Layout parameter definition
class LayoutParameter {
  const LayoutParameter({
    required this.name,
    required this.type,
    required this.value,
    this.min,
    this.max,
    this.step,
    this.choices,
    this.unit,
    this.description,
  });

  final String name;
  final LayoutParameterType type;
  final dynamic value;
  final double? min;
  final double? max;
  final double? step;
  final List<String>? choices;
  final String? unit;
  final String? description;

  /// Create range parameter
  factory LayoutParameter.range({
    required String name,
    required double value,
    required double min,
    required double max,
    double? step,
    String? unit,
    String? description,
  }) {
    return LayoutParameter(
      name: name,
      type: LayoutParameterType.range,
      value: value,
      min: min,
      max: max,
      step: step,
      unit: unit,
      description: description,
    );
  }

  /// Create choice parameter
  factory LayoutParameter.choice({
    required String name,
    required String value,
    required List<String> choices,
    String? description,
  }) {
    return LayoutParameter(
      name: name,
      type: LayoutParameterType.choice,
      value: value,
      choices: choices,
      description: description,
    );
  }

  /// Create boolean parameter
  factory LayoutParameter.boolean({
    required String name,
    required bool value,
    String? description,
  }) {
    return LayoutParameter(
      name: name,
      type: LayoutParameterType.boolean,
      value: value,
      description: description,
    );
  }

  LayoutParameter copyWith({dynamic value}) {
    return LayoutParameter(
      name: name,
      type: type,
      value: value ?? this.value,
      min: min,
      max: max,
      step: step,
      choices: choices,
      unit: unit,
      description: description,
    );
  }

  String get displayValue {
    switch (type) {
      case LayoutParameterType.range:
        final val = value as double;
        return unit != null ? '${val.toStringAsFixed(1)}$unit' : val.toStringAsFixed(1);
      case LayoutParameterType.choice:
        return value as String;
      case LayoutParameterType.boolean:
        return (value as bool) ? 'On' : 'Off';
    }
  }
}

/// Layout parameter types
enum LayoutParameterType {
  range,
  choice,
  boolean,
}

/// Comprehensive layout controls widget
class MindmapLayoutControls extends ConsumerStatefulWidget {
  const MindmapLayoutControls({
    super.key,
    this.onLayoutChanged,
    this.onParameterChanged,
    this.onAnimationStarted,
    this.onAnimationCompleted,
    this.showPreview = true,
    this.showParameters = true,
    this.enableAnimation = true,
    this.compact = false,
  });

  final Function(FfiLayoutType layoutType)? onLayoutChanged;
  final Function(String parameter, dynamic value)? onParameterChanged;
  final VoidCallback? onAnimationStarted;
  final VoidCallback? onAnimationCompleted;
  final bool showPreview;
  final bool showParameters;
  final bool enableAnimation;
  final bool compact;

  @override
  ConsumerState<MindmapLayoutControls> createState() => _MindmapLayoutControlsState();
}

class _MindmapLayoutControlsState extends ConsumerState<MindmapLayoutControls>
    with TickerProviderStateMixin {
  late AnimationController _layoutAnimationController;
  late AnimationController _previewAnimationController;
  late Animation<double> _layoutAnimation;
  late Animation<double> _previewAnimation;

  final Map<FfiLayoutType, LayoutConfiguration> _configurations = {
    FfiLayoutType.radial: LayoutConfiguration.radial(),
    FfiLayoutType.tree: LayoutConfiguration.tree(),
    FfiLayoutType.forceDirected: LayoutConfiguration.forceDirected(),
  };

  FfiLayoutType _selectedLayout = FfiLayoutType.radial;
  bool _isAnimating = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _layoutAnimationController.dispose();
    _previewAnimationController.dispose();
    _animationTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _layoutAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _previewAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _layoutAnimation = CurvedAnimation(
      parent: _layoutAnimationController,
      curve: Curves.easeInOut,
    );

    _previewAnimation = CurvedAnimation(
      parent: _previewAnimationController,
      curve: Curves.easeInOut,
    );

    // Start preview animation loop
    if (widget.showPreview) {
      _startPreviewAnimation();
    }
  }

  void _startPreviewAnimation() {
    _previewAnimationController.repeat(reverse: true);
  }

  void _stopPreviewAnimation() {
    _previewAnimationController.stop();
  }

  Future<void> _applyLayout(FfiLayoutType layoutType) async {
    if (_isAnimating || layoutType == _selectedLayout) return;

    setState(() {
      _selectedLayout = layoutType;
      _isAnimating = true;
    });

    widget.onAnimationStarted?.call();

    try {
      // Apply layout through bridge
      await ref.read(mindmapBridgeProvider).applyLayout(layoutType);

      // Start animation
      if (widget.enableAnimation) {
        _layoutAnimationController.forward(from: 0.0);

        // Set timer for animation completion
        final config = _configurations[layoutType]!;
        _animationTimer = Timer(config.animationDuration, () {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
            widget.onAnimationCompleted?.call();
          }
        });
      } else {
        setState(() {
          _isAnimating = false;
        });
        widget.onAnimationCompleted?.call();
      }

      widget.onLayoutChanged?.call(layoutType);

    } catch (e) {
      setState(() {
        _isAnimating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply layout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateParameter(String parameterKey, dynamic value) {
    final config = _configurations[_selectedLayout]!;
    final updatedParameters = Map<String, LayoutParameter>.from(config.parameters);

    if (updatedParameters.containsKey(parameterKey)) {
      updatedParameters[parameterKey] = updatedParameters[parameterKey]!.copyWith(value: value);

      setState(() {
        _configurations[_selectedLayout] = config.copyWith(parameters: updatedParameters);
      });

      widget.onParameterChanged?.call(parameterKey, value);
    }
  }

  /// Build layout selection buttons
  Widget _buildLayoutSelectors() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _configurations.entries.map((entry) {
        final layoutType = entry.key;
        final config = entry.value;
        final isSelected = layoutType == _selectedLayout;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: LayoutSelectorButton(
            configuration: config,
            isSelected: isSelected,
            isAnimating: _isAnimating && isSelected,
            onTap: () => _applyLayout(layoutType),
            compact: widget.compact,
          ),
        );
      }).toList(),
    );
  }

  /// Build parameter controls
  Widget _buildParameterControls() {
    if (!widget.showParameters) return const SizedBox.shrink();

    final config = _configurations[_selectedLayout]!;
    if (config.parameters.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(config.icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${config.name} Parameters',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...config.parameters.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ParameterControl(
                  parameter: entry.value,
                  onChanged: (value) => _updateParameter(entry.key, value),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build layout preview
  Widget _buildLayoutPreview() {
    if (!widget.showPreview) return const SizedBox.shrink();

    final config = _configurations[_selectedLayout]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Layout Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 150,
              child: AnimatedBuilder(
                animation: _previewAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: LayoutPreviewPainter(
                      layoutType: _selectedLayout,
                      animationValue: _previewAnimation.value,
                      color: config.previewColor,
                    ),
                    size: const Size(200, 150),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.description,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildLayoutSelectors();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLayoutSelectors(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildParameterControls()),
            const SizedBox(width: 16),
            if (widget.showPreview) _buildLayoutPreview(),
          ],
        ),
      ],
    );
  }
}

/// Layout selector button widget
class LayoutSelectorButton extends StatelessWidget {
  const LayoutSelectorButton({
    super.key,
    required this.configuration,
    required this.isSelected,
    required this.onTap,
    this.isAnimating = false,
    this.compact = false,
  });

  final LayoutConfiguration configuration;
  final bool isSelected;
  final bool isAnimating;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: configuration.description,
      child: InkWell(
        onTap: isAnimating ? null : onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: EdgeInsets.all(compact ? 8.0 : 12.0),
          decoration: BoxDecoration(
            color: isSelected
                ? configuration.previewColor.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? configuration.previewColor
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    configuration.icon,
                    size: compact ? 24 : 32,
                    color: isSelected
                        ? configuration.previewColor
                        : Theme.of(context).iconTheme.color,
                  ),
                  if (isAnimating)
                    SizedBox(
                      width: compact ? 32 : 40,
                      height: compact ? 32 : 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(configuration.previewColor),
                      ),
                    ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  configuration.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? configuration.previewColor
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Parameter control widget
class ParameterControl extends StatelessWidget {
  const ParameterControl({
    super.key,
    required this.parameter,
    required this.onChanged,
  });

  final LayoutParameter parameter;
  final Function(dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    switch (parameter.type) {
      case LayoutParameterType.range:
        return _buildRangeControl(context);
      case LayoutParameterType.choice:
        return _buildChoiceControl(context);
      case LayoutParameterType.boolean:
        return _buildBooleanControl(context);
    }
  }

  Widget _buildRangeControl(BuildContext context) {
    final value = parameter.value as double;
    final min = parameter.min!;
    final max = parameter.max!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              parameter.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              parameter.displayValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: parameter.step != null
              ? ((max - min) / parameter.step!).round()
              : null,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChoiceControl(BuildContext context) {
    final value = parameter.value as String;
    final choices = parameter.choices!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parameter.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: choices.map((choice) {
            return DropdownMenuItem(
              value: choice,
              child: Text(choice),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBooleanControl(BuildContext context) {
    final value = parameter.value as bool;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          parameter.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Layout preview painter
class LayoutPreviewPainter extends CustomPainter {
  const LayoutPreviewPainter({
    required this.layoutType,
    required this.animationValue,
    required this.color,
  });

  final FfiLayoutType layoutType;
  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    switch (layoutType) {
      case FfiLayoutType.radial:
        _drawRadialPreview(canvas, size, center, paint);
        break;
      case FfiLayoutType.tree:
        _drawTreePreview(canvas, size, center, paint);
        break;
      case FfiLayoutType.forceDirected:
        _drawForceDirectedPreview(canvas, size, center, paint);
        break;
    }
  }

  void _drawRadialPreview(Canvas canvas, Size size, Offset center, Paint paint) {
    final baseRadius = size.width * 0.15;
    final maxRadius = size.width * 0.4;

    // Central node
    canvas.drawCircle(center, 6, paint);

    // Animated circles
    for (int level = 1; level <= 3; level++) {
      final radius = baseRadius + (level * (maxRadius - baseRadius) / 3);
      final animatedRadius = radius * (0.8 + 0.2 * animationValue);

      final nodeCount = level * 4;
      for (int i = 0; i < nodeCount; i++) {
        final angle = (i * 2 * math.pi / nodeCount) + (animationValue * math.pi / 4);
        final x = center.dx + animatedRadius * math.cos(angle);
        final y = center.dy + animatedRadius * math.sin(angle);

        canvas.drawCircle(Offset(x, y), 4, paint);
      }
    }
  }

  void _drawTreePreview(Canvas canvas, Size size, Offset center, Paint paint) {
    final levelHeight = size.height * 0.25;

    // Root
    final rootY = center.dy - levelHeight;
    canvas.drawCircle(Offset(center.dx, rootY), 6, paint);

    // Level 1
    final level1Y = center.dy;
    final level1Spacing = size.width * 0.2;
    for (int i = -1; i <= 1; i++) {
      final x = center.dx + i * level1Spacing * (0.8 + 0.2 * animationValue);
      canvas.drawCircle(Offset(x, level1Y), 5, paint);

      // Connection lines
      canvas.drawLine(
        Offset(center.dx, rootY + 6),
        Offset(x, level1Y - 5),
        Paint()..color = color..strokeWidth = 2,
      );
    }

    // Level 2
    final level2Y = center.dy + levelHeight;
    final level2Spacing = size.width * 0.1;
    for (int i = -2; i <= 2; i++) {
      final x = center.dx + i * level2Spacing * (0.8 + 0.2 * animationValue);
      canvas.drawCircle(Offset(x, level2Y), 4, paint);

      // Connection to parent
      final parentX = center.dx + (i / 2).clamp(-1.0, 1.0) * level1Spacing * (0.8 + 0.2 * animationValue);
      canvas.drawLine(
        Offset(parentX, level1Y + 5),
        Offset(x, level2Y - 4),
        Paint()..color = color..strokeWidth = 1.5,
      );
    }
  }

  void _drawForceDirectedPreview(Canvas canvas, Size size, Offset center, Paint paint) {
    final nodes = [
      Offset(center.dx, center.dy - 30),
      Offset(center.dx - 40, center.dy + 10),
      Offset(center.dx + 40, center.dy + 10),
      Offset(center.dx - 20, center.dy + 40),
      Offset(center.dx + 20, center.dy + 40),
      Offset(center.dx, center.dy + 60),
    ];

    // Animate node positions
    final animatedNodes = nodes.map((node) {
      final offset = math.sin(animationValue * 2 * math.pi) * 5;
      return Offset(
        node.dx + offset * math.cos(nodes.indexOf(node) * 0.5),
        node.dy + offset * math.sin(nodes.indexOf(node) * 0.5),
      );
    }).toList();

    // Draw connections
    final linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.5;

    for (int i = 0; i < animatedNodes.length; i++) {
      for (int j = i + 1; j < animatedNodes.length; j++) {
        if ((animatedNodes[i] - animatedNodes[j]).distance < 60) {
          canvas.drawLine(animatedNodes[i], animatedNodes[j], linePaint);
        }
      }
    }

    // Draw nodes
    for (final node in animatedNodes) {
      canvas.drawCircle(node, 5, paint);
    }
  }

  @override
  bool shouldRepaint(LayoutPreviewPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.layoutType != layoutType ||
           oldDelegate.color != color;
  }
}

/// Layout controls builder for different contexts
class LayoutControlsBuilder {
  /// Create full layout controls
  static Widget buildFull({
    Function(FfiLayoutType)? onLayoutChanged,
    Function(String, dynamic)? onParameterChanged,
    bool showPreview = true,
    bool showParameters = true,
  }) {
    return MindmapLayoutControls(
      onLayoutChanged: onLayoutChanged,
      onParameterChanged: onParameterChanged,
      showPreview: showPreview,
      showParameters: showParameters,
    );
  }

  /// Create compact layout selector
  static Widget buildCompact({
    Function(FfiLayoutType)? onLayoutChanged,
  }) {
    return MindmapLayoutControls(
      onLayoutChanged: onLayoutChanged,
      compact: true,
      showPreview: false,
      showParameters: false,
    );
  }

  /// Create layout dialog
  static Future<FfiLayoutType?> showLayoutDialog(BuildContext context) {
    return showDialog<FfiLayoutType>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree),
                  const SizedBox(width: 8),
                  Text(
                    'Layout Selection',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MindmapLayoutControls(
                onLayoutChanged: (layoutType) {
                  Navigator.of(context).pop(layoutType);
                },
                showParameters: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}