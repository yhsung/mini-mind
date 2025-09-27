/// Search Widget - Comprehensive search interface for mindmap navigation
///
/// This widget provides real-time search functionality with node navigation,
/// result highlighting, and advanced search options for the mindmap.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../models/document.dart';
import '../bridge/bridge_types.dart';
import '../state/providers.dart';

/// Search result item containing node and match information
class SearchResultItem {
  const SearchResultItem({
    required this.node,
    required this.score,
    required this.snippet,
    this.matchPositions = const [],
  });

  final Node node;
  final double score;
  final String snippet;
  final List<SearchMatch> matchPositions;

  /// Create from FFI search result
  factory SearchResultItem.fromFfi(FfiSearchResult ffiResult, Node node) {
    return SearchResultItem(
      node: node,
      score: ffiResult.score,
      snippet: ffiResult.snippet ?? ffiResult.text,
      matchPositions: [], // Would be populated from FFI match positions
    );
  }
}

/// Search match position within text
class SearchMatch {
  const SearchMatch({
    required this.start,
    required this.end,
    required this.matchType,
  });

  final int start;
  final int end;
  final SearchMatchType matchType;

  int get length => end - start;
}

/// Types of search matches
enum SearchMatchType {
  exact,
  partial,
  fuzzy,
  metadata,
}

/// Comprehensive search widget with real-time results
class MindmapSearchWidget extends ConsumerStatefulWidget {
  const MindmapSearchWidget({
    super.key,
    this.onSearchResult,
    this.onNodeSelected,
    this.onSearchClosed,
    this.placeholder = 'Search nodes...',
    this.maxResults = 10,
    this.enableFuzzySearch = true,
    this.enableMetadataSearch = true,
    this.searchDelay = const Duration(milliseconds: 300),
    this.autoFocus = false,
    this.showSearchStats = true,
  });

  final Function(List<SearchResultItem> results)? onSearchResult;
  final Function(Node node)? onNodeSelected;
  final VoidCallback? onSearchClosed;
  final String placeholder;
  final int maxResults;
  final bool enableFuzzySearch;
  final bool enableMetadataSearch;
  final Duration searchDelay;
  final bool autoFocus;
  final bool showSearchStats;

  @override
  ConsumerState<MindmapSearchWidget> createState() => _MindmapSearchWidgetState();
}

