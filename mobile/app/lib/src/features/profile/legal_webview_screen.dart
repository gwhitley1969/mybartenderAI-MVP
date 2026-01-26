import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/theme.dart';

/// Screen for displaying legal documents (Privacy Policy, Terms of Service)
/// in a WebView that stays within the app.
class LegalWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const LegalWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundPrimary)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading state
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title, style: AppTypography.appTitle),
      ),
      body: Stack(
        children: [
          // WebView
          if (!_hasError)
            WebViewWidget(controller: _controller),

          // Loading indicator
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            ),

          // Error state
          if (_hasError)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Unable to load ${widget.title}',
                      style: AppTypography.heading3,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Please check your internet connection and try again.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
