import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/album.dart';
import '../models/vaulted_file.dart';
import '../providers/vault_providers.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';
import 'album_detail_screen.dart';

/// Screen for managing albums/folders
class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Albums',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
      ),
      body: albumsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: AppColors.lightTextTertiary),
              const SizedBox(height: 16),
              Text(
                'Failed to load albums',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(albumsNotifierProvider.notifier).loadAlbums(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (albums) => _buildAlbumsList(albums),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAlbumDialog,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Album',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsList(List<Album> albums) {
    if (albums.isEmpty) {
      return _buildEmptyState();
    }

    // Separate default and custom albums
    final defaultAlbums = albums.where((a) => a.isDefault).toList();
    final customAlbums = albums.where((a) => !a.isDefault).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(albumsNotifierProvider.notifier).loadAlbums();
      },
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (defaultAlbums.isNotEmpty) ...[
            _buildSectionHeader('Default Albums'),
            const SizedBox(height: 12),
            _buildAlbumsGrid(defaultAlbums),
            const SizedBox(height: 24),
          ],
          if (customAlbums.isNotEmpty) ...[
            _buildSectionHeader('My Albums'),
            const SizedBox(height: 12),
            _buildAlbumsGrid(customAlbums),
          ],
          if (customAlbums.isEmpty && defaultAlbums.isNotEmpty) ...[
            _buildSectionHeader('My Albums'),
            const SizedBox(height: 12),
            _buildCreateAlbumCard(),
          ],
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

  Widget _buildAlbumsGrid(List<Album> albums) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) => _buildAlbumCard(albums[index]),
    );
  }

  Widget _buildAlbumCard(Album album) {
    return GestureDetector(
      onTap: () => _openAlbum(album),
      onLongPress: album.isDefault ? null : () => _showAlbumOptions(album),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image or placeholder
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildAlbumCover(album),
              ),
            ),
            // Album info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getAlbumIcon(album.type),
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          album.name,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${album.fileCount} items',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: AppColors.lightTextTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCover(Album album) {
    if (album.coverImageId != null) {
      // Try to load cover image
      return FutureBuilder<VaultedFile?>(
        future: ref.read(vaultServiceProvider).getFileById(album.coverImageId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final file = snapshot.data!;
            if (file.isImage) {
              return Image.file(
                File(file.vaultPath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => _buildPlaceholderCover(album),
              );
            }
          }
          return _buildPlaceholderCover(album);
        },
      );
    }

    // Try to get first image from album
    if (album.fileIds.isNotEmpty) {
      return FutureBuilder<List<VaultedFile>>(
        future: ref.read(vaultServiceProvider).getFilesInAlbum(album.id),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final imageFiles = snapshot.data!.where((f) => f.isImage).toList();
            if (imageFiles.isNotEmpty) {
              return Image.file(
                File(imageFiles.first.vaultPath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => _buildPlaceholderCover(album),
              );
            }
          }
          return _buildPlaceholderCover(album);
        },
      );
    }

    return _buildPlaceholderCover(album);
  }

  Widget _buildPlaceholderCover(Album album) {
    final color = _getAlbumColor(album.type);
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          _getAlbumIcon(album.type),
          size: 48,
          color: color,
        ),
      ),
    );
  }

  IconData _getAlbumIcon(AlbumType type) {
    switch (type) {
      case AlbumType.custom:
        return Icons.folder_outlined;
      case AlbumType.favorites:
        return Icons.favorite_outline;
      case AlbumType.recent:
        return Icons.access_time;
      case AlbumType.screenshots:
        return Icons.screenshot_outlined;
      case AlbumType.camera:
        return Icons.camera_alt_outlined;
      case AlbumType.downloads:
        return Icons.download_outlined;
      case AlbumType.shared:
        return Icons.share_outlined;
    }
  }

  Color _getAlbumColor(AlbumType type) {
    switch (type) {
      case AlbumType.custom:
        return AppColors.accent;
      case AlbumType.favorites:
        return Colors.red;
      case AlbumType.recent:
        return Colors.orange;
      case AlbumType.screenshots:
        return Colors.purple;
      case AlbumType.camera:
        return Colors.teal;
      case AlbumType.downloads:
        return Colors.green;
      case AlbumType.shared:
        return Colors.blue;
    }
  }

  Widget _buildCreateAlbumCard() {
    return GestureDetector(
      onTap: _showCreateAlbumDialog,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.lightBackgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 40,
                color: AppColors.accent,
              ),
              const SizedBox(height: 8),
              Text(
                'Create Album',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
              color: AppColors.lightBackgroundSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 64,
              color: AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No albums yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create albums to organize your files',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateAlbumDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Album'),
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

  void _openAlbum(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(albumId: album.id),
      ),
    );
  }

  void _showAlbumOptions(Album album) {
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
                    album.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextPrimary,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildOptionTile(
                    icon: Icons.edit_outlined,
                    label: 'Rename Album',
                    onTap: () {
                      Navigator.pop(context);
                      _showRenameAlbumDialog(album);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.image_outlined,
                    label: 'Change Cover',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Implement change cover
                      ToastUtils.showInfo('Coming soon');
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    label: 'Delete Album',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteAlbumDialog(album);
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

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.lightTextPrimary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'ProductSans',
          color: color ?? AppColors.lightTextPrimary,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showCreateAlbumDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Create Album',
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
                labelText: 'Album Name',
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
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
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
              maxLines: 2,
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ToastUtils.showError('Please enter album name');
                return;
              }

              final album =
                  await ref.read(albumsNotifierProvider.notifier).createAlbum(
                        name: name,
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                      );

              if (!context.mounted) return;
              if (album != null) {
                Navigator.pop(context);
                ToastUtils.showSuccess('Album created');
              } else {
                ToastUtils.showError('Failed to create album');
              }
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
    );
  }

  void _showRenameAlbumDialog(Album album) {
    final nameController = TextEditingController(text: album.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Rename Album',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Album Name',
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
          autofocus: true,
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ToastUtils.showError('Please enter album name');
                return;
              }

              final updated = await ref
                  .read(albumsNotifierProvider.notifier)
                  .updateAlbum(album.copyWith(name: name));

              if (!context.mounted) return;
              if (updated != null) {
                Navigator.pop(context);
                ToastUtils.showSuccess('Album renamed');
              } else {
                ToastUtils.showError('Failed to rename album');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Rename',
              style: TextStyle(fontFamily: 'ProductSans'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlbumDialog(Album album) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        title: Text(
          'Delete Album',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${album.name}"? Files in this album will not be deleted.',
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
              final deleted = await ref
                  .read(albumsNotifierProvider.notifier)
                  .deleteAlbum(album.id);

              if (!context.mounted) return;
              Navigator.pop(context);
              if (deleted) {
                ToastUtils.showSuccess('Album deleted');
              } else {
                ToastUtils.showError('Failed to delete album');
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
