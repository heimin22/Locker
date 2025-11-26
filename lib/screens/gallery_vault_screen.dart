import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Gallery vault screen - main screen after authentication
class GalleryVaultScreen extends StatelessWidget {
  const GalleryVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Gallery Vault',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: AppColors.lightTextPrimary),
            onPressed: () {
              // TODO: Add settings menu
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.lightBackgroundSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: AppColors.lightTextTertiary,
              ),
            ),

            const SizedBox(height: 24),

            // Empty state text
            Text(
              'No media yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.lightTextPrimary,
                fontFamily: 'ProductSans',
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Your hidden photos and videos\nwill appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.lightTextSecondary,
                fontFamily: 'ProductSans',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add media
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Media import feature coming soon',
                style: TextStyle(fontFamily: 'ProductSans'),
              ),
              backgroundColor: AppColors.accent,
            ),
          );
        },
        backgroundColor: AppColors.accent,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
