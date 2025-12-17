import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
  double _playbackSpeed = 1.0;
  bool _isLooping = false;
  bool _isMuted = false;

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

      // Apply current settings
      await _videoController!.setLooping(_isLooping);
      await _videoController!.setPlaybackSpeed(_playbackSpeed);
      await _videoController!.setVolume(_isMuted ? 0.0 : 1.0);

      // Add listener to update UI for progress
      _videoController!.addListener(() {
        if (mounted) setState(() {});
      });

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

  void _seekVideo(Duration position) {
    if (_videoController == null || !_isVideoInitialized) return;
    _videoController!.seekTo(position);
  }

  void _skipForward() {
    if (_videoController == null || !_isVideoInitialized) return;
    final newPos =
        _videoController!.value.position + const Duration(seconds: 10);
    final duration = _videoController!.value.duration;
    _seekVideo(newPos > duration ? duration : newPos);
  }

  void _skipBackward() {
    if (_videoController == null || !_isVideoInitialized) return;
    final newPos =
        _videoController!.value.position - const Duration(seconds: 10);
    _seekVideo(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _showVideoSettings() {
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
              'Playback Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
                fontFamily: 'ProductSans',
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingRow(
              'Playback Speed',
              DropdownButton<double>(
                value: _playbackSpeed,
                dropdownColor: AppColors.lightSurface,
                underline: Container(),
                icon: const Icon(Icons.speed, color: AppColors.accent),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _playbackSpeed = value;
                      _videoController?.setPlaybackSpeed(value);
                    });
                    Navigator.pop(context);
                  }
                },
                items: [0.5, 1.0, 1.5, 2.0].map((speed) {
                  return DropdownMenuItem(
                    value: speed,
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            _buildSwitchSetting(
              'Loop Video',
              _isLooping,
              (value) {
                setState(() {
                  _isLooping = value;
                  _videoController?.setLooping(value);
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            _buildSwitchSetting(
              'Mute Audio',
              _isMuted,
              (value) {
                setState(() {
                  _isMuted = value;
                  _videoController?.setVolume(value ? 0.0 : 1.0);
                });
                Navigator.pop(context);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.lightTextPrimary,
              fontFamily: 'ProductSans',
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
      String label, bool value, Function(bool) onChanged) {
    return _buildSettingRow(
      label,
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.accent,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
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

  void _showExportOptions(VaultedFile file) {
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
                    'Export Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextPrimary,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.download_outlined,
                          color: AppColors.accent),
                    ),
                    title: const Text('Export to Downloads',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('Save file to Downloads folder',
                        style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12,
                            color: AppColors.lightTextSecondary)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _exportToDownloads(file);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Future<void> _exportToDownloads(VaultedFile file) async {
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
            child: FutureBuilder<bool>(
              future: File(file.vaultPath).exists(),
              builder: (context, snapshot) {
                if (snapshot.data != true) {
                  return _buildImageErrorPlaceholder(file);
                }
                return Image.file(
                  File(file.vaultPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error decoding image file: $error');
                    return _buildImageErrorPlaceholder(file);
                  },
                );
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
            // Main Controls Overlay
            if (_showControls)
              Container(
                color: Colors.black26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10, size: 36),
                      color: Colors.white,
                      onPressed: _skipBackward,
                    ),
                    GestureDetector(
                      onTap: _toggleVideoPlayback,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10, size: 36),
                      color: Colors.white,
                      onPressed: _skipForward,
                    ),
                  ],
                ),
              ),
            // Tap area needed to toggle controls
            if (!_showControls)
              GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
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
    if (file.isVideo) return _buildVideoBottomControls(file);
    return _buildImageBottomControls(file);
  }

  Widget _buildVideoBottomControls(VaultedFile file) {
    final position = _videoController?.value.position ?? Duration.zero;
    final duration = _videoController?.value.duration ?? Duration.zero;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          top: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black87,
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar and Time
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppColors.accent,
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: Colors.white24,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14.0),
                    ),
                    child: Slider(
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, duration.inMilliseconds.toDouble()),
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _seekVideo(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isLooping ? Icons.repeat_one : Icons.repeat,
                    color: _isLooping ? AppColors.accent : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLooping = !_isLooping;
                      _videoController?.setLooping(_isLooping);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: _currentIndex > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    _isVideoPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: _toggleVideoPlayback,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: _currentIndex < widget.files.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  onPressed: _showVideoSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBottomControls(VaultedFile file) {
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
                // Share/Export
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _showExportOptions(file),
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
