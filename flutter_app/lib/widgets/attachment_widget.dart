/// Attachment Widget - File and link attachment support for mindmap nodes
///
/// This widget provides comprehensive attachment functionality including
/// file attachments with thumbnail previews and link attachments with
/// URL validation and click handling.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../models/node.dart';
import '../state/providers.dart';

/// Attachment types supported by the mindmap
enum AttachmentType {
  file,
  link,
  image,
  document,
  video,
  audio,
  unknown,
}

/// Attachment data model
class Attachment {
  const Attachment({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    this.filePath,
    this.mimeType,
    this.size,
    this.thumbnail,
    this.description,
    this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final AttachmentType type;
  final String name;
  final String url;
  final String? filePath;
  final String? mimeType;
  final int? size;
  final Uint8List? thumbnail;
  final String? description;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  /// Get file extension
  String get extension {
    if (filePath != null) {
      return path.extension(filePath!).toLowerCase();
    } else if (url.contains('.')) {
      return path.extension(url).toLowerCase();
    }
    return '';
  }

  /// Get human-readable file size
  String get formattedSize {
    if (size == null) return '';

    final bytes = size!;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Check if attachment is an image
  bool get isImage {
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'};
    return type == AttachmentType.image || imageExtensions.contains(extension);
  }

  /// Check if attachment is a document
  bool get isDocument {
    final docExtensions = {'.pdf', '.doc', '.docx', '.txt', '.md', '.rtf'};
    return type == AttachmentType.document || docExtensions.contains(extension);
  }

  /// Check if attachment is a video
  bool get isVideo {
    final videoExtensions = {'.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'};
    return type == AttachmentType.video || videoExtensions.contains(extension);
  }

  /// Check if attachment is audio
  bool get isAudio {
    final audioExtensions = {'.mp3', '.wav', '.aac', '.ogg', '.flac'};
    return type == AttachmentType.audio || audioExtensions.contains(extension);
  }

  /// Check if attachment is a web link
  bool get isLink => type == AttachmentType.link;

  /// Check if attachment is local file
  bool get isLocalFile => filePath != null && File(filePath!).existsSync();

  /// Get appropriate icon for attachment type
  IconData get icon {
    if (isImage) return Icons.image;
    if (isDocument) return Icons.description;
    if (isVideo) return Icons.video_file;
    if (isAudio) return Icons.audio_file;
    if (isLink) return Icons.link;
    return Icons.attach_file;
  }

  /// Get color for attachment type
  Color get color {
    if (isImage) return Colors.green;
    if (isDocument) return Colors.blue;
    if (isVideo) return Colors.red;
    if (isAudio) return Colors.purple;
    if (isLink) return Colors.orange;
    return Colors.grey;
  }

  /// Create from file
  factory Attachment.fromFile({
    required String filePath,
    String? description,
    Uint8List? thumbnail,
  }) {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    AttachmentType type = AttachmentType.file;
    if ({'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}.contains(extension)) {
      type = AttachmentType.image;
    } else if ({'.pdf', '.doc', '.docx', '.txt', '.md'}.contains(extension)) {
      type = AttachmentType.document;
    } else if ({'.mp4', '.avi', '.mov', '.wmv'}.contains(extension)) {
      type = AttachmentType.video;
    } else if ({'.mp3', '.wav', '.aac', '.ogg'}.contains(extension)) {
      type = AttachmentType.audio;
    }

    return Attachment(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      name: fileName,
      url: file.uri.toString(),
      filePath: filePath,
      size: file.existsSync() ? file.lengthSync() : null,
      thumbnail: thumbnail,
      description: description,
      createdAt: DateTime.now(),
    );
  }

  /// Create from URL
  factory Attachment.fromUrl({
    required String url,
    required String name,
    String? description,
  }) {
    return Attachment(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      type: AttachmentType.link,
      name: name,
      url: url,
      description: description,
      createdAt: DateTime.now(),
    );
  }

  Attachment copyWith({
    String? name,
    String? description,
    Uint8List? thumbnail,
    Map<String, dynamic>? metadata,
  }) {
    return Attachment(
      id: id,
      type: type,
      name: name ?? this.name,
      url: url,
      filePath: filePath,
      mimeType: mimeType,
      size: size,
      thumbnail: thumbnail ?? this.thumbnail,
      description: description ?? this.description,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Comprehensive attachment widget
class AttachmentWidget extends ConsumerStatefulWidget {
  const AttachmentWidget({
    super.key,
    required this.attachment,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDownload,
    this.showActions = true,
    this.showMetadata = true,
    this.compact = false,
    this.maxWidth = 300.0,
  });

  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final bool showActions;
  final bool showMetadata;
  final bool compact;
  final double maxWidth;

  @override
  ConsumerState<AttachmentWidget> createState() => _AttachmentWidgetState();
}

class _AttachmentWidgetState extends ConsumerState<AttachmentWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverAnimationController;
  late Animation<double> _hoverAnimation;

  bool _isHovered = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _hoverAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _hoverAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _hoverAnimation = CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    // Default tap behavior
    if (widget.attachment.isLink) {
      await _openUrl(widget.attachment.url);
    } else if (widget.attachment.isLocalFile) {
      await _openFile(widget.attachment.filePath!);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      setState(() => _isLoading = true);

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Cannot open URL: $url');
      }
    } catch (e) {
      _showError('Failed to open URL: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      setState(() => _isLoading = true);

      final file = File(filePath);
      if (await file.exists()) {
        final uri = file.uri;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showError('Cannot open file: $filePath');
        }
      } else {
        _showError('File not found: $filePath');
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleHover(bool isHovered) {
    setState(() => _isHovered = isHovered);

    if (isHovered) {
      _hoverAnimationController.forward();
    } else {
      _hoverAnimationController.reverse();
    }
  }

  /// Build thumbnail widget
  Widget _buildThumbnail() {
    final size = widget.compact ? 32.0 : 48.0;

    if (widget.attachment.thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.memory(
          widget.attachment.thumbnail!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildIconThumbnail(size),
        ),
      );
    }

    return _buildIconThumbnail(size);
  }

  Widget _buildIconThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.attachment.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: widget.attachment.color.withOpacity(0.3),
        ),
      ),
      child: Icon(
        widget.attachment.icon,
        size: size * 0.6,
        color: widget.attachment.color,
      ),
    );
  }

  /// Build attachment actions
  Widget _buildActions() {
    if (!widget.showActions || widget.compact) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.attachment.isLocalFile && widget.onDownload != null)
          IconButton(
            icon: const Icon(Icons.download, size: 16),
            onPressed: widget.onDownload,
            tooltip: 'Download',
          ),
        if (widget.onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            onPressed: widget.onEdit,
            tooltip: 'Edit',
          ),
        if (widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            onPressed: widget.onDelete,
            tooltip: 'Delete',
          ),
      ],
    );
  }

  /// Build metadata display
  Widget _buildMetadata() {
    if (!widget.showMetadata || widget.compact) {
      return const SizedBox.shrink();
    }

    final metadata = <Widget>[];

    if (widget.attachment.size != null) {
      metadata.add(Text(
        widget.attachment.formattedSize,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ));
    }

    if (widget.attachment.createdAt != null) {
      final date = widget.attachment.createdAt!;
      metadata.add(Text(
        '${date.day}/${date.month}/${date.year}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ));
    }

    if (metadata.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8.0,
      children: metadata,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hoverAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => _handleHover(true),
          onExit: (_) => _handleHover(false),
          child: GestureDetector(
            onTap: _isLoading ? null : _handleTap,
            child: Container(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              padding: EdgeInsets.all(widget.compact ? 8.0 : 12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: _isHovered
                      ? widget.attachment.color.withOpacity(0.5)
                      : Theme.of(context).dividerColor,
                  width: _isHovered ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05 + 0.05 * _hoverAnimation.value),
                    blurRadius: 4.0 + 4.0 * _hoverAnimation.value,
                    offset: Offset(0, 2.0 + 2.0 * _hoverAnimation.value),
                  ),
                ],
              ),
              child: widget.compact ? _buildCompactContent() : _buildFullContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          _buildThumbnail(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.attachment.name,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFullContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_isLoading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _buildThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.attachment.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.attachment.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.attachment.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _buildActions(),
          ],
        ),
        const SizedBox(height: 8),
        _buildMetadata(),
      ],
    );
  }
}

