import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../api/vision_api.dart';
import '../../providers/cocktail_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/vision_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class SmartScannerScreen extends ConsumerStatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  ConsumerState<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends ConsumerState<SmartScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  Uint8List? _imageBytes;
  VisionAnalysisResponse? _analysisResult;
  final Set<String> _selectedIngredients = {};

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,  // Limit image size for faster processing
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _analysisResult = null;
          _selectedIngredients.clear();
        });

        await _analyzeImage(bytes);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Get vision API instance
      final visionApi = ref.read(visionApiProvider);

      // Analyze image
      final result = await visionApi.analyzeImage(bytes);

      setState(() {
        _analysisResult = result;
        // Auto-select high confidence matches
        for (final match in result.matched) {
          if (match.confidence > 0.7) {
            _selectedIngredients.add(match.ingredientName);
          }
        }
      });
    } catch (e) {
      _showError('Failed to analyze image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _addToInventory() async {
    if (_selectedIngredients.isEmpty) {
      _showError('Please select at least one ingredient');
      return;
    }

    try {
      final db = ref.read(databaseServiceProvider);
      // Add each selected ingredient to inventory
      for (final ingredient in _selectedIngredients) {
        await db.addToInventory(
          ingredient,
          notes: 'Added via Smart Scanner',
        );
      }

      // Invalidate the inventory provider to refresh
      ref.invalidate(inventoryProvider);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${_selectedIngredients.length} items to your bar'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Failed to add ingredients: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('Smart Scanner', style: AppTypography.heading2),
        backgroundColor: AppColors.backgroundSecondary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.camera_alt, color: AppColors.primaryPurple, size: 48),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Scan Your Bar',
                    style: AppTypography.heading3,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Take a photo of the bottles (labels facing front) and we\'ll identify them for you',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // Camera/Gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.iconCircleBlue,  // Changed to blue for better visibility
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text('Choose Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.iconCircleTeal,  // Changed to teal for contrast
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Image preview
            if (_imageBytes != null) ...[
              SizedBox(height: AppSpacing.lg),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],

            // Processing indicator
            if (_isProcessing) ...[
              SizedBox(height: AppSpacing.lg),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryPurple),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Analyzing image...',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            // Results
            if (_analysisResult != null && !_isProcessing) ...[
              SizedBox(height: AppSpacing.lg),

              // Confidence indicator
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics,
                      color: _analysisResult!.confidence > 0.7
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Confidence: ${(_analysisResult!.confidence * 100).toStringAsFixed(0)}%',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // Matched ingredients
              if (_analysisResult!.matched.isNotEmpty) ...[
                Text(
                  'Detected Bottles',
                  style: AppTypography.heading3,
                ),
                SizedBox(height: AppSpacing.sm),

                ...(_analysisResult!.matched.map((match) =>
                  CheckboxListTile(
                    title: Text(
                      match.ingredientName,
                      style: AppTypography.bodyMedium,
                    ),
                    subtitle: Text(
                      'Confidence: ${(match.confidence * 100).toStringAsFixed(0)}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _selectedIngredients.contains(match.ingredientName),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedIngredients.add(match.ingredientName);
                        } else {
                          _selectedIngredients.remove(match.ingredientName);
                        }
                      });
                    },
                    activeColor: AppColors.primaryPurple,
                    checkColor: Colors.white,
                  ),
                )),

                SizedBox(height: AppSpacing.lg),

                // Add to inventory button
                ElevatedButton(
                  onPressed: _selectedIngredients.isEmpty
                      ? null
                      : _addToInventory,
                  child: Text(
                    'Add ${_selectedIngredients.length} Items to My Bar',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(AppSpacing.md),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                // No matches found
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        color: AppColors.warning,
                        size: 48,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'No bottles detected',
                        style: AppTypography.heading3,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Try taking a clearer photo with better lighting',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              // Raw analysis (debug info - remove in production)
              if (_analysisResult!.rawAnalysis.description.isNotEmpty) ...[
                SizedBox(height: AppSpacing.md),
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Description:',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _analysisResult!.rawAnalysis.description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
