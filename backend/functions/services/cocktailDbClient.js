"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CocktailDbClient = void 0;
const promises_1 = require("timers/promises");
const DEFAULT_BASE_URL = 'https://www.thecocktaildb.com';
const DEFAULT_THROTTLE_MS = Number(process.env.COCKTAILDB_THROTTLE_MS ?? '200');
const DEFAULT_MAX_RETRIES = Number(process.env.COCKTAILDB_MAX_RETRIES ?? '3');
const buildUrl = (path, params) => {
    const url = new URL(path, DEFAULT_BASE_URL);
    if (params) {
        for (const [key, value] of Object.entries(params)) {
            url.searchParams.set(key, value);
        }
    }
    return url.toString();
};
const sleep = (ms) => (0, promises_1.setTimeout)(ms);
const parseTags = (value) => value ? value.split(',').map((tag) => tag.trim()).filter(Boolean) : [];
const buildIngredients = (drink) => {
    const items = [];
    for (let i = 1; i <= 15; i += 1) {
        const ingredientKey = `strIngredient${i}`;
        const measureKey = `strMeasure${i}`;
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
class CocktailDbClient {
    constructor(apiKey, options = {}) {
        if (!apiKey) {
            throw new Error('COCKTAILDB-API-KEY environment variable is required.');
        }
        this.apiKey = apiKey.trim();
        this.throttleMs = options.throttleMs ?? DEFAULT_THROTTLE_MS;
        this.maxRetries = options.maxRetries ?? DEFAULT_MAX_RETRIES;
    }
    async fetchJson(path, params) {
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
                const json = (await response.json());
                await sleep(this.throttleMs);
                return json;
            }
            catch (error) {
                if (attempt >= this.maxRetries) {
                    throw error;
                }
                await sleep(this.throttleMs * (attempt + 1));
                attempt += 1;
            }
        }
    }
    async fetchDrinksForLetter(letter) {
        const data = await this.fetchJson(`/api/json/v2/${this.apiKey}/search.php`, { f: letter });
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
    async fetchCatalog() {
        const letters = 'abcdefghijklmnopqrstuvwxyz'.split('');
        const results = [];
        for (const letter of letters) {
            const drinks = await this.fetchDrinksForLetter(letter);
            results.push(...drinks);
        }
        return results;
    }
}
exports.CocktailDbClient = CocktailDbClient;

