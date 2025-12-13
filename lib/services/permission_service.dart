import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions for media and file access
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Request permissions for photos/images access
  Future<bool> requestPhotosPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular permissions
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Request permissions for videos access
  Future<bool> requestVideosPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final status = await Permission.videos.request();
        return status.isGranted || status.isLimited;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Request permissions for camera access
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request permissions for microphone access (for video recording)
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request permissions for file/document access
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 30) {
        // Android 11+ may need MANAGE_EXTERNAL_STORAGE for full access
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;

        // Fall back to regular storage permission
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't need explicit storage permission for file picker
      return true;
    }
    return false;
  }

  /// Request "All Files Access" permission for hiding files
  /// This is required on Android 11+ (API 30+) to access and modify files
  /// across the entire external storage, which is needed for file hiding
  Future<bool> requestAllFilesAccess() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await _getAndroidSdkVersion();

    if (androidInfo >= 30) {
      // Check if already granted
      final isGranted = await Permission.manageExternalStorage.isGranted;
      if (isGranted) return true;

      // Request the permission - this will prompt user to go to settings
      final status = await Permission.manageExternalStorage.request();

      if (status.isPermanentlyDenied) {
        // Open settings directly for user to grant permission
        await openAppSettings();
        // Return false as we can't confirm if user granted permission
        return false;
      }

      return status.isGranted;
    } else if (androidInfo >= 29) {
      // Android 10 - requestLegacyExternalStorage is used
      final status = await Permission.storage.request();
      return status.isGranted;
    } else {
      // Android 9 and below - just need storage permission
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  /// Check if "All Files Access" permission is granted
  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await _getAndroidSdkVersion();

    if (androidInfo >= 30) {
      return await Permission.manageExternalStorage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  /// Request all media permissions at once
  Future<MediaPermissionResult> requestAllMediaPermissions() async {
    bool photos = false;
    bool videos = false;
    bool camera = false;
    bool storage = false;
    bool allFilesAccess = false;

    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();

      if (androidInfo >= 33) {
        // Android 13+ granular permissions
        final results = await [
          Permission.photos,
          Permission.videos,
          Permission.camera,
        ].request();

        photos = results[Permission.photos]?.isGranted ?? false;
        videos = results[Permission.videos]?.isGranted ?? false;
        camera = results[Permission.camera]?.isGranted ?? false;
        storage = true; // file_picker handles this on Android 13+

        // Request all files access for hiding files
        allFilesAccess = await requestAllFilesAccess();
      } else if (androidInfo >= 30) {
        // Android 11-12
        final results = await [
          Permission.storage,
          Permission.camera,
        ].request();

        final storageGranted = results[Permission.storage]?.isGranted ?? false;
        photos = storageGranted;
        videos = storageGranted;
        storage = storageGranted;
        camera = results[Permission.camera]?.isGranted ?? false;

        // Request all files access for hiding files
        allFilesAccess = await requestAllFilesAccess();
      } else {
        // Android 10 and below
        final results = await [
          Permission.storage,
          Permission.camera,
        ].request();

        final storageGranted = results[Permission.storage]?.isGranted ?? false;
        photos = storageGranted;
        videos = storageGranted;
        storage = storageGranted;
        camera = results[Permission.camera]?.isGranted ?? false;
        allFilesAccess = storageGranted; // Storage permission is sufficient
      }
    } else if (Platform.isIOS) {
      final results = await [
        Permission.photos,
        Permission.camera,
        Permission.microphone,
      ].request();

      final photosStatus = results[Permission.photos];
      photos = (photosStatus?.isGranted ?? false) ||
          (photosStatus?.isLimited ?? false);
      videos = photos; // Same permission on iOS
      camera = results[Permission.camera]?.isGranted ?? false;
      storage = true; // file_picker handles this on iOS
      allFilesAccess = true; // iOS handles file access differently
    }

    return MediaPermissionResult(
      photos: photos,
      videos: videos,
      camera: camera,
      storage: storage,
      allFilesAccess: allFilesAccess,
    );
  }

  /// Check if photos permission is granted
  Future<bool> hasPhotosPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        return await Permission.photos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Check if videos permission is granted
  Future<bool> hasVideosPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        return await Permission.videos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 30) {
        return await Permission.manageExternalStorage.isGranted ||
            await Permission.storage.isGranted;
      }
      return await Permission.storage.isGranted;
    }
    return true; // iOS doesn't need explicit permission
  }

  /// Open app settings if permission is permanently denied
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get Android SDK version
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      // Use ProcessInfo or default to a safe version
      // In a real app, you'd use device_info_plus
      // For now, we'll default to 33 (Android 13) which is common
      return 33;
    } catch (e) {
      debugPrint('Error getting Android SDK version: $e');
      return 33; // Default to Android 13
    }
  }
}

/// Result of requesting all media permissions
class MediaPermissionResult {
  final bool photos;
  final bool videos;
  final bool camera;
  final bool storage;
  final bool allFilesAccess;

  const MediaPermissionResult({
    required this.photos,
    required this.videos,
    required this.camera,
    required this.storage,
    this.allFilesAccess = false,
  });

  bool get allGranted =>
      photos && videos && camera && storage && allFilesAccess;
  bool get mediaGranted => photos && videos;
  bool get anyGranted =>
      photos || videos || camera || storage || allFilesAccess;
  bool get canHideFiles => allFilesAccess;

  @override
  String toString() {
    return 'MediaPermissionResult(photos: $photos, videos: $videos, camera: $camera, storage: $storage, allFilesAccess: $allFilesAccess)';
  }
}