/// Attachment list widget for managing multiple attachments
class AttachmentListWidget extends ConsumerWidget {
  const AttachmentListWidget({
    super.key,
    required this.attachments,
    this.onAttachmentTap,
    this.onAttachmentEdit,
    this.onAttachmentDelete,
    this.onAddAttachment,
    this.maxItems = 5,
    this.compact = false,
  });

  final List<Attachment> attachments;
  final Function(Attachment)? onAttachmentTap;
  final Function(Attachment)? onAttachmentEdit;
  final Function(Attachment)? onAttachmentDelete;
  final VoidCallback? onAddAttachment;
  final int maxItems;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachments.isEmpty && onAddAttachment == null) {
      return const SizedBox.shrink();
    }

    final displayedAttachments = attachments.take(maxItems).toList();
    final hasMore = attachments.length > maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachments.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Attachments (${attachments.length})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        ...displayedAttachments.map((attachment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AttachmentWidget(
              attachment: attachment,
              onTap: () => onAttachmentTap?.call(attachment),
              onEdit: () => onAttachmentEdit?.call(attachment),
              onDelete: () => onAttachmentDelete?.call(attachment),
              compact: compact,
            ),
          );
        }),

        if (hasMore)
          TextButton(
            onPressed: () {
              // Show all attachments dialog
              _showAllAttachmentsDialog(context, attachments);
            },
            child: Text('Show ${attachments.length - maxItems} more...'),
          ),

        if (onAddAttachment != null)
          TextButton.icon(
            onPressed: onAddAttachment,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Attachment'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
      ],
    );
  }

  void _showAllAttachmentsDialog(BuildContext context, List<Attachment> attachments) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 8),
                  Text(
                    'All Attachments (${attachments.length})',
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
              Expanded(
                child: ListView.builder(
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AttachmentWidget(
                        attachment: attachment,
                        onTap: () => onAttachmentTap?.call(attachment),
                        onEdit: () => onAttachmentEdit?.call(attachment),
                        onDelete: () => onAttachmentDelete?.call(attachment),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// URL validator utility
class UrlValidator {
  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    return _urlRegex.hasMatch(url);
  }

  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'URL cannot be empty';
    }

    if (!isValidUrl(url)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  static String normalizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }
}

/// Attachment dialog for adding/editing attachments
class AttachmentDialog extends StatefulWidget {
  const AttachmentDialog({
    super.key,
    this.attachment,
    this.onSave,
  });

  final Attachment? attachment;
  final Function(Attachment)? onSave;

  @override
  State<AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<AttachmentDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _descriptionController;

  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.attachment != null;

    _nameController = TextEditingController(
      text: widget.attachment?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.attachment?.url ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.attachment?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final url = UrlValidator.normalizeUrl(_urlController.text.trim());
    final name = _nameController.text.trim().ifEmpty ?? Uri.parse(url).host;

    final attachment = _isEditing
        ? widget.attachment!.copyWith(
            name: name,
            description: _descriptionController.text.trim().ifEmpty,
          )
        : Attachment.fromUrl(
            url: url,
            name: name,
            description: _descriptionController.text.trim().ifEmpty,
          );

    widget.onSave?.call(attachment);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_isEditing ? Icons.edit : Icons.add_link),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Edit Attachment' : 'Add Link Attachment',
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

              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
                validator: UrlValidator.validateUrl,
                enabled: !_isEditing,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Link name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(_isEditing ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}