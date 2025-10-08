export interface Inventory {
  spirits?: string[];
  mixers?: string[];
}

export interface TasteProfile {
  preferredFlavors?: string[];
  dislikedFlavors?: string[];
  abvRange?: string;
}

export interface RecommendRequestBody {
  inventory: Inventory;
  tasteProfile?: TasteProfile;
}

export interface RecommendationIngredient {
  name: string;
  amount: number;
  unit: string;
}

export interface Recommendation {
  id: string;
  name: string;
  reason?: string;
  ingredients: RecommendationIngredient[];
  instructions: string;
  glassware?: string;
  garnish?: string;
}

export interface ErrorPayload {
  code: string;
  message: string;
  traceId: string;
  details?: Record<string, unknown>;
}
