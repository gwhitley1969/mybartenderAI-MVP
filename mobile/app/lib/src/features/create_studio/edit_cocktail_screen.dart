import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../api/create_studio_api.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import 'widgets/ingredient_list.dart';
import 'widgets/refinement_dialog.dart';

class EditCocktailScreen extends ConsumerStatefulWidget {
  const EditCocktailScreen({super.key, this.cocktail});

  final Cocktail? cocktail;

  @override
  ConsumerState<EditCocktailScreen> createState() =>
      _EditCocktailScreenState();
}

class _EditCocktailScreenState extends ConsumerState<EditCocktailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _selectedCategory;
  String? _selectedGlass;
  String? _selectedAlcoholic;
  List<IngredientInput> _ingredients = [];

  bool _isSaving = false;
  bool _isRefining = false;

  // Common categories
  final List<String> _categories = [
    'Cocktail',
    'Shot',
    'Ordinary Drink',
    'Punch / Party Drink',
    'Beer',
    'Coffee / Tea',
    'Shake',
    'Cocoa',
    'Other/Unknown',
  ];

  // Common glass types
  final List<String> _glassTypes = [
    'Highball glass',
    'Cocktail glass',
    'Old-fashioned glass',
    'Whiskey glass',
    'Collins glass',
    'Martini glass',
    'Margarita glass',
    'Wine glass',
    'Champagne flute',
    'Shot glass',
    'Pint glass',
    'Beer mug',
    'Hurricane glass',
  ];

  // Alcoholic types
  final List<String> _alcoholicTypes = [
    'Alcoholic',
    'Non alcoholic',
    'Optional alcohol',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.cocktail != null) {
      // Edit mode
      _nameController.text = widget.cocktail!.name;
      _selectedCategory = widget.cocktail!.category;
      _selectedGlass = widget.cocktail!.glass;
      _selectedAlcoholic = widget.cocktail!.alcoholic;
      _instructionsController.text = widget.cocktail!.instructions ?? '';

      if (widget.cocktail!.ingredients != null) {
        _ingredients = widget.cocktail!.ingredients!
            .map((ing) => IngredientInput(
                  name: ing.ingredientName,
                  measure: ing.measure ?? '',
                ))
            .toList();
      }
    } else {
      // Create mode - start with one empty ingredient
      _ingredients = [IngredientInput(name: '', measure: '')];
      _selectedAlcoholic = 'Alcoholic';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.cocktail != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => _handleBack(),
        ),
        title: Text(
          isEditMode ? 'Edit Cocktail' : 'Create Cocktail',
          style: AppTypography.appTitle,
        ),
        actions: [
          if (!isEditMode)
            TextButton.icon(
              onPressed: _isRefining ? null : _handleAIRefinement,
              icon: _isRefining
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple),
                      ),
                    )
                  : Icon(Icons.auto_awesome, color: AppColors.primaryPurple),
              label: Text(
                'AI Refine',
                style: AppTypography.bodyMedium.copyWith(
                  color: _isRefining
                      ? AppColors.textSecondary
                      : AppColors.primaryPurple,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field
              _buildSectionTitle('Cocktail Name'),
              TextFormField(
                controller: _nameController,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'e.g., Sunset Paradise',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a cocktail name';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Category dropdown
              _buildSectionTitle('Category'),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: AppTypography.bodyMedium,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                hint: Text('Select a category',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    )),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Glass type dropdown
              _buildSectionTitle('Glass Type'),
              DropdownButtonFormField<String>(
                value: _selectedGlass,
                style: AppTypography.bodyMedium,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                hint: Text('Select glass type',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    )),
                items: _glassTypes.map((glass) {
                  return DropdownMenuItem(
                    value: glass,
                    child: Text(glass),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGlass = value;
                  });
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Alcoholic type dropdown
              _buildSectionTitle('Alcoholic Type'),
              DropdownButtonFormField<String>(
                value: _selectedAlcoholic,
                style: AppTypography.bodyMedium,
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                items: _alcoholicTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAlcoholic = value;
                  });
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Ingredients section
              _buildSectionTitle('Ingredients'),
              IngredientList(
                ingredients: _ingredients,
                onIngredientsChanged: (ingredients) {
                  setState(() {
                    _ingredients = ingredients;
                  });
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Instructions field
              _buildSectionTitle('Instructions'),
              TextFormField(
                controller: _instructionsController,
                style: AppTypography.bodyMedium,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Describe how to make this cocktail...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                    borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        isEditMode ? 'Save Changes' : 'Create Cocktail',
                        style: AppTypography.buttonMedium,
                      ),
              ),
              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.heading3.copyWith(fontSize: 16),
      ),
    );
  }

  void _handleBack() {
    if (_formKey.currentState?.validate() == false ||
        _nameController.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text('Discard changes?', style: AppTypography.heading3),
          content: Text(
            'You have unsaved changes. Are you sure you want to go back?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppTypography.bodyMedium),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              },
              child: Text('Discard',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleAIRefinement() async {
    // Validate minimum required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a cocktail name first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_ingredients.where((i) => i.name.trim().isNotEmpty).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isRefining = true;
    });

    try {
      final apiService = ref.read(createStudioApiProvider);

      final draft = CocktailDraft(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        glass: _selectedGlass,
        alcoholic: _selectedAlcoholic,
        instructions: _instructionsController.text.trim(),
        ingredients: _ingredients
            .where((i) => i.name.trim().isNotEmpty)
            .map((i) => CocktailIngredient(
                  name: i.name.trim(),
                  measure: i.measure.trim().isEmpty ? null : i.measure.trim(),
                ))
            .toList(),
      );

      final refinement = await apiService.refineCocktail(draft);

      if (mounted) {
        await showRefinementDialog(
          context: context,
          refinement: refinement,
          onApply: (refinedRecipe) {
            _applyRefinement(refinedRecipe);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting refinement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefining = false;
        });
      }
    }
  }

  void _applyRefinement(RefinedRecipe refinedRecipe) {
    setState(() {
      _nameController.text = refinedRecipe.name;
      if (refinedRecipe.category != null) {
        _selectedCategory = refinedRecipe.category;
      }
      if (refinedRecipe.glass != null) {
        _selectedGlass = refinedRecipe.glass;
      }
      _instructionsController.text = refinedRecipe.instructions;
      _ingredients = refinedRecipe.ingredients
          .map((i) => IngredientInput(
                name: i.name,
                measure: i.measure ?? '',
              ))
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refinements applied!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one ingredient
    final validIngredients = _ingredients.where((i) => i.name.trim().isNotEmpty);
    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final isEditMode = widget.cocktail != null;

      final cocktailId = isEditMode ? widget.cocktail!.id : 'custom-${const Uuid().v4()}';
      final now = DateTime.now();

      final cocktail = Cocktail(
        id: cocktailId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        glass: _selectedGlass,
        alcoholic: _selectedAlcoholic ?? 'Alcoholic',
        instructions: _instructionsController.text.trim(),
        imageUrl: widget.cocktail?.imageUrl,
        ingredients: validIngredients
            .toList()
            .asMap()
            .entries
            .map((entry) => DrinkIngredient(
                  drinkId: cocktailId,
                  ingredientName: entry.value.name.trim(),
                  measure: entry.value.measure.trim().isEmpty ? null : entry.value.measure.trim(),
                  ingredientOrder: entry.key + 1,
                ))
            .toList(),
        isCustom: true,
        createdAt: isEditMode ? widget.cocktail!.createdAt : now,
        updatedAt: now,
      );

      if (isEditMode) {
        await db.updateCustomCocktail(cocktail);
      } else {
        await db.insertCocktail(cocktail);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode
                ? 'Cocktail updated successfully!'
                : 'Cocktail created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving cocktail: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

// Helper class for ingredient input
class IngredientInput {
  String name;
  String measure;

  IngredientInput({
    required this.name,
    required this.measure,
  });
}
