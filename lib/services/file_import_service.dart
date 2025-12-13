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

      // Check if we have all files access for deletion
      final hasAllFilesAccess = await _permissionService.hasAllFilesAccess();
      if (deleteOriginals && !hasAllFilesAccess) {
        debugPrint(
            '[FileImport] Warning: All Files Access not granted. Original files may not be deleted from gallery.');
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

      debugPrint('[FileImport] Selected ${images.length} images for import');

      // Track assets to delete BEFORE importing (so we can find them by filename)
      List<AssetEntity> assetsToDelete = [];
      if (deleteOriginals) {
        final fileNames = images.map((i) => i.name).toList();
        debugPrint(
            '[FileImport] Looking for assets to delete with names: $fileNames');
        assetsToDelete =
            await _findMatchingAssets(fileNames, RequestType.image);
        debugPrint(
            '[FileImport] Found ${assetsToDelete.length} matching assets in gallery');
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
        deleteOriginals: false, // We handle deletion via PhotoManager
        onProgress: onProgress,
      );

      debugPrint('[FileImport] Imported ${imported.length} files to vault');

      // Delete originals from gallery if requested and import was successful
      bool deletedFromGallery = false;
      if (deleteOriginals && imported.isNotEmpty && assetsToDelete.isNotEmpty) {
        debugPrint(
            '[FileImport] Attempting to delete ${assetsToDelete.length} assets from gallery');
        deletedFromGallery = await _deleteAssetsFromGallery(assetsToDelete);
        debugPrint('[FileImport] Gallery deletion result: $deletedFromGallery');
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} image(s)',
        deletedOriginals: deletedFromGallery,
      );
    } catch (e) {
      debugPrint('[FileImport] Error importing images from gallery: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import images: $e',
        importedFiles: [],
      );
    }
  }

  /// Import media directly from AssetEntity objects (from custom media picker)
  /// This is the preferred method as it gives us direct access to the original files
  Future<ImportResult> importFromAssets({
    required List<AssetEntity> assets,
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    if (assets.isEmpty) {
      return ImportResult(
        success: true,
        importedFiles: [],
        message: 'No assets selected',
      );
    }

    try {
      debugPrint('[FileImport] Importing ${assets.length} assets directly');

      // Check if we have all files access for deletion
      final hasAllFilesAccess = await _permissionService.hasAllFilesAccess();
      if (deleteOriginals && !hasAllFilesAccess) {
        debugPrint(
            '[FileImport] Warning: All Files Access not granted. Original files may not be deleted from gallery.');
      }

      final filesToVault = <FileToVault>[];
      final validAssets = <AssetEntity>[];
      int processed = 0;

      for (final asset in assets) {
        try {
          // Get the actual file from the asset
          final file = await asset.file;
          if (file == null) {
            debugPrint(
                '[FileImport] Could not get file for asset: ${asset.title}');
            continue;
          }

          final filePath = file.path;
          final fileName =
              asset.title ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

          // Determine file type
          VaultedFileType type;
          String mimeType;

          if (asset.type == AssetType.video) {
            type = VaultedFileType.video;
            mimeType = lookupMimeType(filePath) ?? 'video/mp4';
          } else if (asset.type == AssetType.image) {
            type = VaultedFileType.image;
            mimeType = lookupMimeType(filePath) ?? 'image/jpeg';
          } else {
            type = VaultedFileType.other;
            mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
          }

          filesToVault.add(FileToVault(
            sourcePath: filePath,
            originalName: fileName,
            type: type,
            mimeType: mimeType,
          ));
          validAssets.add(asset);

          processed++;
          onProgress?.call(processed, assets.length);

          debugPrint(
              '[FileImport] Prepared asset for import: $fileName (path: $filePath)');
        } catch (e) {
          debugPrint('[FileImport] Error processing asset ${asset.title}: $e');
        }
      }

      if (filesToVault.isEmpty) {
        return ImportResult(
          success: false,
          error: 'Could not access any of the selected files',
          importedFiles: [],
        );
      }

      debugPrint('[FileImport] Adding ${filesToVault.length} files to vault');

      // Add to vault (copy files to vault directory)
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false, // We handle deletion via PhotoManager
        onProgress: (current, total) {
          onProgress?.call(assets.length + current, assets.length + total);
        },
      );

      debugPrint('[FileImport] Imported ${imported.length} files to vault');

      // Delete originals from gallery if requested and import was successful
      bool deletedFromGallery = false;
      if (deleteOriginals && imported.isNotEmpty && validAssets.isNotEmpty) {
        debugPrint(
            '[FileImport] Attempting to delete ${validAssets.length} assets from gallery');
        deletedFromGallery = await _deleteAssetsFromGallery(validAssets);

        if (deletedFromGallery) {
          debugPrint(
              '[FileImport] Successfully deleted ${validAssets.length} assets from gallery');
        } else {
          debugPrint(
              '[FileImport] Failed to delete assets from gallery. Files are imported but originals remain.');
        }
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message:
            'Imported ${imported.length} file(s)${deletedFromGallery ? " and removed from gallery" : ""}',
        deletedOriginals: deletedFromGallery,
      );
    } catch (e, stackTrace) {
      debugPrint('[FileImport] Error importing from assets: $e');
      debugPrint('[FileImport] Stack trace: $stackTrace');
      return ImportResult(
        success: false,
        error: 'Failed to import files: $e',
        importedFiles: [],
      );
    }
  }

  /// Unhide files from vault - restores them back to the device gallery
  Future<UnhideResult> unhideFiles({
    required List<String> fileIds,
    bool removeFromVault = true,
    Function(int current, int total)? onProgress,
  }) async {
    if (fileIds.isEmpty) {
      return UnhideResult(
        success: true,
        unhiddenCount: 0,
        message: 'No files selected',
      );
    }

    try {
      debugPrint('[FileImport] Unhiding ${fileIds.length} files');

      // Check if we have all files access
      final hasAllFilesAccess = await _permissionService.hasAllFilesAccess();
      if (!hasAllFilesAccess) {
        debugPrint(
            '[FileImport] Warning: All Files Access not granted. Unhiding may fail.');
      }

      // Get the destination directory (DCIM/Restored)
      final dcimDir = Directory('/storage/emulated/0/DCIM/Restored');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }

      int successCount = 0;
      int errorCount = 0;
      final List<String> restoredPaths = [];

      for (int i = 0; i < fileIds.length; i++) {
        try {
          final fileId = fileIds[i];
          final vaultedFile = await _vaultService.getFileById(fileId);

          if (vaultedFile == null) {
            debugPrint('[FileImport] File not found in vault: $fileId');
            errorCount++;
            continue;
          }

          // Determine destination path with original filename
          String destinationPath =
              '${dcimDir.path}/${vaultedFile.originalName}';

          // Handle duplicate filenames
          int counter = 1;
          while (await File(destinationPath).exists()) {
            final extension = vaultedFile.extension;
            final nameWithoutExt =
                vaultedFile.originalName.replaceAll('.$extension', '');
            destinationPath =
                '${dcimDir.path}/${nameWithoutExt}_$counter.$extension';
            counter++;
          }

          // Export the file from vault
          final exportedFile =
              await _vaultService.exportFile(fileId, destinationPath);

          if (exportedFile != null && await exportedFile.exists()) {
            debugPrint('[FileImport] Exported file to: $destinationPath');

            // Notify MediaStore to scan the new file so it appears in gallery
            await _notifyMediaStore(destinationPath);

            restoredPaths.add(destinationPath);
            successCount++;

            // Remove from vault if requested
            if (removeFromVault) {
              await _vaultService.removeFile(fileId);
              debugPrint('[FileImport] Removed file from vault: $fileId');
            }
          } else {
            debugPrint(
                '[FileImport] Failed to export file: ${vaultedFile.originalName}');
            errorCount++;
          }

          onProgress?.call(i + 1, fileIds.length);
        } catch (e) {
          debugPrint('[FileImport] Error unhiding file: $e');
          errorCount++;
        }
      }

      final message = successCount > 0
          ? 'Restored $successCount file(s) to gallery${errorCount > 0 ? ' ($errorCount failed)' : ''}'
          : 'Failed to restore files';

      return UnhideResult(
        success: successCount > 0,
        unhiddenCount: successCount,
        errorCount: errorCount,
        restoredPaths: restoredPaths,
        message: message,
      );
    } catch (e, stackTrace) {
      debugPrint('[FileImport] Error unhiding files: $e');
      debugPrint('[FileImport] Stack trace: $stackTrace');
      return UnhideResult(
        success: false,
        unhiddenCount: 0,
        error: 'Failed to unhide files: $e',
      );
    }
  }

  /// Notify MediaStore to scan a file so it appears in the gallery
  Future<void> _notifyMediaStore(String filePath) async {
    try {
      // Use PhotoManager to notify the system about the new file
      // This makes the file appear in the device's gallery
      final file = File(filePath);
      if (await file.exists()) {
        // The saveImage/saveVideo methods register the file with MediaStore
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType(filePath) ?? '';

        if (mimeType.startsWith('image/')) {
          await PhotoManager.editor.saveImage(
            bytes,
            filename: filePath.split('/').last,
          );
          debugPrint(
              '[FileImport] Registered image with MediaStore: $filePath');
        } else if (mimeType.startsWith('video/')) {
          await PhotoManager.editor.saveVideo(
            file,
            title: filePath.split('/').last,
          );
          debugPrint(
              '[FileImport] Registered video with MediaStore: $filePath');
        }
        // For other file types, they should still be accessible via file manager
      }
    } catch (e) {
      debugPrint('[FileImport] Error notifying MediaStore: $e');
      // Even if MediaStore notification fails, the file is still restored to DCIM
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

      // Check if we have all files access for deletion
      final hasAllFilesAccess = await _permissionService.hasAllFilesAccess();
      if (deleteOriginals && !hasAllFilesAccess) {
        debugPrint(
            '[FileImport] Warning: All Files Access not granted. Original videos may not be deleted from gallery.');
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

      debugPrint(
          '[FileImport] Selected ${result.files.length} videos for import');

      // Track assets to delete BEFORE importing
      List<AssetEntity> assetsToDelete = [];
      if (deleteOriginals) {
        final fileNames = result.files.map((f) => f.name).toList();
        debugPrint(
            '[FileImport] Looking for video assets to delete with names: $fileNames');
        assetsToDelete =
            await _findMatchingAssets(fileNames, RequestType.video);
        debugPrint(
            '[FileImport] Found ${assetsToDelete.length} matching video assets in gallery');
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
        deleteOriginals: false, // We handle deletion via PhotoManager
        onProgress: onProgress,
      );

      debugPrint('[FileImport] Imported ${imported.length} videos to vault');

      // Delete originals from gallery if requested and import was successful
      bool deletedFromGallery = false;
      if (deleteOriginals && imported.isNotEmpty && assetsToDelete.isNotEmpty) {
        debugPrint(
            '[FileImport] Attempting to delete ${assetsToDelete.length} video assets from gallery');
        deletedFromGallery = await _deleteAssetsFromGallery(assetsToDelete);
        debugPrint('[FileImport] Gallery deletion result: $deletedFromGallery');
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} video(s)',
        deletedOriginals: deletedFromGallery,
      );
    } catch (e) {
      debugPrint('[FileImport] Error importing videos from gallery: $e');
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

  /// Import documents from file paths (from custom document picker)
  /// This is the preferred method for the custom document picker
  Future<ImportResult> importFromDocumentFiles({
    required List<String> filePaths,
    bool deleteOriginals = true,
    Function(int current, int total)? onProgress,
  }) async {
    if (filePaths.isEmpty) {
      return ImportResult(
        success: true,
        importedFiles: [],
        message: 'No documents selected',
      );
    }

    try {
      debugPrint(
          '[FileImport] Importing ${filePaths.length} documents directly');

      final filesToVault = <FileToVault>[];
      final pathsToDelete = <String>[];
      int processed = 0;

      for (final path in filePaths) {
        try {
          final file = File(path);
          if (!await file.exists()) {
            debugPrint('[FileImport] File does not exist: $path');
            continue;
          }

          final fileName = path.split('/').last;
          final mimeType = lookupMimeType(path) ?? 'application/octet-stream';

          filesToVault.add(FileToVault(
            sourcePath: path,
            originalName: fileName,
            type: VaultedFileType.document,
            mimeType: mimeType,
          ));

          pathsToDelete.add(path);

          processed++;
          onProgress?.call(processed, filePaths.length);

          debugPrint('[FileImport] Prepared document for import: $fileName');
        } catch (e) {
          debugPrint('[FileImport] Error processing document $path: $e');
        }
      }

      if (filesToVault.isEmpty) {
        return ImportResult(
          success: false,
          error: 'Could not access any of the selected files',
          importedFiles: [],
        );
      }

      debugPrint(
          '[FileImport] Adding ${filesToVault.length} documents to vault');

      // Add to vault
      final imported = await _vaultService.addFiles(
        files: filesToVault,
        deleteOriginals: false,
        onProgress: (current, total) {
          onProgress?.call(
              filePaths.length + current, filePaths.length + total);
        },
      );

      debugPrint('[FileImport] Imported ${imported.length} documents to vault');

      // Delete originals if requested
      bool deletedOriginals = false;
      if (deleteOriginals && imported.isNotEmpty && pathsToDelete.isNotEmpty) {
        debugPrint(
            '[FileImport] Deleting ${pathsToDelete.length} original documents');
        await _deleteFiles(pathsToDelete);
        deletedOriginals = true;
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message:
            'Imported ${imported.length} document(s)${deletedOriginals ? " and removed originals" : ""}',
        deletedOriginals: deletedOriginals,
      );
    } catch (e, stackTrace) {
      debugPrint('[FileImport] Error importing documents from files: $e');
      debugPrint('[FileImport] Stack trace: $stackTrace');
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

      // Check if we have all files access for deletion
      final hasAllFilesAccess = await _permissionService.hasAllFilesAccess();
      if (deleteOriginals && !hasAllFilesAccess) {
        debugPrint(
            '[FileImport] Warning: All Files Access not granted. Original media may not be deleted from gallery.');
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

      debugPrint(
          '[FileImport] Selected ${result.files.length} media files for import');

      // Track assets to delete BEFORE importing
      List<AssetEntity> assetsToDelete = [];
      if (deleteOriginals) {
        final fileNames = result.files.map((f) => f.name).toList();
        debugPrint(
            '[FileImport] Looking for media assets to delete with names: $fileNames');
        assetsToDelete =
            await _findMatchingAssets(fileNames, RequestType.common);
        debugPrint(
            '[FileImport] Found ${assetsToDelete.length} matching media assets in gallery');
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
        deleteOriginals: false, // We handle deletion via PhotoManager
        onProgress: onProgress,
      );

      debugPrint(
          '[FileImport] Imported ${imported.length} media files to vault');

      // Delete originals from gallery if requested and import was successful
      bool deletedFromGallery = false;
      if (deleteOriginals && imported.isNotEmpty && assetsToDelete.isNotEmpty) {
        debugPrint(
            '[FileImport] Attempting to delete ${assetsToDelete.length} media assets from gallery');
        deletedFromGallery = await _deleteAssetsFromGallery(assetsToDelete);
        debugPrint('[FileImport] Gallery deletion result: $deletedFromGallery');
      }

      return ImportResult(
        success: true,
        importedFiles: imported,
        message: 'Imported ${imported.length} media file(s)',
        deletedOriginals: deletedFromGallery,
      );
    } catch (e) {
      debugPrint('[FileImport] Error importing media: $e');
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
      debugPrint(
          '[FileImport] Finding matching assets for ${fileNames.length} files');

      // Get all albums
      final albums = await PhotoManager.getAssetPathList(type: type);
      debugPrint('[FileImport] Found ${albums.length} albums to search');

      if (albums.isEmpty) {
        debugPrint('[FileImport] No albums found, cannot match assets');
        return matchingAssets;
      }

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

      debugPrint('[FileImport] Looking for files matching: $fileNameSet');

      // Search through all albums
      int totalAssetsSearched = 0;
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

          totalAssetsSearched += assets.length;

          for (final asset in assets) {
            final title = asset.title?.toLowerCase() ?? '';
            final titleNoExt = title.contains('.')
                ? title.substring(0, title.lastIndexOf('.'))
                : title;
            if (fileNameSet.contains(title) ||
                fileNameSet.contains(titleNoExt)) {
              debugPrint(
                  '[FileImport] Found matching asset: ${asset.title} (id: ${asset.id})');
              matchingAssets.add(asset);
              // Remove from set to avoid duplicates
              fileNameSet.remove(title);
              fileNameSet.remove(titleNoExt);

              // If we found all files, return early
              if (fileNameSet.isEmpty) {
                debugPrint(
                    '[FileImport] Found all ${matchingAssets.length} matching assets');
                return matchingAssets;
              }
            }
          }
        }
      }

      debugPrint('[FileImport] Searched $totalAssetsSearched assets total');
      if (fileNameSet.isNotEmpty) {
        debugPrint('[FileImport] Could not find matches for: $fileNameSet');
      }
    } catch (e, stackTrace) {
      debugPrint('[FileImport] Error finding matching assets: $e');
      debugPrint('[FileImport] Stack trace: $stackTrace');
    }

    debugPrint(
        '[FileImport] Returning ${matchingAssets.length} matching assets');
    return matchingAssets;
  }

  /// Delete assets from gallery using PhotoManager
  Future<bool> _deleteAssetsFromGallery(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      debugPrint('[FileImport] No assets to delete');
      return true;
    }

    try {
      // Log asset details for debugging (avoid asset.file to prevent decode errors)
      for (final asset in assets) {
        debugPrint(
            '[FileImport] Deleting asset: ${asset.title} (id: ${asset.id})');
      }

      final ids = assets.map((a) => a.id).toList();
      debugPrint(
          '[FileImport] Calling PhotoManager.editor.deleteWithIds with ${ids.length} IDs');

      final result = await PhotoManager.editor.deleteWithIds(ids);

      debugPrint(
          '[FileImport] Delete result: ${result.length} assets deleted successfully');

      if (result.length < assets.length) {
        debugPrint(
            '[FileImport] Warning: Not all assets were deleted. Requested: ${assets.length}, Deleted: ${result.length}');
        debugPrint(
            '[FileImport] This may be due to missing "All Files Access" permission on Android 11+');
      }

      return result.isNotEmpty;
    } catch (e, stackTrace) {
      debugPrint('[FileImport] Error deleting assets from gallery: $e');
      debugPrint('[FileImport] Stack trace: $stackTrace');
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

/// Result of an unhide operation
class UnhideResult {
  final bool success;
  final int unhiddenCount;
  final int errorCount;
  final String? error;
  final String? message;
  final List<String> restoredPaths;

  const UnhideResult({
    required this.success,
    required this.unhiddenCount,
    this.errorCount = 0,
    this.error,
    this.message,
    this.restoredPaths = const [],
  });

  @override
  String toString() {
    if (success) {
      return 'UnhideResult: Success - ${message ?? "Unhidden $unhiddenCount file(s)"}';
    }
    return 'UnhideResult: Failed - $error';
  }
}