class _MindmapSearchWidgetState extends ConsumerState<MindmapSearchWidget>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late AnimationController _resultsAnimationController;
  late Animation<double> _resultsAnimation;

  final OverlayPortalController _overlayController = OverlayPortalController();

  List<SearchResultItem> _searchResults = [];
  int _selectedResultIndex = -1;
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _searchTimer;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
    _setupKeyboardListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _resultsAnimationController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _setupControllers() {
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onFocusChanged);

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _setupAnimations() {
    _resultsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _resultsAnimation = CurvedAnimation(
      parent: _resultsAnimationController,
      curve: Curves.easeOut,
    );
  }

  void _setupKeyboardListener() {
    // Handle keyboard shortcuts
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_searchFocusNode.hasFocus) return false;

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          _moveSelection(1);
          return true;
        case LogicalKeyboardKey.arrowUp:
          _moveSelection(-1);
          return true;
        case LogicalKeyboardKey.enter:
          _selectCurrentResult();
          return true;
        case LogicalKeyboardKey.escape:
          _closeSearch();
          return true;
      }
    }

    return false;
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;

    if (query.isEmpty) {
      _clearResults();
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    // Debounce search
    _searchTimer?.cancel();
    _searchTimer = Timer(widget.searchDelay, () {
      _performSearch(query);
    });
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchResults.isNotEmpty) {
      _showResults = true;
      _overlayController.show();
      _resultsAnimationController.forward();
    } else if (!_searchFocusNode.hasFocus) {
      // Delay hiding to allow result selection
      Timer(const Duration(milliseconds: 150), () {
        if (!_searchFocusNode.hasFocus) {
          _hideResults();
        }
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Get search results from bridge
      final searchResults = await ref.read(mindmapBridgeProvider).searchNodes(
        query: query,
        caseSensitive: false,
        wholeWords: false,
        regex: false,
      );

      // Convert to search result items
      final document = ref.read(mindmapDataProvider);
      final resultItems = <SearchResultItem>[];

      if (document != null) {
        for (final ffiResult in searchResults.take(widget.maxResults)) {
          final node = document.findNodeById(ffiResult.nodeId);
          if (node != null) {
            resultItems.add(SearchResultItem.fromFfi(ffiResult, node));
          }
        }
      }

      // Update UI state
      setState(() {
        _searchResults = resultItems;
        _selectedResultIndex = resultItems.isNotEmpty ? 0 : -1;
        _isSearching = false;
        _showResults = resultItems.isNotEmpty;
      });

      // Show results overlay
      if (_showResults && _searchFocusNode.hasFocus) {
        _overlayController.show();
        _resultsAnimationController.forward();
      }

      // Notify callback
      widget.onSearchResult?.call(_searchResults);

    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _showResults = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _searchResults = [];
      _selectedResultIndex = -1;
      _showResults = false;
      _isSearching = false;
    });
    _hideResults();
  }

  void _hideResults() {
    _resultsAnimationController.reverse().then((_) {
      _overlayController.hide();
    });
  }

  void _moveSelection(int direction) {
    if (_searchResults.isEmpty) return;

    setState(() {
      _selectedResultIndex = (_selectedResultIndex + direction)
          .clamp(0, _searchResults.length - 1);
    });
  }

  void _selectCurrentResult() {
    if (_selectedResultIndex >= 0 && _selectedResultIndex < _searchResults.length) {
      final result = _searchResults[_selectedResultIndex];
      _selectResult(result);
    }
  }

  void _selectResult(SearchResultItem result) {
    // Navigate to the node
    ref.read(mindmapStateProvider.notifier).selectNode(result.node.id);

    // Notify callback
    widget.onNodeSelected?.call(result.node);

    // Clear search and hide results
    _searchController.clear();
    _clearResults();
    _searchFocusNode.unfocus();
  }

  void _closeSearch() {
    _searchController.clear();
    _clearResults();
    _searchFocusNode.unfocus();
    widget.onSearchClosed?.call();
  }

  /// Build highlighted text with search matches
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int lastIndex = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Add text before match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: Theme.of(context).textTheme.bodyMedium,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = index + query.length;
      index = lowerText.indexOf(lowerQuery, lastIndex);
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: Theme.of(context).textTheme.bodyMedium,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build search result item
  Widget _buildResultItem(SearchResultItem result, int index) {
    final isSelected = index == _selectedResultIndex;
    final query = _searchController.text;

    return InkWell(
      onTap: () => _selectResult(result),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).highlightColor : null,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Node type icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: result.node.style.backgroundColor,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: result.node.style.borderColor,
                  width: 1.0,
                ),
              ),
              child: Icon(
                _getNodeTypeIcon(result.node.nodeType),
                size: 16,
                color: result.node.style.textColor,
              ),
            ),
            const SizedBox(width: 12.0),

            // Node content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Node title
                  _buildHighlightedText(result.node.text, query),

                  // Search snippet
                  if (result.snippet != result.node.text)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        result.snippet,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // Score indicator
            if (widget.showSearchStats)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    '${(result.score * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get icon for node type
  IconData _getNodeTypeIcon(NodeType nodeType) {
    switch (nodeType) {
      case NodeType.root:
        return Icons.home;
      case NodeType.branch:
        return Icons.account_tree;
      case NodeType.leaf:
        return Icons.circle;
      case NodeType.note:
        return Icons.note;
      default:
        return Icons.circle_outlined;
    }
  }

  /// Build search results overlay
  Widget _buildResultsOverlay() {
    if (_searchResults.isEmpty && !_isSearching) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300,
        minWidth: 300,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Searching...'),
                ],
              ),
            )
          : _searchResults.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No results found for "${_searchController.text}"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Results header
                    if (widget.showSearchStats)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8.0),
                            topRight: Radius.circular(8.0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Use ↑↓ to navigate, Enter to select',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Results list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) => _buildResultItem(_searchResults[index], index),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: AnimatedBuilder(
              animation: _resultsAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _resultsAnimation.value,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: _resultsAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: _buildResultsOverlay(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: _searchFocusNode.hasFocus
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _clearResults();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _selectCurrentResult(),
        ),
      ),
    );
  }
}

/// Compact search widget for toolbars
class CompactSearchWidget extends StatelessWidget {
  const CompactSearchWidget({
    super.key,
    this.onTap,
    this.onNodeSelected,
    this.width = 200.0,
  });

  final VoidCallback? onTap;
  final Function(Node node)? onNodeSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search nodes...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              Text(
                '⌘K',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search widget builder for different contexts
class SearchWidgetBuilder {
  /// Create a full-featured search widget
  static Widget buildFull({
    Function(List<SearchResultItem> results)? onSearchResult,
    Function(Node node)? onNodeSelected,
    VoidCallback? onSearchClosed,
    bool autoFocus = false,
  }) {
    return MindmapSearchWidget(
      onSearchResult: onSearchResult,
      onNodeSelected: onNodeSelected,
      onSearchClosed: onSearchClosed,
      autoFocus: autoFocus,
    );
  }

  /// Create a compact search widget for toolbars
  static Widget buildCompact({
    VoidCallback? onTap,
    Function(Node node)? onNodeSelected,
    double width = 200.0,
  }) {
    return CompactSearchWidget(
      onTap: onTap,
      onNodeSelected: onNodeSelected,
      width: width,
    );
  }

  /// Create a search dialog
  static Future<Node?> showSearchDialog(BuildContext context) {
    return showDialog<Node>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Search Nodes',
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
              MindmapSearchWidget(
                autoFocus: true,
                onNodeSelected: (node) {
                  Navigator.of(context).pop(node);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}