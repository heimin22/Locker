import 'dart:convert';

/// Model representing an album/folder for organizing files
class Album {
  final String id;
  final String name;
  final String? description;
  final String? coverImageId; // ID of the VaultedFile to use as cover
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> fileIds; // List of VaultedFile IDs in this album
  final bool isDefault; // Default albums like "All", "Favorites", etc.
  final AlbumType type;
  final int sortOrder; // For custom ordering of albums
  final Map<String, dynamic>? metadata;

  const Album({
    required this.id,
    required this.name,
    this.description,
    this.coverImageId,
    required this.createdAt,
    required this.updatedAt,
    this.fileIds = const [],
    this.isDefault = false,
    this.type = AlbumType.custom,
    this.sortOrder = 0,
    this.metadata,
  });

  /// Get file count
  int get fileCount => fileIds.length;

  /// Check if album is empty
  bool get isEmpty => fileIds.isEmpty;

  /// Check if album contains a specific file
  bool containsFile(String fileId) => fileIds.contains(fileId);

  /// Create a copy with updated fields
  Album copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImageId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? fileIds,
    bool? isDefault,
    AlbumType? type,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageId: coverImageId ?? this.coverImageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileIds: fileIds ?? List.from(this.fileIds),
      isDefault: isDefault ?? this.isDefault,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add a file to the album
  Album addFile(String fileId) {
    if (fileIds.contains(fileId)) return this;
    return copyWith(
      fileIds: [...fileIds, fileId],
      updatedAt: DateTime.now(),
    );
  }

  /// Add multiple files to the album
  Album addFiles(List<String> ids) {
    final newIds = ids.where((id) => !fileIds.contains(id)).toList();
    if (newIds.isEmpty) return this;
    return copyWith(
      fileIds: [...fileIds, ...newIds],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a file from the album
  Album removeFile(String fileId) {
    if (!fileIds.contains(fileId)) return this;
    return copyWith(
      fileIds: fileIds.where((id) => id != fileId).toList(),
      updatedAt: DateTime.now(),
      coverImageId: coverImageId == fileId ? null : coverImageId,
    );
  }

  /// Remove multiple files from the album
  Album removeFiles(List<String> ids) {
    final idsSet = ids.toSet();
    final newFileIds = fileIds.where((id) => !idsSet.contains(id)).toList();
    if (newFileIds.length == fileIds.length) return this;
    return copyWith(
      fileIds: newFileIds,
      updatedAt: DateTime.now(),
      coverImageId: idsSet.contains(coverImageId) ? null : coverImageId,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImageId': coverImageId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'fileIds': fileIds,
      'isDefault': isDefault,
      'type': type.name,
      'sortOrder': sortOrder,
      'metadata': metadata,
    };
  }

  /// Create from JSON map
  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverImageId: json['coverImageId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      fileIds: (json['fileIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isDefault: json['isDefault'] as bool? ?? false,
      type: AlbumType.fromString(json['type'] as String? ?? 'custom'),
      sortOrder: json['sortOrder'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory Album.fromJsonString(String jsonString) {
    return Album.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'Album(id: $id, name: $name, fileCount: $fileCount, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Types of albums
enum AlbumType {
  custom, // User-created album
  favorites, // Special favorites album
  recent, // Recently added/viewed
  screenshots, // Auto-detected screenshots
  camera, // Camera captures
  downloads, // Downloaded files
  shared; // Shared/received files

  String get displayName {
    switch (this) {
      case AlbumType.custom:
        return 'Album';
      case AlbumType.favorites:
        return 'Favorites';
      case AlbumType.recent:
        return 'Recent';
      case AlbumType.screenshots:
        return 'Screenshots';
      case AlbumType.camera:
        return 'Camera';
      case AlbumType.downloads:
        return 'Downloads';
      case AlbumType.shared:
        return 'Shared';
    }
  }

  static AlbumType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'favorites':
        return AlbumType.favorites;
      case 'recent':
        return AlbumType.recent;
      case 'screenshots':
        return AlbumType.screenshots;
      case 'camera':
        return AlbumType.camera;
      case 'downloads':
        return AlbumType.downloads;
      case 'shared':
        return AlbumType.shared;
      default:
        return AlbumType.custom;
    }
  }
}

/// Sorting options for files
enum SortOption {
  nameAsc,
  nameDesc,
  dateAddedNewest,
  dateAddedOldest,
  dateModifiedNewest,
  dateModifiedOldest,
  sizeSmallest,
  sizeLargest,
  typeAsc,
  typeDesc;

  String get displayName {
    switch (this) {
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.dateAddedNewest:
        return 'Date Added (Newest)';
      case SortOption.dateAddedOldest:
        return 'Date Added (Oldest)';
      case SortOption.dateModifiedNewest:
        return 'Date Modified (Newest)';
      case SortOption.dateModifiedOldest:
        return 'Date Modified (Oldest)';
      case SortOption.sizeSmallest:
        return 'Size (Smallest)';
      case SortOption.sizeLargest:
        return 'Size (Largest)';
      case SortOption.typeAsc:
        return 'Type (A-Z)';
      case SortOption.typeDesc:
        return 'Type (Z-A)';
    }
  }

  String get iconName {
    switch (this) {
      case SortOption.nameAsc:
      case SortOption.nameDesc:
        return 'sort_by_alpha';
      case SortOption.dateAddedNewest:
      case SortOption.dateAddedOldest:
      case SortOption.dateModifiedNewest:
      case SortOption.dateModifiedOldest:
        return 'date_range';
      case SortOption.sizeSmallest:
      case SortOption.sizeLargest:
        return 'storage';
      case SortOption.typeAsc:
      case SortOption.typeDesc:
        return 'category';
    }
  }
}
