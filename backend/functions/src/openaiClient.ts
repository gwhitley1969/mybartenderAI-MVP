import {
  OpenAiRecommendationOptions,
  RecommendRequestBody,
  Recommendation,
} from './types';

export const AI_MODEL_DEFAULT =
  process.env.AI_MODEL_DEFAULT ?? 'gpt-4.1-mini';

export interface OpenAiClient {
  readonly model: string;
  getRecommendations(
    request: RecommendRequestBody,
    options: OpenAiRecommendationOptions,
  ): Promise<Recommendation[]>;
}

class StubOpenAiClient implements OpenAiClient {
  public readonly model = AI_MODEL_DEFAULT;

  async getRecommendations(
    request: RecommendRequestBody,
    _options: OpenAiRecommendationOptions,
  ): Promise<Recommendation[]> {
    const spirit = request.inventory.spirits?.[0] ?? 'Bourbon';
    const mixer = request.inventory.mixers?.[0] ?? 'Simple Syrup';

    return [
      {
        id: 'stub-old-fashioned',
        name: 'Old Fashioned',
        reason: `Balanced build featuring ${spirit}.`,
        ingredients: [
          { name: spirit, amount: 2, unit: 'oz' },
          { name: mixer, amount: 0.25, unit: 'oz' },
          { name: 'Angostura Bitters', amount: 2, unit: 'dashes' },
        ],
        instructions:
          'Stir all ingredients over ice until chilled, strain over a large cube, garnish with expressed orange peel.',
        glassware: 'Rocks',
        garnish: 'Orange peel',
      },
      {
        id: 'stub-sour',
        name: `${spirit} Sour`,
        reason: `Leverages ${spirit} with fresh citrus for a crowd-pleaser.`,
        ingredients: [
          { name: spirit, amount: 2, unit: 'oz' },
          { name: 'Fresh Lemon Juice', amount: 0.75, unit: 'oz' },
          { name: mixer, amount: 0.75, unit: 'oz' },
        ],
        instructions:
          'Shake with ice until well chilled, strain into a chilled coupe, garnish if desired.',
        glassware: 'Coupe',
        garnish: 'Lemon twist',
      },
    ];
  }
}

const singletonClient: OpenAiClient = new StubOpenAiClient();

export const getOpenAiClient = (): OpenAiClient => singletonClient;
