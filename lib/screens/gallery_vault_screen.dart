import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vaulted_file.dart';
import '../models/album.dart';
import '../providers/vault_providers.dart';
import '../services/file_import_service.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';
import 'albums_screen.dart';
import 'favorites_screen.dart';
import 'tags_screen.dart';
import 'media_viewer_screen.dart';
import 'document_viewer_screen.dart';
import '../widgets/permission_warning_banner.dart';
import 'media_picker_screen.dart';
import 'document_picker_screen.dart';
import 'package:photo_manager/photo_manager.dart' hide AlbumType;

/// Gallery vault screen - main screen after authentication
class GalleryVaultScreen extends ConsumerStatefulWidget {
  const GalleryVaultScreen({super.key});

  @override
  ConsumerState<GalleryVaultScreen> createState() => _GalleryVaultScreenState();
}

class _GalleryVaultScreenState extends ConsumerState<GalleryVaultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FileImportService _importService = FileImportService.instance;

  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeVault();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeVault() async {
    await ref.read(vaultServiceProvider).initialize();
    ref.read(vaultNotifierProvider.notifier).loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(vaultNotifierProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(isSelectionMode, selectedFiles),
      body: Column(
        children: [
          // Permission warning banner for All Files Access
          const PermissionWarningBanner(),
          if (_isImporting) _buildImportProgress(),
          if (_isSearching) _buildSearchBar(),
          _buildTabBar(filesAsync),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFileGrid(null, filesAsync),
                _buildFileGrid(VaultedFileType.image, filesAsync),
                _buildFileGrid(VaultedFileType.video, filesAsync),
                _buildFileGrid(VaultedFileType.document, filesAsync),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode ? null : _buildFAB(),
      drawer: _buildDrawer(),
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool isSelectionMode, Set<String> selectedFiles) {
    if (isSelectionMode) {
      return AppBar(
        backgroundColor: AppColors.accent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${selectedFiles.length} selected',
          style: const TextStyle(
            fontFamily: 'ProductSans',
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: Colors.white),
            onPressed: () => _unhideSelectedFiles(selectedFiles),
            tooltip: 'Unhide (restore to gallery)',
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white),
            onPressed: () => _showAddToAlbumSheet(selectedFiles),
            tooltip: 'Add to album',
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline, color: Colors.white),
            onPressed: () => _toggleFavoriteSelected(selectedFiles),
            tooltip: 'Toggle favorite',
          ),
          IconButton(
            icon: const Icon(Icons.label_outline, color: Colors.white),
            onPressed: () => _showAddTagsSheet(selectedFiles),
            tooltip: 'Add tags',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _deleteSelectedFiles(selectedFiles),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(
        'Gallery Vault',
        style: TextStyle(
          fontFamily: 'ProductSans',
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: AppColors.lightTextPrimary,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              }
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.sort, color: AppColors.lightTextPrimary),
          onPressed: _showSortOptions,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.lightTextPrimary),
          onSelected: (value) {
            switch (value) {
              case 'albums':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlbumsScreen()),
                );
                break;
              case 'settings':
                _showSettingsSheet();
                break;
              case 'refresh':
                ref.read(vaultNotifierProvider.notifier).refresh();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'albums',
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Albums'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.lightBackgroundSecondary,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search files...',
          hintStyle: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextTertiary,
          ),
          prefixIcon:
              Icon(Icons.search, color: AppColors.lightTextTertiary, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.lightBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(
          fontFamily: 'ProductSans',
          color: AppColors.lightTextPrimary,
        ),
        onChanged: (value) {
          ref.read(searchQueryProvider.notifier).state = value;
        },
      ),
    );
  }

  Widget _buildImportProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.accent.withValues(alpha: 0.1),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
              value: _importTotal > 0 ? _importProgress / _importTotal : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _importTotal > 0
                  ? 'Importing... $_importProgress / $_importTotal'
                  : 'Importing...',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AsyncValue<List<VaultedFile>> filesAsync) {
    final files = filesAsync.value ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.lightTextTertiary,
        indicatorColor: AppColors.accent,
        indicatorWeight: 3,
        isScrollable: true,
        labelStyle: const TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_view_rounded, size: 18),
                const SizedBox(width: 6),
                Text('All (${files.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                    'Images (${files.where((f) => f.type == VaultedFileType.image).length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                    'Videos (${files.where((f) => f.type == VaultedFileType.video).length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                    'Docs (${files.where((f) => f.type == VaultedFileType.document || f.type == VaultedFileType.other).length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileGrid(
      VaultedFileType? filterType, AsyncValue<List<VaultedFile>> filesAsync) {
    return filesAsync.when(
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
              'Failed to load files',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(vaultNotifierProvider.notifier).loadFiles(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allFiles) {
        // Filter by type
        List<VaultedFile> files;
        if (filterType == null) {
          files = allFiles;
        } else if (filterType == VaultedFileType.document) {
          files = allFiles
              .where((f) =>
                  f.type == VaultedFileType.document ||
                  f.type == VaultedFileType.other)
              .toList();
        } else {
          files = allFiles.where((f) => f.type == filterType).toList();
        }

        // Apply search filter
        final searchQuery = ref.watch(searchQueryProvider);
        if (searchQuery.isNotEmpty) {
          files = files
              .where((f) => f.originalName
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
              .toList();
        }

        // Apply sorting
        final sortOption = ref.watch(sortOptionProvider);
        files = ref.read(vaultServiceProvider).sortFiles(files, sortOption);

        if (files.isEmpty) {
          return _buildEmptyState(filterType);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(vaultNotifierProvider.notifier).refresh();
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

  Widget _buildFileItem(VaultedFile file) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final isSelected = selectedFiles.contains(file.id);

    return GestureDetector(
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(file.id);
        } else {
          _openFile(file);
        }
      },
      onLongPress: () {
        if (!isSelectionMode) {
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
          if (isSelectionMode)
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
          if (file.isFavorite && !isSelectionMode)
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
          // Encrypted indicator
          if (file.isEncrypted && !isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.lock,
                  size: 14,
                  color: Colors.green,
                ),
              ),
            ),
          // Tags indicator
          if (file.hasTags && !isSelectionMode)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.label, size: 12, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      '${file.tagCount}',
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
          // Video duration indicator
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
          // File type badge for documents
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
    // Show image thumbnail
    if (file.isImage) {
      final imageFile = File(file.vaultPath);

      // Use FutureBuilder to check file existence first
      return FutureBuilder<bool>(
        future: imageFile.exists(),
        builder: (context, snapshot) {
          if (snapshot.data != true) {
            return _buildPlaceholder(file);
          }

          // Use Image.file with defensive error handling
          return Image.file(
            imageFile,
            fit: BoxFit.cover,
            cacheWidth: 300, // Limit resolution for performance
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              // Show placeholder while loading
              return Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Log error for debugging but show placeholder gracefully
              debugPrint('Error loading image: ${file.originalName} - $error');
              return _buildPlaceholder(file);
            },
          );
        },
      );
    }

    // Show video thumbnail (first frame preview)
    if (file.isVideo) {
      // Try to show video thumbnail from the vault path
      // Videos don't have a simple thumbnail, so we use a styled placeholder
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
        icon = _getDocumentIcon(file.extension);
        color = _getDocumentColor(file.extension);
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

  IconData _getDocumentIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  void _toggleSelection(String fileId) {
    final selectedFiles = ref.read(selectedFilesProvider);
    if (selectedFiles.contains(fileId)) {
      ref.read(selectedFilesProvider.notifier).state = Set.from(selectedFiles)
        ..remove(fileId);
      if (selectedFiles.length == 1) {
        ref.read(isSelectionModeProvider.notifier).state = false;
      }
    } else {
      ref.read(selectedFilesProvider.notifier).state = Set.from(selectedFiles)
        ..add(fileId);
    }
  }

  void _enterSelectionMode(String fileId) {
    ref.read(isSelectionModeProvider.notifier).state = true;
    ref.read(selectedFilesProvider.notifier).state = {fileId};
  }

  void _exitSelectionMode() {
    ref.read(isSelectionModeProvider.notifier).state = false;
    ref.read(selectedFilesProvider.notifier).state = {};
  }

  void _openFile(VaultedFile file) {
    // Get the current list of files for navigation in viewer
    final filesAsync = ref.read(vaultNotifierProvider);
    final allFiles = filesAsync.value ?? [];

    // Filter files based on type for viewer navigation
    List<VaultedFile> viewerFiles;
    int initialIndex;

    if (file.isImage || file.isVideo) {
      // For media files, include both images and videos
      viewerFiles = allFiles.where((f) => f.isImage || f.isVideo).toList();
      initialIndex = viewerFiles.indexWhere((f) => f.id == file.id);
      if (initialIndex == -1) initialIndex = 0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerScreen(
            initialFile: file,
            files: viewerFiles,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (file.isDocument) {
      // For documents, open document viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(file: file),
        ),
      );
    } else {
      // For other files, show info
      ToastUtils.showInfo('Preview not available for ${file.originalName}');
    }
  }

  Widget _buildEmptyState(VaultedFileType? filterType) {
    String title;
    String subtitle;
    IconData icon;

    if (filterType == null) {
      title = 'No files yet';
      subtitle = 'Your hidden files will appear here';
      icon = Icons.folder_open_outlined;
    } else {
      switch (filterType) {
        case VaultedFileType.image:
          title = 'No images yet';
          subtitle = 'Import images from gallery or camera';
          icon = Icons.image_outlined;
          break;
        case VaultedFileType.video:
          title = 'No videos yet';
          subtitle = 'Import videos from gallery or camera';
          icon = Icons.videocam_outlined;
          break;
        case VaultedFileType.document:
          title = 'No documents yet';
          subtitle = 'Import PDFs, Word docs, and more';
          icon = Icons.description_outlined;
          break;
        case VaultedFileType.other:
          title = 'No other files yet';
          subtitle = 'Import any files';
          icon = Icons.folder_open_outlined;
          break;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.lightBackgroundSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.lightTextTertiary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Files'),
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

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showImportDialog,
      backgroundColor: AppColors.accent,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Import',
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.lightBackground,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              color: AppColors.accent,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/padlock.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Locker',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, ref, _) {
                      final storageAsync = ref.watch(formattedStorageProvider);
                      final countAsync = ref.watch(fileCountSummaryProvider);

                      return Text(
                        '${countAsync.value ?? '...'} • ${storageAsync.value ?? '...'}',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text(
              'Albums',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlbumsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text(
              'Favorites',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FavoritesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text(
              'Tags',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TagsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text(
              'Security Settings',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
            onTap: () {
              Navigator.pop(context);
              _showSettingsSheet();
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text(
              'Decoy Mode',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
            subtitle: const Text(
              'Set up fake vault',
              style: TextStyle(fontFamily: 'ProductSans', fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDecoyModeSheet();
            },
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ImportOptionsSheet(
        onImportImages: _importImagesFromGallery,
        onImportVideos: _importVideosFromGallery,
        onImportMedia: _importMediaFromGallery,
        onCapturePhoto: _capturePhoto,
        onRecordVideo: _recordVideo,
        onImportDocuments: _importDocuments,
        onImportAnyFiles: _importAnyFiles,
      ),
    );
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

  void _showAddToAlbumSheet(Set<String> selectedFiles) {
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
                        data: (albums) => Column(
                          children: albums
                              .where((a) =>
                                  !a.isDefault || a.type == AlbumType.favorites)
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
                                          .read(vaultNotifierProvider.notifier)
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
                        ),
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

  void _showAddTagsSheet(Set<String> selectedFiles) {
    final tagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final tagsAsync = ref.watch(tagsProvider);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
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
                          'Add Tags',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightTextPrimary,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                        Text(
                          '${selectedFiles.length} file(s) selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.lightTextSecondary,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: tagController,
                          decoration: InputDecoration(
                            hintText: 'Create new tag',
                            hintStyle: TextStyle(
                              fontFamily: 'ProductSans',
                              color: AppColors.lightTextTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                            prefixIcon: Icon(Icons.label_outline,
                                color: AppColors.lightTextSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add, color: AppColors.accent),
                              onPressed: () async {
                                final tag = tagController.text.trim();
                                if (tag.isEmpty) return;

                                // Create tag if it doesn't exist
                                final vaultService =
                                    ref.read(vaultServiceProvider);
                                await vaultService.createTag(tag);

                                for (final fileId in selectedFiles) {
                                  await ref
                                      .read(vaultNotifierProvider.notifier)
                                      .addTag(fileId, tag);
                                }

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ref.invalidate(tagsProvider);
                                ToastUtils.showSuccess('Tag added');
                                _exitSelectionMode();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Existing Tags',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextTertiary,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                        const SizedBox(height: 8),
                        tagsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (_, __) => Text(
                            'Failed to load tags',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                          data: (tags) {
                            if (tags.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    'No tags yet. Create one above!',
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
                                      color: AppColors.lightTextTertiary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags
                                  .map((tag) => ActionChip(
                                        avatar: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Color(tag.colorValue),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        label: Text(
                                          tag.name,
                                          style: const TextStyle(
                                            fontFamily: 'ProductSans',
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () async {
                                          for (final fileId in selectedFiles) {
                                            await ref
                                                .read(vaultNotifierProvider
                                                    .notifier)
                                                .addTag(fileId, tag.name);
                                          }

                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                          ref.invalidate(tagsProvider);
                                          ToastUtils.showSuccess('Tag added');
                                          _exitSelectionMode();
                                        },
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Quick Tags',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextTertiary,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: predefinedTags
                              .map((tag) => ActionChip(
                                    label: Text(
                                      tag,
                                      style: const TextStyle(
                                        fontFamily: 'ProductSans',
                                        fontSize: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      // Create tag if doesn't exist
                                      final vaultService =
                                          ref.read(vaultServiceProvider);
                                      await vaultService.createTag(tag);

                                      for (final fileId in selectedFiles) {
                                        await ref
                                            .read(
                                                vaultNotifierProvider.notifier)
                                            .addTag(fileId, tag);
                                      }

                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      ref.invalidate(tagsProvider);
                                      ToastUtils.showSuccess('Tag added');
                                      _exitSelectionMode();
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleFavoriteSelected(Set<String> selectedFiles) async {
    for (final fileId in selectedFiles) {
      await ref.read(vaultNotifierProvider.notifier).toggleFavorite(fileId);
    }
    ToastUtils.showSuccess('Favorites updated');
    _exitSelectionMode();
  }

  Future<void> _unhideSelectedFiles(Set<String> selectedFiles) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Unhide Files',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to unhide ${selectedFiles.length} file(s)? This will restore them to your device gallery (DCIM/Restored folder) and remove them from the vault.',
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
              'Unhide',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isImporting = true;
        _importProgress = 0;
        _importTotal = selectedFiles.length;
      });

      final result = await _importService.unhideFiles(
        fileIds: selectedFiles.toList(),
        removeFromVault: true,
        onProgress: (current, total) {
          setState(() {
            _importProgress = current;
            _importTotal = total;
          });
        },
      );

      setState(() => _isImporting = false);
      _exitSelectionMode();

      if (result.success && result.unhiddenCount > 0) {
        ToastUtils.showSuccess(result.message ?? 'Files restored to gallery');
        ref.read(vaultNotifierProvider.notifier).loadFiles();
      } else if (!result.success) {
        ToastUtils.showError(result.error ?? 'Failed to unhide files');
      }
    }
  }

  Future<void> _deleteSelectedFiles(Set<String> selectedFiles) async {
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
          'Are you sure you want to delete ${selectedFiles.length} file(s)? This action cannot be undone.',
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
      // Check if still mounted after async gap
      if (!mounted) return;

      // Use a Completer to ensure dialog is shown before starting delete operation
      final dialogContext = Completer<BuildContext>();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          // Complete with the dialog's context once it's built
          if (!dialogContext.isCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!dialogContext.isCompleted) {
                dialogContext.complete(ctx);
              }
            });
          }
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: AppColors.lightBackground,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Deleting ${selectedFiles.length} file(s)...',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Wait for the dialog to be fully rendered before starting the delete operation
      await dialogContext.future;

      final success = await ref
          .read(vaultNotifierProvider.notifier)
          .deleteFiles(selectedFiles.toList());

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      _exitSelectionMode();

      if (success) {
        ToastUtils.showSuccess('Files deleted');
      } else {
        ToastUtils.showError('Failed to delete some files');
      }
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final settingsAsync = ref.watch(vaultSettingsProvider);

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
                        'Security Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                      const SizedBox(height: 16),
                      settingsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Text('Failed to load settings'),
                        data: (settings) => Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Encrypt New Files',
                                style: TextStyle(fontFamily: 'ProductSans'),
                              ),
                              subtitle: Text(
                                'AES-256 encryption for all new imports',
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 12,
                                  color: AppColors.lightTextTertiary,
                                ),
                              ),
                              value: settings.encryptionEnabled,
                              onChanged: (value) async {
                                await ref
                                    .read(vaultServiceProvider)
                                    .updateSettings(settings.copyWith(
                                      encryptionEnabled: value,
                                    ));
                                ref.invalidate(vaultSettingsProvider);
                              },
                              activeThumbColor: AppColors.accent,
                              contentPadding: EdgeInsets.zero,
                            ),
                            SwitchListTile(
                              title: const Text(
                                'Secure Delete',
                                style: TextStyle(fontFamily: 'ProductSans'),
                              ),
                              subtitle: Text(
                                'Overwrite files before deletion',
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 12,
                                  color: AppColors.lightTextTertiary,
                                ),
                              ),
                              value: settings.secureDelete,
                              onChanged: (value) async {
                                await ref
                                    .read(vaultServiceProvider)
                                    .updateSettings(settings.copyWith(
                                      secureDelete: value,
                                    ));
                                ref.invalidate(vaultSettingsProvider);
                              },
                              activeThumbColor: AppColors.accent,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
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

  void _showDecoyModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final decoySettingsAsync = ref.watch(decoySettingsProvider);

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
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Decoy Mode',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightTextPrimary,
                              fontFamily: 'ProductSans',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up a fake vault that shows when using a different PIN/password. Perfect for situations where you might be forced to open the app.',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          color: AppColors.lightTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      decoySettingsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Text('Failed to load settings'),
                        data: (settings) => Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Enable Decoy Mode',
                                style: TextStyle(fontFamily: 'ProductSans'),
                              ),
                              value: settings.isEnabled,
                              onChanged: (value) async {
                                final decoyService =
                                    ref.read(decoyServiceProvider);
                                if (value) {
                                  await decoyService.enableDecoyMode();
                                } else {
                                  await decoyService.disableDecoyMode();
                                }
                                ref.invalidate(decoySettingsProvider);
                              },
                              activeThumbColor: AppColors.accent,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (settings.isEnabled) ...[
                              ListTile(
                                leading: Icon(
                                  settings.hasPinSet
                                      ? Icons.check_circle
                                      : Icons.radio_button_off,
                                  color: settings.hasPinSet
                                      ? Colors.green
                                      : AppColors.lightTextTertiary,
                                ),
                                title: const Text(
                                  'Set Decoy PIN',
                                  style: TextStyle(fontFamily: 'ProductSans'),
                                ),
                                subtitle: Text(
                                  settings.hasPinSet
                                      ? 'Decoy PIN is set'
                                      : 'Not configured',
                                  style: TextStyle(
                                    fontFamily: 'ProductSans',
                                    fontSize: 12,
                                    color: AppColors.lightTextTertiary,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showSetDecoyPinDialog();
                                },
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
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

  void _showSetDecoyPinDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Set Decoy PIN',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This PIN will show your decoy vault instead of your real files.',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Decoy PIN (4-6 digits)',
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
              ),
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
              final pin = pinController.text.trim();
              if (pin.length < 4) {
                ToastUtils.showError('PIN must be at least 4 digits');
                return;
              }

              final success =
                  await ref.read(decoyServiceProvider).setDecoyPin(pin);
              if (!context.mounted) return;
              if (success) {
                Navigator.pop(context);
                ref.invalidate(decoySettingsProvider);
                ToastUtils.showSuccess('Decoy PIN set');
              } else {
                ToastUtils.showError('Failed to set decoy PIN');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Set PIN',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
          ),
        ],
      ),
    );
  }

  // Import methods
  Future<void> _importImagesFromGallery() async {
    Navigator.pop(context);

    // Open custom media picker for images
    final selectedAssets = await Navigator.push<List<AssetEntity>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const MediaPickerScreen(
          requestType: RequestType.image,
          title: 'Select Images to Hide',
        ),
      ),
    );

    if (selectedAssets == null || selectedAssets.isEmpty) {
      ToastUtils.showInfo('No images selected');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedAssets.length;
    });

    final result = await _importService.importFromAssets(
      assets: selectedAssets,
      deleteOriginals: true, // Hide from gallery
      onProgress: (current, total) {
        setState(() {
          _importProgress = current;
          _importTotal = total;
        });
      },
    );

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      final msg = result.deletedOriginals
          ? 'Imported and hidden ${result.importedCount} image(s)'
          : 'Imported ${result.importedCount} image(s) (originals may still be visible)';
      ToastUtils.showSuccess(msg);
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Import failed');
    }
  }

  Future<void> _importVideosFromGallery() async {
    Navigator.pop(context);

    // Open custom media picker for videos
    final selectedAssets = await Navigator.push<List<AssetEntity>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const MediaPickerScreen(
          requestType: RequestType.video,
          title: 'Select Videos to Hide',
        ),
      ),
    );

    if (selectedAssets == null || selectedAssets.isEmpty) {
      ToastUtils.showInfo('No videos selected');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedAssets.length;
    });

    final result = await _importService.importFromAssets(
      assets: selectedAssets,
      deleteOriginals: true, // Hide from gallery
      onProgress: (current, total) {
        setState(() {
          _importProgress = current;
          _importTotal = total;
        });
      },
    );

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      final msg = result.deletedOriginals
          ? 'Imported and hidden ${result.importedCount} video(s)'
          : 'Imported ${result.importedCount} video(s) (originals may still be visible)';
      ToastUtils.showSuccess(msg);
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Import failed');
    }
  }

  Future<void> _importMediaFromGallery() async {
    Navigator.pop(context);

    // Open custom media picker for all media (images and videos)
    final selectedAssets = await Navigator.push<List<AssetEntity>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const MediaPickerScreen(
          requestType: RequestType.common,
          title: 'Select Media to Hide',
        ),
      ),
    );

    if (selectedAssets == null || selectedAssets.isEmpty) {
      ToastUtils.showInfo('No media selected');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedAssets.length;
    });

    final result = await _importService.importFromAssets(
      assets: selectedAssets,
      deleteOriginals: true, // Hide from gallery
      onProgress: (current, total) {
        setState(() {
          _importProgress = current;
          _importTotal = total;
        });
      },
    );

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      final msg = result.deletedOriginals
          ? 'Imported and hidden ${result.importedCount} file(s)'
          : 'Imported ${result.importedCount} file(s) (originals may still be visible)';
      ToastUtils.showSuccess(msg);
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Import failed');
    }
  }

  Future<void> _capturePhoto() async {
    Navigator.pop(context);
    setState(() => _isImporting = true);

    final result = await _importService.capturePhotoFromCamera();

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      ToastUtils.showSuccess('Photo captured and hidden');
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Capture failed');
    }
  }

  Future<void> _recordVideo() async {
    Navigator.pop(context);
    setState(() => _isImporting = true);

    final result = await _importService.recordVideoFromCamera();

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      ToastUtils.showSuccess('Video recorded and hidden');
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Recording failed');
    }
  }

  Future<void> _importDocuments() async {
    Navigator.pop(context);

    // Open custom document picker
    final selectedDocuments = await Navigator.push<List<DocumentFile>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentPickerScreen(
          title: 'Select Documents to Hide',
        ),
      ),
    );

    if (selectedDocuments == null || selectedDocuments.isEmpty) {
      ToastUtils.showInfo('No documents selected');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedDocuments.length;
    });

    final result = await _importService.importFromDocumentFiles(
      filePaths: selectedDocuments.map((d) => d.path).toList(),
      deleteOriginals: true, // Hide from file manager
      onProgress: (current, total) {
        setState(() {
          _importProgress = current;
          _importTotal = total;
        });
      },
    );

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      final msg = result.deletedOriginals
          ? 'Imported and hidden ${result.importedCount} document(s)'
          : 'Imported ${result.importedCount} document(s)';
      ToastUtils.showSuccess(msg);
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Import failed');
    } else {
      ToastUtils.showInfo('No documents selected');
    }
  }

  Future<void> _importAnyFiles() async {
    Navigator.pop(context);
    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = 0;
    });

    final result = await _importService.importAnyFiles(
      deleteOriginals: true, // Hide originals
      onProgress: (current, total) {
        setState(() {
          _importProgress = current;
          _importTotal = total;
        });
      },
    );

    setState(() => _isImporting = false);

    if (result.success && result.importedCount > 0) {
      final msg = result.deletedOriginals
          ? 'Imported and hidden ${result.importedCount} file(s)'
          : 'Imported ${result.importedCount} file(s)';
      ToastUtils.showSuccess(msg);
      ref.read(vaultNotifierProvider.notifier).loadFiles();
    } else if (!result.success) {
      ToastUtils.showError(result.error ?? 'Import failed');
    } else {
      ToastUtils.showInfo('No files selected');
    }
  }
}

/// Import options bottom sheet
class _ImportOptionsSheet extends StatelessWidget {
  final VoidCallback onImportImages;
  final VoidCallback onImportVideos;
  final VoidCallback onImportMedia;
  final VoidCallback onCapturePhoto;
  final VoidCallback onRecordVideo;
  final VoidCallback onImportDocuments;
  final VoidCallback onImportAnyFiles;

  const _ImportOptionsSheet({
    required this.onImportImages,
    required this.onImportVideos,
    required this.onImportMedia,
    required this.onCapturePhoto,
    required this.onRecordVideo,
    required this.onImportDocuments,
    required this.onImportAnyFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Import Files',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightTextPrimary,
                    fontFamily: 'ProductSans',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Files will be encrypted and hidden securely',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.lightTextSecondary,
                    fontFamily: 'ProductSans',
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('From Gallery'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.photo_library_outlined,
                        label: 'Images',
                        color: Colors.blue,
                        onTap: onImportImages,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.video_library_outlined,
                        label: 'Videos',
                        color: Colors.red,
                        onTap: onImportVideos,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.perm_media_outlined,
                        label: 'All Media',
                        color: Colors.purple,
                        onTap: onImportMedia,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('From Camera'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.camera_alt_outlined,
                        label: 'Take Photo',
                        color: Colors.teal,
                        onTap: onCapturePhoto,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.videocam_outlined,
                        label: 'Record Video',
                        color: Colors.orange,
                        onTap: onRecordVideo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('From File Manager'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.description_outlined,
                        label: 'Documents',
                        color: Colors.green,
                        onTap: onImportDocuments,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImportOptionTile(
                        icon: Icons.folder_open_outlined,
                        label: 'Any File',
                        color: Colors.blueGrey,
                        onTap: onImportAnyFiles,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextTertiary,
        fontFamily: 'ProductSans',
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'ProductSans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
