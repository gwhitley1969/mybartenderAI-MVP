import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../theme/theme.dart';
import 'models/academy_models.dart';
import 'widgets/difficulty_badge.dart';

/// Screen for playing a lesson video with YouTube embedded player.
///
/// Uses [YoutubePlayerScaffold] to provide proper fullscreen support.
/// The video player is controlled via [YoutubePlayerController].
class AcademyLessonScreen extends StatefulWidget {
  final AcademyLesson lesson;

  const AcademyLessonScreen({
    required this.lesson,
    super.key,
  });

  @override
  State<AcademyLessonScreen> createState() => _AcademyLessonScreenState();
}

class _AcademyLessonScreenState extends State<AcademyLessonScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.lesson.youtubeVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
        enableCaption: true,
        playsInline: true,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () {
                _controller.pauseVideo();
                Navigator.pop(context);
              },
            ),
            title: Text(
              widget.lesson.title,
              style: AppTypography.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // YouTube Player
                player,
                // Lesson details
                Padding(
                  padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title (larger, below video)
                      Text(
                        widget.lesson.title,
                        style: AppTypography.heading3,
                      ),
                      SizedBox(height: AppSpacing.md),
                      // Metadata row
                      Row(
                        children: [
                          DifficultyBadge(difficulty: widget.lesson.difficulty),
                          SizedBox(width: AppSpacing.md),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            widget.lesson.duration,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.lg),
                      // Description
                      Text(
                        widget.lesson.description,
                        style: AppTypography.bodyLarge,
                      ),
                      SizedBox(height: AppSpacing.xl),
                      // Tags
                      if (widget.lesson.tags.isNotEmpty) ...[
                        Text(
                          'Topics',
                          style: AppTypography.cardTitle,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: widget.lesson.tags.map((tag) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.badgeBorderRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      // Bottom padding
                      SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
