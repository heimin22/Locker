import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/vaulted_file.dart';
import 'permission_service.dart';
import 'vault_service.dart';

/// Service for importing files from various sources
class FileImportService {
  FileImportService._();
  static final FileImportService instance = FileImportService._();

  final ImagePicker _imagePicker = ImagePicker();
  final PermissionService _permissionService = PermissionService.instance;
  final VaultService _vaultService = VaultService.instance;

  /// Import images from gallery using photo_manager for proper deletion support
  Future<ImportResult> importImagesFromGallery({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Request permission
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        return ImportResult(
          success: false,
          error: 'Photo library permission denied',
          importedFiles: [],
        );
      }

      // Pick multiple images using image_picker for UI
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 100,
      );

      if (images.isEmpty) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No images selected',
        );
      }

      // Get all image assets from gallery to find matching ones for deletion
      List<AssetEntity> assetsToDelete = [];
      final originalPaths = <String>[];
      if (deleteOriginals) {
        assetsToDelete = await _findMatchingAssets(
          images.map((i) => i.name).toList(),
          RequestType.image,
        );
        originalPaths.addAll(images.map((i) => i.path));
      }

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      for (final image in images) {
        final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        filesToVault.add(FileToVault(
          sourcePath: image.path,
          originalName: image.name,
          type: VaultedFileType.image,
          mimeType: mimeType,
        ));
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals:
            false, // We'll handle deletion separately via PhotoManager
        onProgress: onProgress,
      );

      // Delete originals from gallery if requested and import was successful
      if (deleteOriginals && imported.isNotEmpty) {
        var deleted = false;
        if (assetsToDelete.isNotEmpty) {
          deleted = await _deleteAssetsFromGallery(assetsToDelete);
        }
        // If gallery deletion failed or had no matches, try deleting by path
        if (!deleted && originalPaths.isNotEmpty) {
          await _deleteFiles(originalPaths);
        }
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} image(s)',
        deletedOriginals: deleteOriginals && assetsToDelete.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error importing images from gallery: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import images: $e',
        importedFiles: [],
      );
    }
  }

  /// Import videos from gallery with proper deletion support
  Future<ImportResult> importVideosFromGallery({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Request permission
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        return ImportResult(
          success: false,
          error: 'Video library permission denied',
          importedFiles: [],
        );
      }

      // Pick videos using file_picker for multiple selection
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No videos selected',
        );
      }

      // Get matching assets for deletion
      List<AssetEntity> assetsToDelete = [];
      final originalPaths = <String>[];
      if (deleteOriginals) {
        assetsToDelete = await _findMatchingAssets(
          result.files.map((f) => f.name).toList(),
          RequestType.video,
        );
        originalPaths.addAll(
            result.files.where((f) => f.path != null).map((f) => f.path!));
      }

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        final mimeType = lookupMimeType(file.path!) ?? 'video/mp4';
        filesToVault.add(FileToVault(
          sourcePath: file.path!,
          originalName: file.name,
          type: VaultedFileType.video,
          mimeType: mimeType,
        ));
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete originals from gallery
      if (deleteOriginals && imported.isNotEmpty) {
        var deleted = false;
        if (assetsToDelete.isNotEmpty) {
          deleted = await _deleteAssetsFromGallery(assetsToDelete);
        }
        if (!deleted && originalPaths.isNotEmpty) {
          await _deleteFiles(originalPaths);
        }
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} video(s)',
        deletedOriginals: deleteOriginals && assetsToDelete.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error importing videos from gallery: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import videos: $e',
        importedFiles: [],
      );
    }
  }

  /// Capture photo from camera
  Future<ImportResult> capturePhotoFromCamera() async {
    try {
      // Request camera permission
      final hasPermission = await _permissionService.requestCameraPermission();
      if (!hasPermission) {
        return ImportResult(
          success: false,
          error: 'Camera permission denied',
          importedFiles: [],
        );
      }

      // Capture photo
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (image == null) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No photo captured',
        );
      }

      final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
      final imported = await _vaultService.addFile(
        sourcePath: image.path,
        originalName: image.name,
        type: VaultedFileType.image,
        mimeType: mimeType,
        deleteOriginal: true, // Camera captures are temporary
      );

      if (imported == null) {
        return ImportResult(
          success: false,
          error: 'Failed to save photo to vault',
          importedFiles: [],
        );
      }

      return ImportResult(
        success: true,
        importedFiles: [imported],
        message: 'Photo captured and saved',
        deletedOriginals: true,
      );
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return ImportResult(
        success: false,
        error: 'Failed to capture photo: $e',
        importedFiles: [],
      );
    }
  }

  /// Record video from camera
  Future<ImportResult> recordVideoFromCamera({
    Duration? maxDuration,
  }) async {
    try {
      // Request permissions
      final hasCamera = await _permissionService.requestCameraPermission();
      final hasMic = await _permissionService.requestMicrophonePermission();

      if (!hasCamera) {
        return ImportResult(
          success: false,
          error: 'Camera permission denied',
          importedFiles: [],
        );
      }

      if (!hasMic) {
        return ImportResult(
          success: false,
          error: 'Microphone permission denied',
          importedFiles: [],
        );
      }

      // Record video
      final video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration ?? const Duration(minutes: 10),
      );

      if (video == null) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No video recorded',
        );
      }

      final mimeType = lookupMimeType(video.path) ?? 'video/mp4';
      final imported = await _vaultService.addFile(
        sourcePath: video.path,
        originalName: video.name,
        type: VaultedFileType.video,
        mimeType: mimeType,
        deleteOriginal: true, // Camera captures are temporary
      );

      if (imported == null) {
        return ImportResult(
          success: false,
          error: 'Failed to save video to vault',
          importedFiles: [],
        );
      }

      return ImportResult(
        success: true,
        importedFiles: [imported],
        message: 'Video recorded and saved',
        deletedOriginals: true,
      );
    } catch (e) {
      debugPrint('Error recording video: $e');
      return ImportResult(
        success: false,
        error: 'Failed to record video: $e',
        importedFiles: [],
      );
    }
  }

  /// Import documents from file manager
  Future<ImportResult> importDocuments({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Pick documents
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedDocumentExtensions,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No documents selected',
        );
      }

      // Store original paths for deletion
      final originalPaths = <String>[];

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        final mimeType =
            lookupMimeType(file.path!) ?? 'application/octet-stream';
        filesToVault.add(FileToVault(
          sourcePath: file.path!,
          originalName: file.name,
          type: VaultedFileType.document,
          mimeType: mimeType,
        ));

        // Try to get the original path (not cache path)
        final originalPath = await _getOriginalPath(file.path!, file.name);
        if (originalPath != null) {
          originalPaths.add(originalPath);
        }
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete original files if requested
      if (deleteOriginals && imported.isNotEmpty) {
        await _deleteFiles(originalPaths);
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} document(s)',
        deletedOriginals: deleteOriginals && originalPaths.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error importing documents: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import documents: $e',
        importedFiles: [],
      );
    }
  }

  /// Import any files from file manager
  Future<ImportResult> importAnyFiles({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Pick any files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No files selected',
        );
      }

      // Store info for deletion
      final mediaFileNames = <String>[];
      final nonMediaPaths = <String>[];

      // Convert to FileToVault list with auto-detected types
      final filesToVault = <FileToVault>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        final mimeType =
            lookupMimeType(file.path!) ?? 'application/octet-stream';
        final extension = file.extension ?? '';
        final type = getFileTypeFromExtension(extension);

        filesToVault.add(FileToVault(
          sourcePath: file.path!,
          originalName: file.name,
          type: type,
          mimeType: mimeType,
        ));

        // Categorize for deletion
        if (type == VaultedFileType.image || type == VaultedFileType.video) {
          mediaFileNames.add(file.name);
        } else {
          final originalPath = await _getOriginalPath(file.path!, file.name);
          if (originalPath != null) {
            nonMediaPaths.add(originalPath);
          } else if (await File(file.path!).exists()) {
            // Fall back to the picker path when we can access the file directly
            nonMediaPaths.add(file.path!);
          }
        }
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete originals if requested
      if (deleteOriginals && imported.isNotEmpty) {
        // Delete media files via PhotoManager
        if (mediaFileNames.isNotEmpty) {
          final assets = await _findMatchingAssets(
            mediaFileNames,
            RequestType.common,
          );
          await _deleteAssetsFromGallery(assets);
        }
        // Delete non-media files directly
        if (nonMediaPaths.isNotEmpty) {
          await _deleteFiles(nonMediaPaths);
        }
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} file(s)',
        deletedOriginals: deleteOriginals,
      );
    } catch (e) {
      debugPrint('Error importing files: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import files: $e',
        importedFiles: [],
      );
    }
  }

  /// Import media (images and videos) from gallery
  Future<ImportResult> importMediaFromGallery({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Request permissions
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        return ImportResult(
          success: false,
          error: 'Media permission denied',
          importedFiles: [],
        );
      }

      // Pick media files (images and videos)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: true,
          importedFiles: [],
          message: 'No media selected',
        );
      }

      // Get matching assets for deletion
      List<AssetEntity> assetsToDelete = [];
      final originalPaths = <String>[];
      if (deleteOriginals) {
        assetsToDelete = await _findMatchingAssets(
          result.files.map((f) => f.name).toList(),
          RequestType.common,
        );
        originalPaths.addAll(
            result.files.where((f) => f.path != null).map((f) => f.path!));
      }

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        final mimeType =
            lookupMimeType(file.path!) ?? 'application/octet-stream';
        final type = getFileTypeFromMime(mimeType);

        filesToVault.add(FileToVault(
          sourcePath: file.path!,
          originalName: file.name,
          type: type,
          mimeType: mimeType,
        ));
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete from gallery if requested
      if (deleteOriginals && imported.isNotEmpty) {
        var deleted = false;
        if (assetsToDelete.isNotEmpty) {
          deleted = await _deleteAssetsFromGallery(assetsToDelete);
        }
        if (!deleted && originalPaths.isNotEmpty) {
          await _deleteFiles(originalPaths);
        }
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} media file(s)',
        deletedOriginals: deleteOriginals && assetsToDelete.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error importing media: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import media: $e',
        importedFiles: [],
      );
    }
  }

  /// Find matching assets in the gallery by filename
  Future<List<AssetEntity>> _findMatchingAssets(
    List<String> fileNames,
    RequestType type,
  ) async {
    final matchingAssets = <AssetEntity>[];

    try {
      // Get all albums
      final albums = await PhotoManager.getAssetPathList(type: type);
      if (albums.isEmpty) return matchingAssets;

      // Convert filenames to a set for faster lookup (with and without extension)
      final fileNameSet = <String>{};
      for (final name in fileNames) {
        final lower = name.toLowerCase();
        fileNameSet.add(lower);
        final dotIndex = lower.lastIndexOf('.');
        if (dotIndex > 0) {
          fileNameSet.add(lower.substring(0, dotIndex));
        }
      }

      // Search through all albums
      for (final album in albums) {
        final count = await album.assetCountAsync;
        if (count == 0) continue;

        // Get assets in batches
        const batchSize = 100;
        for (int i = 0; i < count; i += batchSize) {
          final assets = await album.getAssetListRange(
            start: i,
            end: (i + batchSize).clamp(0, count),
          );

          for (final asset in assets) {
            final title = asset.title?.toLowerCase() ?? '';
            final titleNoExt = title.contains('.')
                ? title.substring(0, title.lastIndexOf('.'))
                : title;
            if (fileNameSet.contains(title) ||
                fileNameSet.contains(titleNoExt)) {
              matchingAssets.add(asset);
              // Remove from set to avoid duplicates
              fileNameSet.remove(title);
              fileNameSet.remove(titleNoExt);

              // If we found all files, return early
              if (fileNameSet.isEmpty) {
                return matchingAssets;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding matching assets: $e');
    }

    return matchingAssets;
  }

  /// Delete assets from gallery using PhotoManager
  Future<bool> _deleteAssetsFromGallery(List<AssetEntity> assets) async {
    if (assets.isEmpty) return true;

    try {
      final ids = assets.map((a) => a.id).toList();
      final result = await PhotoManager.editor.deleteWithIds(ids);
      debugPrint('Deleted ${result.length} assets from gallery');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error deleting assets from gallery: $e');
      return false;
    }
  }

  /// Try to get the original path from a cached/picked file path
  Future<String?> _getOriginalPath(String cachedPath, String fileName) async {
    // Common locations to check
    final possibleDirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/DCIM',
      '/sdcard/Download',
      '/sdcard/Documents',
    ];

    for (final dir in possibleDirs) {
      final possiblePath = '$dir/$fileName';
      if (await File(possiblePath).exists()) {
        return possiblePath;
      }
    }

    return null;
  }

  /// Delete files directly (for non-gallery files)
  Future<void> _deleteFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted file: $path');
        }
      } catch (e) {
        debugPrint('Error deleting file: $path - $e');
      }
    }
  }
}

/// Result of an import operation
class ImportResult {
  final bool success;
  final String? error;
  final String? message;
  final List<VaultedFile> importedFiles;
  final bool deletedOriginals;

  const ImportResult({
    required this.success,
    this.error,
    this.message,
    required this.importedFiles,
    this.deletedOriginals = false,
  });

  int get importedCount => importedFiles.length;

  @override
  String toString() {
    if (success) {
      return 'ImportResult: Success - ${message ?? "Imported $importedCount file(s)"}${deletedOriginals ? " (originals deleted)" : ""}';
    }
    return 'ImportResult: Failed - $error';
  }
}
