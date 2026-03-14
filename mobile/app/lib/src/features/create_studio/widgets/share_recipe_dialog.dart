import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../services/recipe_card_share_service.dart';
import '../../../services/review_service.dart';
import '../../../services/user_settings_service.dart';
import '../../../theme/theme.dart';

/// Dialog shown after saving a custom cocktail, encouraging the user
/// to share their recipe with friends.
class ShareRecipeDialog extends StatefulWidget {
  final Cocktail cocktail;

  const ShareRecipeDialog({super.key, required this.cocktail});

  /// Convenience method to show the dialog.
  static Future<void> show(BuildContext context,
      {required Cocktail cocktail}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ShareRecipeDialog(cocktail: cocktail),
    );
  }

  @override
  State<ShareRecipeDialog> createState() => _ShareRecipeDialogState();
}

class _ShareRecipeDialogState extends State<ShareRecipeDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              color: AppColors.primaryPurple,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            'Nice work!',
            style: AppTypography.heading2,
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            'Share your creation with friends so they can try it too!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Don't show again checkbox
          GestureDetector(
            onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _dontShowAgain,
                    onChanged: (v) =>
                        setState(() => _dontShowAgain = v ?? false),
                    activeColor: AppColors.primaryPurple,
                    side: BorderSide(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Don't ask me again",
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _dismiss(context),
          child: Text(
            'Maybe Later',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _shareAndDismiss(context),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Share Recipe'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
            ),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  void _dismiss(BuildContext context) {
    if (_dontShowAgain) {
      UserSettingsService.instance.dismissSharePrompt();
    }
    Navigator.of(context).pop();
  }

  Future<void> _shareAndDismiss(BuildContext context) async {
    if (_dontShowAgain) {
      UserSettingsService.instance.dismissSharePrompt();
    }

    final cocktail = widget.cocktail;
    final nav = Navigator.of(context);

    // Compute iOS share position origin before any async gap
    Rect? sharePositionOrigin;
    if (Platform.isIOS) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        sharePositionOrigin = position & renderBox.size;
      }
    }

    try {
      await RecipeCardShareService.instance.shareRecipeCard(
        context,
        cocktail,
        sharePositionOrigin: sharePositionOrigin,
      );
      // Record sharing win moment and defer prompt
      await ReviewService.instance.recordWinMoment(WinMomentType.sharingSuccess);
      await ReviewService.instance.setPendingPrompt();
    } catch (e) {
      debugPrint('[SHARE] Share from dialog failed: $e');
    }

    nav.pop();
  }
}
