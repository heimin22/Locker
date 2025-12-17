import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:locker/models/album.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vaulted_file.dart';
import '../providers/vault_providers.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';
import 'media_viewer_screen.dart';
import 'document_viewer_screen.dart';

/// Predefined tag colors
final List<Color> tagColors = [
  const Color(0xFF1976D2), // Blue
  const Color(0xFF388E3C), // Green
  const Color(0xFFD32F2F), // Red
  const Color(0xFF7B1FA2), // Purple
  const Color(0xFFF57C00), // Orange
  const Color(0xFF00796B), // Teal
  const Color(0xFFC2185B), // Pink
  const Color(0xFF5D4037), // Brown
  const Color(0xFF455A64), // Blue Grey
  const Color(0xFF616161), // Grey
  const Color(0xFF303F9F), // Indigo
  const Color(0xFF689F38), // Light Green
];

/// Screen for managing and browsing tags
class TagsScreen extends ConsumerStatefulWidget {
  final String? initialTag; // If set, show files with this tag directly

  const TagsScreen({super.key, this.initialTag});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  String? _selectedTag;
  bool _isSelectionMode = false;
  final Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialTag;
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(),
      body: _selectedTag != null
          ? _buildTagFilesView()
          : _buildTagsListView(tagsAsync),
      floatingActionButton: _selectedTag == null
          ? FloatingActionButton.extended(
              onPressed: _showCreateTagDialog,
              backgroundColor: AppColors.accent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'New Tag',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppColors.accent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${_selectedFiles.length} selected',
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_off_outlined, color: Colors.white),
            onPressed: _removeTagFromSelected,
            tooltip: 'Remove tag',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteSelectedFiles,
            tooltip: 'Delete files',
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_selectedTag != null) {
            setState(() => _selectedTag = null);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        _selectedTag ?? 'Tags',
        style: const TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_selectedTag != null)
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
      ],
    );
  }

  Widget _buildTagsListView(AsyncValue<List<TagInfo>> tagsAsync) {
    return tagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: AppColors.lightTextTertiary),
            const SizedBox(height: 16),
            Text(
              'Failed to load tags',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
      data: (tags) {
        if (tags.isEmpty) {
          return _buildEmptyTagsState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tagsProvider);
          },
          color: AppColors.accent,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            itemBuilder: (context, index) => _buildTagItem(tags[index]),
          ),
        );
      },
    );
  }

  Widget _buildTagItem(TagInfo tag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.lightBackgroundSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _selectedTag = tag.name),
        onLongPress: () => _showTagOptions(tag),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(tag.colorValue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.label,
                  color: Color(tag.colorValue),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.name,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tag.usageCount} ${tag.usageCount == 1 ? 'file' : 'files'}',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 13,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTagsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.label_outline,
              size: 64,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tags yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create tags to organize your files by category',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.lightTextSecondary,
                fontFamily: 'ProductSans',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateTagDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Tag'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilesView() {
    final filesAsync = ref.watch(filesByTagProvider(_selectedTag!));

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load files',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextSecondary,
          ),
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return _buildEmptyTagFilesState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(filesByTagProvider(_selectedTag!));
          },
          color: AppColors.accent,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) => _buildFileItem(files[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTagFilesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No files with this tag',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add this tag to files from the gallery',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              fontFamily: 'ProductSans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(VaultedFile file) {
    final isSelected = _selectedFiles.contains(file.id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(file.id);
        } else {
          _openFile(file);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(file.id);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightBackgroundSecondary,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 5 : 8),
              child: _buildFileThumbnail(file),
            ),
          ),
          // Selection indicator
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accent : Colors.white,
                  border: Border.all(
                    color:
                        isSelected ? AppColors.accent : AppColors.lightBorder,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          // Favorite indicator
          if (file.isFavorite && !_isSelectionMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 14,
                  color: Colors.red,
                ),
              ),
            ),
          // Video indicator
          if (file.isVideo)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child:
                    const Icon(Icons.play_arrow, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(VaultedFile file) {
    if (file.isImage) {
      final imageFile = File(file.vaultPath);
      return FutureBuilder<bool>(
        future: imageFile.exists(),
        builder: (context, snapshot) {
          if (snapshot.data != true) {
            return _buildPlaceholder(file);
          }
          return Image.file(
            imageFile,
            fit: BoxFit.cover,
            cacheWidth: 300,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => _buildPlaceholder(file),
          );
        },
      );
    }

    if (file.isVideo) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 48,
            color: Colors.white70,
          ),
        ),
      );
    }

    return _buildPlaceholder(file);
  }

  Widget _buildPlaceholder(VaultedFile file) {
    IconData icon;
    Color color;

    switch (file.type) {
      case VaultedFileType.image:
        icon = Icons.image;
        color = Colors.blue;
        break;
      case VaultedFileType.video:
        icon = Icons.videocam;
        color = Colors.red;
        break;
      case VaultedFileType.document:
        icon = Icons.description;
        color = Colors.orange;
        break;
      case VaultedFileType.other:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
        break;
    }

    return Container(
      color: color.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 4),
          Text(
            file.extension.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'ProductSans',
            ),
          ),
        ],
      ),
    );
  }

  void _enterSelectionMode(String fileId) {
    setState(() {
      _isSelectionMode = true;
      _selectedFiles.add(fileId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFiles.contains(fileId)) {
        _selectedFiles.remove(fileId);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(fileId);
      }
    });
  }

  void _openFile(VaultedFile file) {
    final filesAsync = ref.read(filesByTagProvider(_selectedTag!));
    final files = filesAsync.value ?? [];

    if (file.isImage || file.isVideo) {
      final viewerFiles = files.where((f) => f.isImage || f.isVideo).toList();
      final initialIndex = viewerFiles.indexWhere((f) => f.id == file.id);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerScreen(
            initialFile: file,
            files: viewerFiles,
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ),
        ),
      );
    } else if (file.isDocument) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(file: file),
        ),
      );
    } else {
      _showFileOptionsSheet(file);
    }
  }

  void _showFileOptionsSheet(VaultedFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.insert_drive_file,
                            size: 32, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.originalName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightTextPrimary,
                                  fontFamily: 'ProductSans'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${file.extension.toUpperCase()} • ${file.formattedSize}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.lightTextSecondary,
                                  fontFamily: 'ProductSans'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Preview not available',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.lightTextSecondary,
                          fontFamily: 'ProductSans')),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.download_outlined,
                          color: AppColors.accent),
                    ),
                    title: const Text('Export to Downloads',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('Save decrypted file to Downloads folder',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12,
                            color: AppColors.lightTextSecondary)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _exportFileToDownloads(file);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.open_in_new, color: Colors.blue),
                    ),
                    title: const Text('Open with...',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('Open file with an external app',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12,
                            color: AppColors.lightTextSecondary)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _openWithExternalApp(file);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _exportFileToDownloads(VaultedFile file) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          content: Row(
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent)),
              const SizedBox(width: 20),
              Expanded(
                  child: Text('Exporting ${file.originalName}...',
                      style: const TextStyle(fontFamily: 'ProductSans'))),
            ],
          ),
        ),
      );

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        if (mounted) Navigator.pop(context);
        ToastUtils.showError('Could not access Downloads folder');
        return;
      }

      final destinationPath = '${downloadsDir.path}/${file.originalName}';
      final vaultService = ref.read(vaultServiceProvider);
      final exportedFile =
          await vaultService.exportFile(file.id, destinationPath);

      if (mounted) Navigator.pop(context);

      if (exportedFile != null) {
        ToastUtils.showSuccess('Exported to Downloads/${file.originalName}');
      } else {
        ToastUtils.showError('Failed to export file');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error exporting file: $e');
      ToastUtils.showError('Failed to export file: $e');
    }
  }

  Future<void> _openWithExternalApp(VaultedFile file) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          content: Row(
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent)),
              const SizedBox(width: 20),
              Expanded(
                  child: Text('Preparing ${file.originalName}...',
                      style: const TextStyle(fontFamily: 'ProductSans'))),
            ],
          ),
        ),
      );

      final vaultService = ref.read(vaultServiceProvider);
      final decryptedFile = await vaultService.getVaultedFile(file.id);

      if (mounted) Navigator.pop(context);

      if (decryptedFile != null && await decryptedFile.exists()) {
        final result = await OpenFilex.open(decryptedFile.path);
        if (result.type != ResultType.done) {
          ToastUtils.showError('No app found to open this file type');
        }
      } else {
        ToastUtils.showError('Failed to prepare file');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error opening file: $e');
      ToastUtils.showError('Failed to open file: $e');
    }
  }

  void _showCreateTagDialog() {
    final nameController = TextEditingController();
    int selectedColorValue = tagColors.first.toARGB32();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          title: Text(
            'Create Tag',
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: AppColors.lightTextPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tag Name',
                  labelStyle: TextStyle(
                    fontFamily: 'ProductSans',
                    color: AppColors.lightTextSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                  prefixIcon: Icon(
                    Icons.label_outline,
                    color: Color(selectedColorValue),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Tag Color',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tagColors.map((color) {
                  final isSelected = color.toARGB32() == selectedColorValue;
                  return GestureDetector(
                    onTap: () => setDialogState(
                        () => selectedColorValue = color.toARGB32()),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.lightTextPrimary, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim().toLowerCase();
                if (name.isEmpty) {
                  ToastUtils.showError('Please enter a tag name');
                  return;
                }

                // Create the tag by adding usage count
                final vaultService = ref.read(vaultServiceProvider);
                await vaultService.createTag(name, selectedColorValue);

                if (!context.mounted) return;
                Navigator.pop(context);
                ref.invalidate(tagsProvider);
                ToastUtils.showSuccess('Tag created');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Create',
                style: TextStyle(fontFamily: 'ProductSans'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagOptions(TagInfo tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(tag.colorValue).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.label,
                          color: Color(tag.colorValue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading:
                        Icon(Icons.palette_outlined, color: AppColors.accent),
                    title: const Text(
                      'Change Color',
                      style: TextStyle(fontFamily: 'ProductSans'),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangeTagColorDialog(tag);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text(
                      'Delete Tag',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteTagDialog(tag);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showChangeTagColorDialog(TagInfo tag) {
    int selectedColorValue = tag.colorValue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          title: Text(
            'Change Color',
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: AppColors.lightTextPrimary,
            ),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tagColors.map((color) {
              final isSelected = color.toARGB32() == selectedColorValue;
              return GestureDetector(
                onTap: () =>
                    setDialogState(() => selectedColorValue = color.toARGB32()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: AppColors.lightTextPrimary, width: 3)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final vaultService = ref.read(vaultServiceProvider);
                await vaultService.updateTagColor(tag.name, selectedColorValue);

                if (!context.mounted) return;
                Navigator.pop(context);
                ref.invalidate(tagsProvider);
                ToastUtils.showSuccess('Tag color updated');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontFamily: 'ProductSans'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTagDialog(TagInfo tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Delete Tag',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${tag.name}"? This tag will be removed from all files.',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final vaultService = ref.read(vaultServiceProvider);
              await vaultService.deleteTag(tag.name);

              if (!context.mounted) return;
              Navigator.pop(context);
              ref.invalidate(tagsProvider);
              ref.invalidate(vaultNotifierProvider);
              ToastUtils.showSuccess('Tag deleted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeTagFromSelected() async {
    if (_selectedFiles.isEmpty || _selectedTag == null) return;

    final selectedList = _selectedFiles.toList();
    for (final fileId in selectedList) {
      await ref
          .read(vaultNotifierProvider.notifier)
          .removeTag(fileId, _selectedTag!);
    }

    ToastUtils.showSuccess('Removed tag from ${selectedList.length} file(s)');
    _exitSelectionMode();
    ref.invalidate(filesByTagProvider(_selectedTag!));
    ref.invalidate(tagsProvider);
  }

  Future<void> _deleteSelectedFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Delete Files',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedFiles.length} file(s)? This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(vaultNotifierProvider.notifier)
          .deleteFiles(_selectedFiles.toList());

      _exitSelectionMode();
      ref.invalidate(filesByTagProvider(_selectedTag!));
      ref.invalidate(tagsProvider);

      if (success) {
        ToastUtils.showSuccess('Files deleted');
      } else {
        ToastUtils.showError('Failed to delete some files');
      }
    }
  }

  void _showSortOptions() {
    final currentSort = ref.read(sortOptionProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextPrimary,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...SortOption.values.map((option) => ListTile(
                        leading: Icon(
                          currentSort == option
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: currentSort == option
                              ? AppColors.accent
                              : AppColors.lightTextTertiary,
                        ),
                        title: Text(
                          option.displayName,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        onTap: () {
                          ref.read(sortOptionProvider.notifier).state = option;
                          Navigator.pop(context);
                        },
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
