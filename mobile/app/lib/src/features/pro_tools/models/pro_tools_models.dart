/// Data models for the Pro Tools feature.
///
/// These models represent bar tool tiers and individual tools
/// with pricing and description information.

/// Represents a price range option (Budget, Mid-Range, Premium).
class PriceRange {
  final String tier;
  final String label;
  final String range;
  final String note;

  const PriceRange({
    required this.tier,
    required this.label,
    required this.range,
    required this.note,
  });

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      tier: json['tier'] as String,
      label: json['label'] as String,
      range: json['range'] as String,
      note: json['note'] as String,
    );
  }
}

/// Represents an individual bar tool with full details.
class ProTool {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String whyYouNeedIt;
  final List<String> whatToLookFor;
  final List<PriceRange> priceRanges;
  final String iconName;
  final int sortOrder;
  final List<String> tags;
  final String? imageAsset; // Optional path to tool image in assets

  const ProTool({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.whyYouNeedIt,
    required this.whatToLookFor,
    required this.priceRanges,
    required this.iconName,
    required this.sortOrder,
    required this.tags,
    this.imageAsset,
  });

  factory ProTool.fromJson(Map<String, dynamic> json) {
    return ProTool(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      whyYouNeedIt: json['whyYouNeedIt'] as String,
      whatToLookFor: (json['whatToLookFor'] as List<dynamic>).cast<String>(),
      priceRanges: (json['priceRanges'] as List<dynamic>)
          .map((p) => PriceRange.fromJson(p as Map<String, dynamic>))
          .toList(),
      iconName: json['iconName'] as String,
      sortOrder: json['sortOrder'] as int,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      imageAsset: json['imageAsset'] as String?,
    );
  }
}

/// Represents a tier of bar tools (Essential, Level Up, Pro Status).
class ToolTier {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String iconName;
  final int sortOrder;
  final List<ProTool> tools;

  const ToolTier({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconName,
    required this.sortOrder,
    required this.tools,
  });

  factory ToolTier.fromJson(Map<String, dynamic> json) {
    return ToolTier(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      sortOrder: json['sortOrder'] as int,
      tools: (json['tools'] as List<dynamic>)
          .map((t) => ProTool.fromJson(t as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  /// Number of tools in this tier.
  int get toolCount => tools.length;
}
