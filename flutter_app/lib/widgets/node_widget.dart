/// Node Widget - Interactive mindmap node with editing capabilities
///
/// This widget represents a single node in the mindmap with full interaction
/// support including text editing, selection, focus states, and styling.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../state/providers.dart';

/// Interactive mindmap node widget with text editing and visual states
class NodeWidget extends ConsumerStatefulWidget {
  const NodeWidget({
    super.key,
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
    this.onFocusChanged,
    this.onHoverChanged,
    this.minWidth = 80.0,
    this.minHeight = 40.0,
    this.maxWidth = 300.0,
    this.enableTextEditing = true,
    this.enableSelection = true,
    this.enableHover = true,
    this.autoFocus = false,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;
  final Function(bool hasFocus)? onFocusChanged;
  final Function(bool isHovered)? onHoverChanged;
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final bool enableTextEditing;
  final bool enableSelection;
  final bool enableHover;
  final bool autoFocus;

  @override
  ConsumerState<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends ConsumerState<NodeWidget>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late AnimationController _scaleAnimationController;
  late AnimationController _glowAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool _isHovered = false;
  bool _isPressed = false;
  bool _isEditing = false;
  Timer? _editingTimer;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
    _setupFocusListener();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scaleAnimationController.dispose();
    _glowAnimationController.dispose();
    _editingTimer?.cancel();
    super.dispose();
  }

  void _setupControllers() {
    _textController = TextEditingController(text: widget.node.text);
    _focusNode = FocusNode();

    if (widget.autoFocus && widget.node.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _setupAnimations() {
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _glowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupFocusListener() {
    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      widget.onFocusChanged?.call(hasFocus);

      if (hasFocus && !_isEditing) {
        _startEditing();
      } else if (!hasFocus && _isEditing) {
        _stopEditing();
      }
    });
  }

  @override
  void didUpdateWidget(NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update text if node text changed externally
    if (oldWidget.node.text != widget.node.text && !_isEditing) {
      _textController.text = widget.node.text;
    }

    // Handle editing state changes
    if (oldWidget.node.isEditing != widget.node.isEditing) {
      if (widget.node.isEditing && !_isEditing) {
        _startEditing();
      } else if (!widget.node.isEditing && _isEditing) {
        _stopEditing();
      }
    }

    // Handle focus state changes
    if (oldWidget.node.isFocused != widget.node.isFocused) {
      if (widget.node.isFocused && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      } else if (!widget.node.isFocused && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  void _startEditing() {
    if (!widget.enableTextEditing || _isEditing) return;

    setState(() {
      _isEditing = true;
    });

    _focusNode.requestFocus();
    _glowAnimationController.forward();

    // Auto-select all text when starting to edit
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );

    // Update node state
    ref.read(mindmapStateProvider.notifier).updateNode(
      widget.node.copyWith(isEditing: true, isFocused: true),
    );
  }

  void _stopEditing() {
    if (!_isEditing) return;

    setState(() {
      _isEditing = false;
    });

    _glowAnimationController.reverse();

    // Save text changes
    final newText = _textController.text.trim();
    if (newText != widget.node.text) {
      widget.onTextChanged?.call(newText);

      ref.read(mindmapStateProvider.notifier).updateNode(
        widget.node.copyWith(
          text: newText,
          isEditing: false,
          isFocused: false,
        ),
      );
    } else {
      ref.read(mindmapStateProvider.notifier).updateNode(
        widget.node.copyWith(isEditing: false, isFocused: false),
      );
    }

    widget.onEditingComplete?.call();
  }

  void _handleTap() {
    widget.onTap?.call();

    if (widget.enableSelection) {
      ref.read(mindmapStateProvider.notifier).selectNode(widget.node.id);
    }
  }

  void _handleDoubleTap() {
    widget.onDoubleTap?.call();

    if (widget.enableTextEditing && !_isEditing) {
      _startEditing();
    }
  }

  void _handleLongPress() {
    widget.onLongPress?.call();
    HapticFeedback.mediumImpact();
  }

  void _handleHoverChange(bool isHovered) {
    if (!widget.enableHover) return;

    setState(() {
      _isHovered = isHovered;
    });

    widget.onHoverChanged?.call(isHovered);

    if (isHovered) {
      _scaleAnimationController.forward();
    } else {
      _scaleAnimationController.reverse();
    }

    // Update node hover state
    ref.read(mindmapStateProvider.notifier).updateNode(
      widget.node.copyWith(isHovered: isHovered),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  /// Calculate effective node style based on current state
  NodeStyle get _effectiveStyle {
    var style = widget.node.style;

    if (widget.node.isSelected) {
      style = style.asSelected();
    }

    if (_isHovered) {
      style = style.asHovered();
    }

    if (_isPressed) {
      style = style.copyWith(
        backgroundColor: style.backgroundColor.withOpacity(0.8),
        borderColor: style.borderColor.withBlue(255),
      );
    }

    if (_isEditing) {
      style = style.copyWith(
        borderColor: Colors.blue,
        borderWidth: 2.0,
        backgroundColor: style.backgroundColor.withOpacity(0.95),
      );
    }

    return style;
  }

  /// Build text widget based on editing state
  Widget _buildTextWidget() {
    final style = _effectiveStyle;

    if (_isEditing) {
      return TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: TextStyle(
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          color: style.textColor,
        ),
        textAlign: style.textAlign,
        maxLines: null,
        minLines: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onSubmitted: (_) => _stopEditing(),
        onEditingComplete: _stopEditing,
        textInputAction: TextInputAction.done,
      );
    }

    return Text(
      widget.node.displayText,
      style: TextStyle(
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        color: style.textColor,
      ),
      textAlign: style.textAlign,
      maxLines: style.maxLines,
      overflow: style.textOverflow,
    );
  }

  /// Build glow effect for editing state
  Widget _buildGlowEffect(Widget child) {
    if (!_isEditing) return child;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_effectiveStyle.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 8.0 * _glowAnimation.value,
                spreadRadius: 2.0 * _glowAnimation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _effectiveStyle;
    final renderState = ref.watch(renderStateProvider);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: renderState.animationsEnabled ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: _buildGlowEffect(
        MouseRegion(
          onEnter: (_) => _handleHoverChange(true),
          onExit: (_) => _handleHoverChange(false),
          child: GestureDetector(
            onTap: _handleTap,
            onDoubleTap: _handleDoubleTap,
            onLongPress: _handleLongPress,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              constraints: BoxConstraints(
                minWidth: widget.minWidth,
                minHeight: widget.minHeight,
                maxWidth: widget.maxWidth,
              ),
              padding: style.padding,
              decoration: BoxDecoration(
                color: style.backgroundColor.withOpacity(style.opacity),
                borderRadius: BorderRadius.circular(style.borderRadius),
                border: style.borderWidth > 0
                    ? Border.all(
                        color: style.borderColor,
                        width: style.borderWidth,
                      )
                    : null,
                boxShadow: widget.node.isSelected || _isEditing
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 4.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : style.elevation > 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: style.elevation,
                              offset: Offset(0, style.elevation / 2),
                            ),
                          ]
                        : null,
              ),
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: Center(
                    child: _buildTextWidget(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Specialized node widget for different node types
class TypedNodeWidget extends ConsumerWidget {
  const TypedNodeWidget({
    super.key,
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (node.nodeType) {
      case NodeType.root:
        return _RootNodeWidget(
          node: node,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onTextChanged: onTextChanged,
          onEditingComplete: onEditingComplete,
        );

      case NodeType.branch:
        return _BranchNodeWidget(
          node: node,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onTextChanged: onTextChanged,
          onEditingComplete: onEditingComplete,
        );

      case NodeType.leaf:
        return _LeafNodeWidget(
          node: node,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onTextChanged: onTextChanged,
          onEditingComplete: onEditingComplete,
        );

      case NodeType.note:
        return _NoteNodeWidget(
          node: node,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onTextChanged: onTextChanged,
          onEditingComplete: onEditingComplete,
        );

      default:
        return NodeWidget(
          node: node,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onTextChanged: onTextChanged,
          onEditingComplete: onEditingComplete,
        );
    }
  }
}

/// Root node widget with special styling
class _RootNodeWidget extends StatelessWidget {
  const _RootNodeWidget({
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(
      node: node,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTextChanged: onTextChanged,
      onEditingComplete: onEditingComplete,
      minWidth: 120.0,
      minHeight: 60.0,
      maxWidth: 400.0,
    );
  }
}

/// Branch node widget
class _BranchNodeWidget extends StatelessWidget {
  const _BranchNodeWidget({
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(
      node: node,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTextChanged: onTextChanged,
      onEditingComplete: onEditingComplete,
      minWidth: 100.0,
      minHeight: 50.0,
      maxWidth: 300.0,
    );
  }
}

/// Leaf node widget
class _LeafNodeWidget extends StatelessWidget {
  const _LeafNodeWidget({
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(
      node: node,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTextChanged: onTextChanged,
      onEditingComplete: onEditingComplete,
      minWidth: 80.0,
      minHeight: 40.0,
      maxWidth: 250.0,
    );
  }
}

/// Note node widget with expanded text area
class _NoteNodeWidget extends StatelessWidget {
  const _NoteNodeWidget({
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTextChanged,
    this.onEditingComplete,
  });

  final Node node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String text)? onTextChanged;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(
      node: node,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTextChanged: onTextChanged,
      onEditingComplete: onEditingComplete,
      minWidth: 150.0,
      minHeight: 80.0,
      maxWidth: 400.0,
    );
  }
}

/// Node widget builder for different contexts
class NodeWidgetBuilder {
  /// Create a node widget with default configuration
  static Widget build(
    Node node, {
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
    Function(String)? onTextChanged,
    VoidCallback? onEditingComplete,
    bool enableEditing = true,
    bool enableSelection = true,
  }) {
    return TypedNodeWidget(
      node: node,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTextChanged: onTextChanged,
      onEditingComplete: onEditingComplete,
    );
  }

  /// Create a read-only node widget
  static Widget buildReadOnly(Node node) {
    return NodeWidget(
      node: node,
      enableTextEditing: false,
      enableSelection: false,
      enableHover: false,
    );
  }

  /// Create a minimal node widget for overview/minimap
  static Widget buildMinimal(Node node) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 20.0,
        minHeight: 10.0,
        maxWidth: 100.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: node.style.backgroundColor,
        borderRadius: BorderRadius.circular(node.style.borderRadius / 2),
        border: node.isSelected
            ? Border.all(color: Colors.blue, width: 1.0)
            : null,
      ),
      child: Text(
        node.displayText,
        style: TextStyle(
          fontSize: 8.0,
          color: node.style.textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}