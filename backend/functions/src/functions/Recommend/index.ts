import type {
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from '@azure/functions';
import { randomUUID } from 'node:crypto';

interface Inventory {
  spirits?: string[];
  mixers?: string[];
}

interface RecommendRequestBody {
  inventory?: Inventory;
}

interface RecommendationIngredient {
  name: string;
  amount: number;
  unit: string;
}

interface Recommendation {
  id: string;
  name: string;
  ingredients: RecommendationIngredient[];
  instructions: string;
  reason?: string;
  glassware?: string;
  garnish?: string;
}

interface ErrorPayload {
  code: string;
  message: string;
  traceId: string;
  details?: Record<string, unknown>;
}

const HEADERS = (requestId: string): Record<string, string> => ({
  'Content-Type': 'application/json',
  'X-Cache-Hit': 'false',
  'Request-Id': requestId,
});

const parseBody = async (req: HttpRequest): Promise<RecommendRequestBody | undefined> => {
  try {
    return (await req.json()) as RecommendRequestBody;
  } catch {
    return req.body as RecommendRequestBody | undefined;
  }
};

const buildResponse = (inventory: Inventory): Recommendation[] => {
  const spirit = inventory.spirits?.[0] ?? 'Bourbon';
  const mixer = inventory.mixers?.[0] ?? 'Simple Syrup';

  return [
    {
      id: 'sample-old-fashioned',
      name: 'Old Fashioned',
      reason: `Showcases ${spirit} with minimal prep.`,
      ingredients: [
        { name: spirit, amount: 2, unit: 'oz' },
        { name: mixer, amount: 0.25, unit: 'oz' },
        { name: 'Angostura Bitters', amount: 2, unit: 'dashes' },
      ],
      instructions:
        'Stir ingredients with ice until chilled. Strain over a large cube and garnish with orange peel.',
      glassware: 'Rocks',
      garnish: 'Orange peel',
    },
    {
      id: 'sample-highball',
      name: `${spirit} Highball`,
      reason: 'Long, refreshing build that highlights your base spirit.',
      ingredients: [
        { name: spirit, amount: 1.5, unit: 'oz' },
        { name: mixer, amount: 4, unit: 'oz' },
      ],
      instructions:
        'Build in a chilled highball glass over fresh ice. Give a gentle stir and garnish to taste.',
      glassware: 'Highball',
    },
  ];
};

const buildError = (traceId: string, message: string): ErrorPayload => ({
  code: 'BAD_REQUEST',
  message,
  traceId,
  details: { field: 'inventory' },
});

const recommend = async (
  context: InvocationContext,
  req: HttpRequest,
): Promise<HttpResponseInit> => {
  const traceId = context.traceContext?.traceParent ?? randomUUID();
  const payload = await parseBody(req);

  if (!payload?.inventory) {
    return {
      status: 400,
      headers: HEADERS(traceId),
      jsonBody: buildError(traceId, 'Request body must include an inventory object.'),
    };
  }

  return {
    status: 200,
    headers: HEADERS(traceId),
    jsonBody: buildResponse(payload.inventory),
  };
};

export default recommend;
export { recommend };
