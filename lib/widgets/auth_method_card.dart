import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Reusable card for authentication method selection
class AuthMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const AuthMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.accent,
                ),
              ),

              const SizedBox(width: 20),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                        fontFamily: 'ProductSans',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.lightTextSecondary,
                        fontFamily: 'ProductSans',
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: AppColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
