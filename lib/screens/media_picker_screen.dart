import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../themes/app_colors.dart';

/// A custom media picker that uses PhotoManager to directly access gallery assets.
/// This allows proper deletion of original files from the gallery.
class MediaPickerScreen extends StatefulWidget {
  /// The type of media to show (image, video, or all)
  final RequestType requestType;

  /// Maximum number of items that can be selected (0 = unlimited)
  final int maxSelection;

  /// Title for the app bar
  final String title;

  const MediaPickerScreen({
    super.key,
    this.requestType = RequestType.common,
    this.maxSelection = 0,
    this.title = 'Select Media',
  });

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final Set<AssetEntity> _selectedAssets = {};
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _pageSize = 80;
  bool _hasMoreToLoad = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreAssets();
    }
  }

  Future<void> _loadAlbums() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (mounted) {
        Navigator.pop(context, null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied')),
        );
      }
      return;
    }

    // Configure filter to sort by creation date (most recent first)
    final filterOption = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      videoOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: widget.requestType,
      hasAll: true,
      filterOption: filterOption,
    );

    if (albums.isNotEmpty) {
      setState(() {
        _albums = albums;
        _currentAlbum = albums.first;
      });
      await _loadAssets();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssets() async {
    if (_currentAlbum == null) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _assets = [];
      _hasMoreToLoad = true;
    });

    final assets = await _currentAlbum!.getAssetListPaged(
      page: 0,
      size: _pageSize,
    );

    setState(() {
      _assets = assets;
      _isLoading = false;
      _hasMoreToLoad = assets.length >= _pageSize;
    });
  }

  Future<void> _loadMoreAssets() async {
    if (_currentAlbum == null || _isLoading || !_hasMoreToLoad) return;

    setState(() => _isLoading = true);

    final nextPage = _currentPage + 1;
    final assets = await _currentAlbum!.getAssetListPaged(
      page: nextPage,
      size: _pageSize,
    );

    setState(() {
      _currentPage = nextPage;
      _assets.addAll(assets);
      _isLoading = false;
      _hasMoreToLoad = assets.length >= _pageSize;
    });
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        if (widget.maxSelection > 0 &&
            _selectedAssets.length >= widget.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Maximum ${widget.maxSelection} items can be selected'),
              duration: const Duration(seconds: 1),
            ),
          );
          return;
        }
        _selectedAssets.add(asset);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (widget.maxSelection > 0) {
        // Select up to max
        for (final asset in _assets) {
          if (_selectedAssets.length >= widget.maxSelection) break;
          _selectedAssets.add(asset);
        }
      } else {
        _selectedAssets.addAll(_assets);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedAssets.clear();
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _selectedAssets.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.lightTextPrimary),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: _buildAlbumDropdown(),
        actions: [
          if (_selectedAssets.isNotEmpty)
            TextButton(
              onPressed: _clearSelection,
              child: const Text('Clear'),
            ),
          if (_assets.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: const Text('Select All'),
            ),
        ],
      ),
      body: _isLoading && _assets.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            )
          : _assets.isEmpty
              ? _buildEmptyState()
              : _buildMediaGrid(),
      bottomNavigationBar:
          _selectedAssets.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  Widget _buildAlbumDropdown() {
    if (_albums.isEmpty) {
      return Text(
        widget.title,
        style: TextStyle(
          fontFamily: 'ProductSans',
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return PopupMenuButton<AssetPathEntity>(
      initialValue: _currentAlbum,
      onSelected: (album) {
        setState(() {
          _currentAlbum = album;
        });
        _loadAssets();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _currentAlbum?.name ?? widget.title,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_drop_down, color: AppColors.lightTextPrimary),
        ],
      ),
      itemBuilder: (context) => _albums.map((album) {
        return PopupMenuItem(
          value: album,
          child: FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                '${album.name} ($count)',
                style: const TextStyle(fontFamily: 'ProductSans'),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No media found',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 18,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length + (_hasMoreToLoad ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _assets.length) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          );
        }
        return _buildAssetTile(_assets[index]);
      },
    );
  }

  Widget _buildAssetTile(AssetEntity asset) {
    final isSelected = _selectedAssets.contains(asset);
    final selectionIndex = _selectedAssets.toList().indexOf(asset);

    return GestureDetector(
      onTap: () => _toggleSelection(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
              quality: 80,
            ),
            builder: (context, snapshot) {
              // Handle errors gracefully
              if (snapshot.hasError) {
                return Container(
                  color: AppColors.lightBackgroundSecondary,
                  child: Icon(
                    asset.type == AssetType.video
                        ? Icons.videocam
                        : Icons.image,
                    color: AppColors.lightTextTertiary,
                  ),
                );
              }

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.isNotEmpty) {
                try {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true, // Prevent flickering
                    errorBuilder: (context, error, stackTrace) {
                      // Handle image decode errors
                      return Container(
                        color: AppColors.lightBackgroundSecondary,
                        child: Icon(
                          asset.type == AssetType.video
                              ? Icons.videocam
                              : Icons.image,
                          color: AppColors.lightTextTertiary,
                        ),
                      );
                    },
                  );
                } catch (e) {
                  // Fallback for any other errors
                  return Container(
                    color: AppColors.lightBackgroundSecondary,
                    child: Icon(
                      asset.type == AssetType.video
                          ? Icons.videocam
                          : Icons.image,
                      color: AppColors.lightTextTertiary,
                    ),
                  );
                }
              }

              // Loading state
              return Container(
                color: AppColors.lightBackgroundSecondary,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.accent.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              );
            },
          ),

          // Video indicator
          if (asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.videoDuration),
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

          // Selection overlay
          if (isSelected)
            Container(
              color: AppColors.accent.withValues(alpha: 0.3),
            ),

          // Selection indicator
          Positioned(
            top: 4,
            right: 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.7),
                border: Border.all(
                  color: isSelected ? AppColors.accent : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Text(
                        '${selectionIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedAssets.length} selected',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Hide Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Result from the media picker containing the selected assets
class MediaPickerResult {
  final List<AssetEntity> selectedAssets;

  const MediaPickerResult({required this.selectedAssets});

  bool get isEmpty => selectedAssets.isEmpty;
  bool get isNotEmpty => selectedAssets.isNotEmpty;
  int get count => selectedAssets.length;
}
