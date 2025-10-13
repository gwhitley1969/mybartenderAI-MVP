import { setTimeout as delay } from 'timers/promises';

export interface CocktailIngredient {
  name: string;
  measure?: string | null;
  position: number;
}

export interface CocktailRecord {
  id: string;
  name: string;
  category?: string | null;
  alcoholic?: string | null;
  glass?: string | null;
  instructions?: string | null;
  thumbnail?: string | null;
  tags: string[];
  ingredients: CocktailIngredient[];
  raw: Record<string, unknown>;
}

interface CocktailDbClientOptions {
  throttleMs?: number;
  maxRetries?: number;
}

const DEFAULT_BASE_URL = 'https://www.thecocktaildb.com';
const DEFAULT_THROTTLE_MS = Number(process.env.COCKTAILDB_THROTTLE_MS ?? '200');
const DEFAULT_MAX_RETRIES = Number(process.env.COCKTAILDB_MAX_RETRIES ?? '3');

const buildUrl = (path: string, params?: Record<string, string>): string => {
  const url = new URL(path, DEFAULT_BASE_URL);
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
  }
  return url.toString();
};

const sleep = (ms: number): Promise<void> => delay(ms);

const parseTags = (value?: string | null): string[] =>
  value ? value.split(',').map((tag) => tag.trim()).filter(Boolean) : [];

const buildIngredients = (drink: Record<string, unknown>): CocktailIngredient[] => {
  const items: CocktailIngredient[] = [];
  for (let i = 1; i <= 15; i += 1) {
    const ingredientKey = `strIngredient${i}` as keyof typeof drink;
    const measureKey = `strMeasure${i}` as keyof typeof drink;
    const name = drink[ingredientKey];
    if (typeof name !== 'string' || !name.trim()) {
      continue;
    }
    const measure = drink[measureKey];
    items.push({
      name: name.trim(),
      measure: typeof measure === 'string' ? measure.trim() || null : null,
      position: i,
    });
  }
  return items;
};

export class CocktailDbClient {
  private readonly apiKey: string;

  private readonly throttleMs: number;

  private readonly maxRetries: number;

  constructor(apiKey: string, options: CocktailDbClientOptions = {}) {
    if (!apiKey) {
      throw new Error('COCKTAILDB-API-KEY environment variable is required.');
    }
    this.apiKey = apiKey.trim();
    this.throttleMs = options.throttleMs ?? DEFAULT_THROTTLE_MS;
    this.maxRetries = options.maxRetries ?? DEFAULT_MAX_RETRIES;
  }

  private async fetchJson<T>(path: string, params?: Record<string, string>): Promise<T> {
    const url = buildUrl(path, params);
    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      try {
        const response = await fetch(url, {
          headers: {
            'User-Agent': 'MyBartenderAI/Sync',
          },
        });
        if (response.status === 429) {
          if (attempt >= this.maxRetries) {
            throw new Error('CocktailDB throttled request after maximum retries.');
          }
          const retryAfter = Number(response.headers.get('retry-after') ?? '1') * 1000;
          await sleep(Math.max(this.throttleMs, retryAfter));
          attempt += 1;
          continue;
        }
        if (!response.ok) {
          throw new Error(`CocktailDB request failed with status ${response.status}`);
        }
        const json = (await response.json()) as T;
        await sleep(this.throttleMs);
        return json;
      } catch (error) {
        if (attempt >= this.maxRetries) {
          throw error;
        }
        await sleep(this.throttleMs * (attempt + 1));
        attempt += 1;
      }
    }
  }

  private async fetchDrinksForLetter(letter: string): Promise<CocktailRecord[]> {
    const data = await this.fetchJson<{ drinks: Record<string, unknown>[] | null }>(
      `/api/json/v2/${this.apiKey}/search.php`,
      { f: letter },
    );
    if (!data.drinks) {
      return [];
    }
    return data.drinks
      .filter((drink) => typeof drink?.idDrink === 'string')
      .map((drink) => {
        const id = String(drink.idDrink);
        return {
          id,
          name: typeof drink.strDrink === 'string' ? drink.strDrink : id,
          category: typeof drink.strCategory === 'string' ? drink.strCategory : null,
          alcoholic: typeof drink.strAlcoholic === 'string' ? drink.strAlcoholic : null,
          glass: typeof drink.strGlass === 'string' ? drink.strGlass : null,
          instructions: typeof drink.strInstructions === 'string' ? drink.strInstructions : null,
          thumbnail: typeof drink.strDrinkThumb === 'string' ? drink.strDrinkThumb : null,
          tags: parseTags(typeof drink.strTags === 'string' ? drink.strTags : null),
          ingredients: buildIngredients(drink),
          raw: drink,
        };
      });
  }

  public async fetchCatalog(): Promise<CocktailRecord[]> {
    const letters = 'abcdefghijklmnopqrstuvwxyz'.split('');
    const results: CocktailRecord[] = [];
    for (const letter of letters) {
      const drinks = await this.fetchDrinksForLetter(letter);
      results.push(...drinks);
    }
    return results;
  }
}
