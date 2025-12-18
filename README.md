# Locker

Locker is a secure, private media vault application built with Flutter for Android. It provides a safe space to hide and protect your sensitive photos, videos, and documents from prying eyes, with multiple layers of security including biometric authentication, optional AES-256 encryption, and an auto-kill feature that removes the app from the recent apps list when you leave.

---

## Table of Contents

- [Features](#features)
- [Security](#security)
- [Requirements](#requirements)
- [Installation](#installation)
- [Building from Source](#building-from-source)
- [Usage](#usage)
- [File Support](#file-support)
- [Architecture](#architecture)
- [Permissions](#permissions)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Contact](#contact)

---

## Features

### Core Functionality

- **Media Vault**: Securely hide images, videos, and documents from your device gallery
- **Gallery Import**: Import media directly from your device gallery with the option to delete originals
- **Camera Integration**: Capture photos and videos directly into the vault
- **Document Support**: Store and view PDFs, Office documents (Word, Excel, PowerPoint), and text files
- **Custom Media Picker**: Built-in media picker with album browsing and multi-select support
- **Custom Document Picker**: File browser for selecting documents from device storage

### Organization

- **Albums**: Create custom albums to organize your hidden files
- **Tags**: Add color-coded tags to files for easy categorization and filtering
- **Favorites**: Mark files as favorites for quick access
- **Search**: Find files by name, tags, type, date, or other criteria
- **Sorting**: Multiple sorting options including date, name, size, and type

### Viewing

- **Image Viewer**: Full-screen image viewing with pinch-to-zoom and slideshow mode
- **Video Player**: Built-in video player with playback controls, speed adjustment, and loop options
- **Document Viewer**: Native PDF rendering and Office document conversion for viewing
- **File Export**: Export files to Downloads folder or open with external applications

### Security Features

- **PIN Authentication**: 6-digit PIN lock with secure storage
- **Password Authentication**: Traditional password protection option
- **Biometric Authentication**: Fingerprint and face recognition support
- **Optional Encryption**: AES-256-CBC/CTR encryption for stored files (off by default for performance)
- **Auto-Kill**: Automatically removes app from recent apps when leaving
- **Decoy Mode**: Set up a fake vault with a separate PIN to show if forced to unlock
- **Secure Delete**: Overwrite files before deletion to prevent recovery

---

## Security

### Authentication Methods

Locker supports three authentication methods:

1. **PIN**: A 6-digit numeric PIN
2. **Password**: An alphanumeric password of any length
3. **Biometrics**: Fingerprint or face recognition (requires PIN or password as backup)

### Encryption

When enabled, files are encrypted using AES-256 encryption:

- **Small files**: AES-256-CBC mode with in-memory processing
- **Large files**: AES-256-CTR mode with streaming encryption for memory efficiency

Encryption is disabled by default for performance reasons. Enable it in Settings for maximum security.

### Auto-Kill Feature

The auto-kill feature ensures the app is removed from the Android recent apps switcher when:

- The user presses the home button
- The user switches to another app
- The app goes into the background

This prevents others from seeing that the app was recently used.

### Decoy Mode

Decoy mode allows you to set up a fake vault with a different PIN. If someone forces you to unlock the app, enter the decoy PIN to show the fake vault instead of your real hidden files.

---

## Requirements

- **Android**: 6.0 (API level 23) or higher
- **Target SDK**: Android 14 (API level 34)
- **Minimum SDK**: Android 6.0 (API level 23)
- **Storage**: Sufficient space for your hidden files

---

## Installation

### From Release APK

1. Download the latest APK from the Releases page
2. Enable "Install from unknown sources" in your device settings
3. Install the APK
4. Launch and set up your authentication method

### From Source

See [Building from Source](#building-from-source) below.

---

## Building from Source

### Prerequisites

- Flutter SDK 3.4.4 or higher
- Dart SDK (included with Flutter)
- Android SDK with API level 34
- Java Development Kit (JDK) 17

### Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/heimin22/Locker.git
   cd Locker
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Generate launcher icons (optional):

   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. Build for Android:

   ```bash
   # Debug build
   flutter build apk --debug

   # Release build
   flutter build apk --release
   ```

5. Install on device:

   ```bash
   flutter install
   ```

### Running in Development

```bash
flutter run
```

---

## Usage

### First Launch

1. Launch the app for the first time
2. Choose your preferred authentication method (PIN, Password, or Biometrics)
3. Set up your credentials
4. Optionally configure settings like encryption and decoy mode

### Hiding Files

1. Tap the "Import" button or use the floating action button
2. Select the source:
   - **Images**: Import images from your gallery
   - **Videos**: Import videos from your gallery
   - **All Media**: Import both images and videos
   - **Camera**: Capture a new photo or video
   - **Documents**: Import documents from your device
3. Select the files you want to hide
4. Confirm the import - originals will be deleted from your gallery by default

### Viewing Files

- Tap any file to open it in the built-in viewer
- Use gestures to zoom and pan images
- Swipe left/right to navigate between files
- Tap the screen to show/hide controls

### Organizing Files

- **Albums**: Access from the drawer menu, create albums to group related files
- **Tags**: Long-press a file and select "Add Tag" to categorize
- **Favorites**: Tap the heart icon to mark as favorite

### Unhiding Files

1. Select files in the vault
2. Tap the "Unhide" action
3. Files will be restored to your device gallery (DCIM/Restored folder)

---

## File Support

### Images

- JPEG, PNG, GIF, WebP, BMP, HEIC

### Videos

- MP4, MOV, AVI, MKV, WebM, 3GP

### Documents

- PDF (native viewing)
- Microsoft Word (DOC, DOCX) - converted to PDF for viewingS
- Text files (TXT, MD, JSON, XML, CSV, LOG)

### Other Files

- ZIP, RAR, 7Z archives
- APK files
- Audio files (MP3, WAV, FLAC, AAC, OGG)
- Any other file type (stored but not previewable)

---

## Architecture

### Technology Stack

- **Framework**: Flutter 3.4.4+
- **State Management**: Riverpod
- **Storage**: Flutter Secure Storage for credentials and metadata
- **Encryption**: PointyCastle (AES-256)
- **Native Integration**: Kotlin for Android-specific features

### Project Structure

```
lib/
  main.dart                 # Application entry point
  models/                   # Data models
    album.dart              # Album and tag models
    document_file.dart      # Document file model
    vaulted_file.dart       # Vaulted file model
  providers/                # Riverpod state providers
    vault_providers.dart    # Vault state management
  screens/                  # UI screens
    albums_screen.dart
    album_detail_screen.dart
    camera_screen.dart
    document_picker_screen.dart
    document_viewer_screen.dart
    favorites_screen.dart
    gallery_vault_screen.dart
    home_screen.dart
    media_picker_screen.dart
    media_viewer_screen.dart
    tags_screen.dart
    ...
  services/                 # Business logic services
    auth_service.dart       # Authentication handling
    auto_kill_service.dart  # Auto-kill feature
    encryption_service.dart # File encryption
    file_import_service.dart # Import/export logic
    permission_service.dart # Permission handling
    vault_service.dart      # Core vault operations
  themes/                   # App theming
    app_colors.dart
  utils/                    # Utility classes
    toast_utils.dart
  widgets/                  # Reusable widgets
    permission_warning_banner.dart
    ...

android/
  app/src/main/kotlin/      # Native Kotlin code
    MainActivity.kt         # Auto-kill implementation
```

---

## Permissions

Locker requires the following Android permissions:

| Permission | Purpose |
|------------|---------|
| READ_EXTERNAL_STORAGE | Access files on device (Android 12 and below) |
| WRITE_EXTERNAL_STORAGE | Write files to device (Android 12 and below) |
| READ_MEDIA_IMAGES | Access images (Android 13+) |
| READ_MEDIA_VIDEO | Access videos (Android 13+) |
| MANAGE_EXTERNAL_STORAGE | Full file access for hiding/unhiding (Android 11+) |
| CAMERA | Capture photos and videos |
| RECORD_AUDIO | Record audio with video |
| USE_BIOMETRIC | Biometric authentication |

---

## Configuration

### Settings

Access settings from the drawer menu or security icon:

| Setting | Description | Default |
|---------|-------------|---------|
| Encryption | Enable AES-256 encryption for new files | Off |
| Secure Delete | Overwrite files before deletion | On |
| Default Sort | How files are sorted in the vault | Date Added (Newest) |
| Decoy Mode | Enable fake vault with separate PIN | Off |

### Changing Authentication

1. Open Settings from the drawer
2. Select "Security Settings"
3. Choose "Change PIN/Password" or toggle biometrics

---

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository
2. Create a feature branch:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Make your changes and commit:

   ```bash
   git commit -m "Add your feature description"
   ```

4. Push to your fork:

   ```bash
   git push origin feature/your-feature-name
   ```

5. Open a Pull Request

### Code Style

- Follow the Dart style guide
- Run `flutter analyze` before submitting
- Ensure all existing tests pass

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 ultraelectronica

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## Disclaimer

Locker is intended for personal privacy protection only. The developers are not responsible for any misuse of this application. Use responsibly and in accordance with applicable laws.

This application:

- Does not upload your files anywhere
- Does not collect any personal data
- Stores all data locally on your device
- Cannot recover files if you forget your PIN/password

---

## Contact

For questions, suggestions, or bug reports:

- Open an issue on GitHub
- Email: athrundiscinity@protonmail.com

---

## Acknowledgments

Built with the following open-source libraries:

- Flutter and Dart by Google
- Riverpod for state management
- PointyCastle for encryption
- photo_manager for media access
- pdfrx for PDF viewing
- And many other excellent packages

---

Made with care for your privacy.
