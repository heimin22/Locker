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

  /// Import images from gallery (multiple selection) and optionally delete from gallery
  Future<ImportResult> importImagesFromGallery({
    bool deleteOriginals = true, // Default to true for hiding files
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Request permission
      final hasPermission = await _permissionService.requestPhotosPermission();
      if (!hasPermission) {
        return ImportResult(
          success: false,
          error: 'Photo library permission denied',
          importedFiles: [],
        );
      }

      // Pick multiple images
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

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      final originalPaths = <String>[];

      for (final image in images) {
        final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        filesToVault.add(FileToVault(
          sourcePath: image.path,
          originalName: image.name,
          type: VaultedFileType.image,
          mimeType: mimeType,
        ));
        originalPaths.add(image.path);
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false, // We'll handle deletion separately
        onProgress: onProgress,
      );

      // Delete originals from gallery if requested and import was successful
      if (deleteOriginals && imported.isNotEmpty) {
        await _deleteFromGallery(originalPaths);
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} image(s)',
        deletedOriginals: deleteOriginals,
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

  /// Import videos from gallery (multiple selection) and optionally delete from gallery
  Future<ImportResult> importVideosFromGallery({
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Request permission
      final hasPermission = await _permissionService.requestVideosPermission();
      if (!hasPermission) {
        return ImportResult(
          success: false,
          error: 'Video library permission denied',
          importedFiles: [],
        );
      }

      // Pick video - use file_picker for multiple selection
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

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      final originalPaths = <String>[];

      for (final file in result.files) {
        if (file.path == null) continue;

        final mimeType = lookupMimeType(file.path!) ?? 'video/mp4';
        filesToVault.add(FileToVault(
          sourcePath: file.path!,
          originalName: file.name,
          type: VaultedFileType.video,
          mimeType: mimeType,
        ));
        originalPaths.add(file.path!);
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete originals from gallery if requested
      if (deleteOriginals && imported.isNotEmpty) {
        await _deleteFromGallery(originalPaths);
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} video(s)',
        deletedOriginals: deleteOriginals,
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

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      final originalPaths = <String>[];

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
        originalPaths.add(file.path!);
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
        deletedOriginals: deleteOriginals,
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

      // Convert to FileToVault list with auto-detected types
      final filesToVault = <FileToVault>[];
      final originalPaths = <String>[];

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
        originalPaths.add(file.path!);
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete originals if requested
      if (deleteOriginals && imported.isNotEmpty) {
        // Check if any are media files that need gallery deletion
        final mediaFiles = originalPaths.where((p) {
          final ext = p.split('.').last.toLowerCase();
          return supportedImageExtensions.contains(ext) ||
              supportedVideoExtensions.contains(ext);
        }).toList();

        final otherFiles = originalPaths.where((p) {
          final ext = p.split('.').last.toLowerCase();
          return !supportedImageExtensions.contains(ext) &&
              !supportedVideoExtensions.contains(ext);
        }).toList();

        if (mediaFiles.isNotEmpty) {
          await _deleteFromGallery(mediaFiles);
        }
        if (otherFiles.isNotEmpty) {
          await _deleteFiles(otherFiles);
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
      final permissions = await _permissionService.requestAllMediaPermissions();
      if (!permissions.mediaGranted) {
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

      // Convert to FileToVault list
      final filesToVault = <FileToVault>[];
      final originalPaths = <String>[];

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
        originalPaths.add(file.path!);
      }

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: onProgress,
      );

      // Delete from gallery if requested
      if (deleteOriginals && imported.isNotEmpty) {
        await _deleteFromGallery(originalPaths);
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} media file(s)',
        deletedOriginals: deleteOriginals,
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

  /// Delete files from the device gallery using photo_manager
  Future<void> _deleteFromGallery(List<String> paths) async {
    try {
      // Request permission to delete
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        debugPrint('No permission to delete from gallery');
        return;
      }

      // Get all assets
      final albums = await PhotoManager.getAssetPathList(type: RequestType.all);
      if (albums.isEmpty) return;

      for (final path in paths) {
        try {
          // Find the asset by path
          final file = File(path);
          if (!await file.exists()) continue;

          // Try to find and delete the asset
          for (final album in albums) {
            final assets = await album.getAssetListRange(start: 0, end: 10000);
            for (final asset in assets) {
              final assetFile = await asset.file;
              if (assetFile?.path == path) {
                // Delete the asset
                final result =
                    await PhotoManager.editor.deleteWithIds([asset.id]);
                debugPrint('Deleted asset ${asset.id}: $result');
                break;
              }
            }
          }

          // Also try direct file deletion as fallback
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting file from gallery: $path - $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _deleteFromGallery: $e');
    }
  }

  /// Delete files directly (for non-gallery files)
  Future<void> _deleteFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
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
