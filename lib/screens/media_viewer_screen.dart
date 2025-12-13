import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import '../models/vaulted_file.dart';
import '../providers/vault_providers.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';

/// Full-screen media viewer for images and videos with slideshow support
class MediaViewerScreen extends ConsumerStatefulWidget {
  final VaultedFile initialFile;
  final List<VaultedFile> files;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.initialFile,
    required this.files,
    required this.initialIndex,
  });

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _isSlideshow = false;
  int _slideshowDuration = 3; // seconds

  // Video player for current video
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  // For encrypted files
  final Map<String, Uint8List?> _decryptedCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrentMedia();

    // Hide system UI for immersive view
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadCurrentMedia() async {
    final file = widget.files[_currentIndex];

    if (file.isVideo) {
      await _initializeVideo(file);
    }

    // Pre-load decrypted data for encrypted files
    if (file.isEncrypted && !_decryptedCache.containsKey(file.id)) {
      final data =
          await ref.read(vaultServiceProvider).getDecryptedFileData(file.id);
      if (mounted) {
        setState(() {
          _decryptedCache[file.id] = data;
        });
      }
    }
  }

  Future<void> _initializeVideo(VaultedFile file) async {
    // Dispose previous controller
    await _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _isVideoPlaying = false;

    if (!file.isVideo) return;

    try {
      File videoFile;

      if (file.isEncrypted && file.encryptionIv != null) {
        // Get decrypted file
        final decryptedFile =
            await ref.read(vaultServiceProvider).getVaultedFile(file.id);
        if (decryptedFile == null) {
          ToastUtils.showError('Failed to decrypt video');
          return;
        }
        videoFile = decryptedFile;
      } else {
        videoFile = File(file.vaultPath);
      }

      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      ToastUtils.showError('Failed to load video');
    }
  }

  void _onPageChanged(int index) {
    // Pause current video if playing
    _videoController?.pause();
    _isVideoPlaying = false;

    setState(() {
      _currentIndex = index;
    });

    _loadCurrentMedia();

    // Mark as viewed
    final file = widget.files[index];
    ref.read(vaultServiceProvider).updateFile(file.markViewed());
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleFavorite() async {
    final file = widget.files[_currentIndex];
    final wasFavorite = file.isFavorite;
    await ref.read(vaultNotifierProvider.notifier).toggleFavorite(file.id);
    ToastUtils.showSuccess(
      wasFavorite ? 'Removed from favorites' : 'Added to favorites',
    );
  }

  void _startSlideshow() {
    if (_isSlideshow) {
      setState(() => _isSlideshow = false);
      return;
    }

    setState(() {
      _isSlideshow = true;
      _showControls = false;
    });

    _runSlideshow();
  }

  void _runSlideshow() async {
    while (_isSlideshow && mounted) {
      await Future.delayed(Duration(seconds: _slideshowDuration));
      if (!_isSlideshow || !mounted) break;

      // Move to next image (skip videos in slideshow)
      int nextIndex = _currentIndex;
      do {
        nextIndex = (nextIndex + 1) % widget.files.length;
        if (nextIndex == _currentIndex) break; // Completed full loop
      } while (widget.files[nextIndex].isVideo);

      if (nextIndex != _currentIndex) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showSlideshowSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Slideshow Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
                fontFamily: 'ProductSans',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Duration per slide',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setSheetState) => Row(
                children: [
                  for (final seconds in [2, 3, 5, 10])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${seconds}s'),
                        selected: _slideshowDuration == seconds,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() {});
                            setState(() => _slideshowDuration = seconds);
                          }
                        },
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: _slideshowDuration == seconds
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startSlideshow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isSlideshow ? 'Stop Slideshow' : 'Start Slideshow',
                  style: const TextStyle(fontFamily: 'ProductSans'),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _toggleVideoPlayback() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_isVideoPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  void _showFileInfo() {
    final file = widget.files[_currentIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
                fontFamily: 'ProductSans',
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', file.originalName),
            _buildInfoRow('Type', file.type.displayName),
            _buildInfoRow('Size', file.formattedSize),
            _buildInfoRow('Added', file.formattedDateAdded),
            if (file.isEncrypted) _buildInfoRow('Encrypted', 'Yes'),
            if (file.hasTags) _buildInfoRow('Tags', file.tags.join(', ')),
            if (file.viewCount > 0)
              _buildInfoRow('Views', file.viewCount.toString()),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

  @override
  Widget build(BuildContext context) {
    final currentFile = widget.files[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Main content
            if (currentFile.isImage)
              _buildImageGallery()
            else if (currentFile.isVideo)
              _buildVideoPlayer(currentFile)
            else
              _buildUnsupportedFile(currentFile),

            // Top controls
            if (_showControls) _buildTopControls(currentFile),

            // Bottom controls
            if (_showControls) _buildBottomControls(currentFile),

            // Slideshow indicator
            if (_isSlideshow)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.slideshow,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Slideshow',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _isSlideshow = false),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (context, index) {
        final file = widget.files[index];

        if (file.isEncrypted) {
          final data = _decryptedCache[file.id];
          if (data != null) {
            // Use customChild for encrypted images to handle decode errors
            return PhotoViewGalleryPageOptions.customChild(
              child: PhotoView.customChild(
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: PhotoViewHeroAttributes(tag: file.id),
                child: Image.memory(
                  data,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error decoding encrypted image: $error');
                    return _buildImageErrorPlaceholder(file);
                  },
                ),
              ),
            );
          }
          // Loading placeholder
          return PhotoViewGalleryPageOptions.customChild(
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // Use customChild with Image.file for proper error handling
        return PhotoViewGalleryPageOptions.customChild(
          child: PhotoView.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: file.id),
            child: Image.file(
              File(file.vaultPath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error decoding image file: $error');
                return _buildImageErrorPlaceholder(file);
              },
            ),
          ),
        );
      },
      itemCount: widget.files.length,
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event == null
              ? null
              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          color: Colors.white,
        ),
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      pageController: _pageController,
      onPageChanged: _onPageChanged,
    );
  }

  Widget _buildImageErrorPlaceholder(VaultedFile file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            file.originalName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to display this image',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The file may be corrupted or in an unsupported format',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(VaultedFile file) {
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            // Play/pause overlay
            GestureDetector(
              onTap: _toggleVideoPlayback,
              child: AnimatedOpacity(
                opacity: !_isVideoPlaying || _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedFile(VaultedFile file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 100,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            file.originalName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview not available for this file type',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontFamily: 'ProductSans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(VaultedFile file) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.originalName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'ProductSans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_currentIndex + 1} of ${widget.files.length}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                file.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: file.isFavorite ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showFileInfo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(VaultedFile file) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video progress bar
            if (file.isVideo && _isVideoInitialized && _videoController != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: AppColors.accent,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: _currentIndex > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                // Slideshow (only for images)
                if (widget.files.where((f) => f.isImage).length > 1)
                  IconButton(
                    icon: Icon(
                      _isSlideshow ? Icons.stop : Icons.slideshow,
                      color: Colors.white,
                    ),
                    onPressed: _showSlideshowSettings,
                  ),
                // Share placeholder
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    ToastUtils.showInfo('Share coming soon');
                  },
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _confirmDelete(file),
                ),
                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: _currentIndex < widget.files.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(VaultedFile file) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Delete File',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${file.originalName}"?',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(vaultNotifierProvider.notifier)
                  .deleteFiles([file.id]);
              if (success) {
                ToastUtils.showSuccess('File deleted');
                if (widget.files.length == 1) {
                  if (mounted) Navigator.pop(context);
                } else {
                  // Remove from list and update
                  setState(() {
                    widget.files.remove(file);
                    if (_currentIndex >= widget.files.length) {
                      _currentIndex = widget.files.length - 1;
                    }
                  });
                }
              }
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
}
