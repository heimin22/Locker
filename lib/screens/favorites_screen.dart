import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vaulted_file.dart';
import '../models/album.dart';
import '../providers/vault_providers.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';
import 'media_viewer_screen.dart';
import 'document_viewer_screen.dart';

/// Screen for viewing favorite files
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedFiles = {};

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteFilesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(favoritesAsync),
      body: favoritesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: AppColors.lightTextTertiary),
              const SizedBox(height: 16),
              Text(
                'Failed to load favorites',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(favoriteFilesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (files) {
          if (files.isEmpty) {
            return _buildEmptyState();
          }
          return _buildFilesGrid(files);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AsyncValue<List<VaultedFile>> favoritesAsync) {
    final fileCount = favoritesAsync.value?.length ?? 0;

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
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            onPressed: _unfavoriteSelected,
            tooltip: 'Remove from favorites',
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white),
            onPressed: _showAddToAlbumSheet,
            tooltip: 'Add to album',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteSelectedFiles,
          ),
        ],
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Favorites',
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$fileCount items',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      actions: [
        IconButton(
          icon: Icon(Icons.sort, color: AppColors.lightTextPrimary),
          onPressed: _showSortOptions,
        ),
      ],
    );
  }

  Widget _buildFilesGrid(List<VaultedFile> files) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(favoriteFilesProvider);
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
          // Favorite indicator (always show for this screen)
          if (!_isSelectionMode)
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      file.formattedSize,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'ProductSans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Document name
          if (file.isDocument)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.originalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'ProductSans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(VaultedFile file) {
    if (file.isImage) {
      return Image.file(
        File(file.vaultPath),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(file),
      );
    }

    if (file.isVideo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black87,
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 48,
                color: Colors.white70,
              ),
            ),
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              file.extension.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'ProductSans',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_outline,
              size: 64,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No favorites yet',
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
              'Tap the heart icon on any file to add it to your favorites',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.lightTextSecondary,
                fontFamily: 'ProductSans',
              ),
              textAlign: TextAlign.center,
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
    final favoritesAsync = ref.read(favoriteFilesProvider);
    final files = favoritesAsync.value ?? [];

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
      ToastUtils.showInfo('Preview not available for ${file.originalName}');
    }
  }

  Future<void> _unfavoriteSelected() async {
    final selectedList = _selectedFiles.toList();

    for (final fileId in selectedList) {
      await ref.read(vaultNotifierProvider.notifier).toggleFavorite(fileId);
    }

    ToastUtils.showSuccess('Removed ${selectedList.length} from favorites');
    _exitSelectionMode();
    ref.invalidate(favoriteFilesProvider);
  }

  void _showAddToAlbumSheet() {
    final selectedFiles = Set<String>.from(_selectedFiles);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final albumsAsync = ref.watch(albumsNotifierProvider);

          return Container(
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                        'Add to Album',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                      const SizedBox(height: 16),
                      albumsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Text('Failed to load albums'),
                        data: (albums) {
                          final customAlbums =
                              albums.where((a) => !a.isDefault).toList();

                          if (customAlbums.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No albums yet. Create one from the Albums screen.',
                                  style: TextStyle(
                                    fontFamily: 'ProductSans',
                                    color: AppColors.lightTextSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: customAlbums
                                .map((album) => ListTile(
                                      leading: Icon(
                                        Icons.folder_outlined,
                                        color: AppColors.accent,
                                      ),
                                      title: Text(
                                        album.name,
                                        style: const TextStyle(
                                          fontFamily: 'ProductSans',
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${album.fileCount} items',
                                        style: TextStyle(
                                          fontFamily: 'ProductSans',
                                          fontSize: 12,
                                          color: AppColors.lightTextTertiary,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final success = await ref
                                            .read(
                                                vaultNotifierProvider.notifier)
                                            .addToAlbum(
                                              selectedFiles.toList(),
                                              album.id,
                                            );
                                        if (success) {
                                          ToastUtils.showSuccess(
                                              'Added to ${album.name}');
                                          _exitSelectionMode();
                                        } else {
                                          ToastUtils.showError(
                                              'Failed to add to album');
                                        }
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final selectedList = _selectedFiles.toList();
      final success = await ref
          .read(vaultNotifierProvider.notifier)
          .deleteFiles(selectedList);

      _exitSelectionMode();
      ref.invalidate(favoriteFilesProvider);

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
