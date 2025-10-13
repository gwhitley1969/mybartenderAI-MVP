import type { PoolClient } from "pg";

import { withTransaction } from "../shared/db/postgresPool.js";
import type { CocktailRecord } from "./cocktailDbClient.js";

export interface SyncResultCounts {
  drinks: number;
  ingredients: number;
  measures: number;
  categories: number;
  glasses: number;
  tags: number;
}

const truncateTables = async (client: PoolClient): Promise<void> => {
  await client.query(`
    TRUNCATE TABLE
      drink_tags,
      drink_glasses,
      drink_categories,
      ingredients,
      measures,
      drinks
    RESTART IDENTITY CASCADE;
    TRUNCATE TABLE tags RESTART IDENTITY CASCADE;
    TRUNCATE TABLE categories RESTART IDENTITY CASCADE;
    TRUNCATE TABLE glasses RESTART IDENTITY CASCADE;
  `);
};

const uniq = (values: (string | null | undefined)[]): string[] => {
  const set = new Set<string>();
  for (const value of values) {
    if (value && value.trim()) {
      set.add(value.trim());
    }
  }
  return Array.from(set);
};

const INSERT_TABLE_MAP: Record<'categories' | 'glasses' | 'tags', string> = {
  categories: 'categories',
  glasses: 'glasses',
  tags: 'tags',
};

const insertLookup = async (
  client: PoolClient,
  table: 'categories' | 'glasses' | 'tags',
  names: string[],
): Promise<Map<string, number>> => {
  if (names.length === 0) {
    return new Map();
  }

  const tableName = INSERT_TABLE_MAP[table];

  await client.query(
    `INSERT INTO ${tableName} (name)
     SELECT DISTINCT UNNEST($1::text[])
     ON CONFLICT (name) DO NOTHING`,
    [names],
  );

  const rows = await client.query<{ id: number; name: string }>(
    `SELECT id, name FROM ${tableName} WHERE name = ANY($1::text[])`,
    [names],
  );

  const map = new Map<string, number>();
  for (const row of rows.rows) {
    map.set(row.name, row.id);
  }
  return map;
};

export const syncCocktailCatalog = async (
  records: CocktailRecord[],
): Promise<SyncResultCounts> => {
  const result = await withTransaction(async (client) => {
    await truncateTables(client);

    const categoryMap = await insertLookup(
      client,
      'categories',
      uniq(records.map((drink) => drink.category ?? null)),
    );

    const glassMap = await insertLookup(
      client,
      'glasses',
      uniq(records.map((drink) => drink.glass ?? null)),
    );

    const tagMap = await insertLookup(
      client,
      'tags',
      uniq(records.flatMap((drink) => drink.tags)),
    );

    for (const drink of records) {
      await client.query(
        `INSERT INTO drinks (id, name, category, alcoholic, glass, instructions, thumbnail, raw)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          drink.id,
          drink.name,
          drink.category ?? null,
          drink.alcoholic ?? null,
          drink.glass ?? null,
          drink.instructions ?? null,
          drink.thumbnail ?? null,
          JSON.stringify(drink.raw),
        ],
      );

      for (const ingredient of drink.ingredients) {
        await client.query(
          `INSERT INTO ingredients (drink_id, position, name)
           VALUES ($1, $2, $3)`,
          [drink.id, ingredient.position, ingredient.name],
        );

        await client.query(
          `INSERT INTO measures (drink_id, position, measure)
           VALUES ($1, $2, $3)`,
          [drink.id, ingredient.position, ingredient.measure ?? null],
        );
      }

      const categoryId = drink.category ? categoryMap.get(drink.category) : undefined;
      if (categoryId) {
        await client.query(
          `INSERT INTO drink_categories (drink_id, category_id)
           VALUES ($1, $2)
           ON CONFLICT (drink_id, category_id) DO NOTHING`,
          [drink.id, categoryId],
        );
      }

      const glassId = drink.glass ? glassMap.get(drink.glass) : undefined;
      if (glassId) {
        await client.query(
          `INSERT INTO drink_glasses (drink_id, glass_id)
           VALUES ($1, $2)
           ON CONFLICT (drink_id, glass_id) DO NOTHING`,
          [drink.id, glassId],
        );
      }

      for (const tag of drink.tags) {
        const tagId = tagMap.get(tag);
        if (!tagId) {
          continue;
        }
        await client.query(
          `INSERT INTO drink_tags (drink_id, tag_id)
           VALUES ($1, $2)
           ON CONFLICT (drink_id, tag_id) DO NOTHING`,
          [drink.id, tagId],
        );
      }
    }

    const counts = await client.query<{
      drinks: string;
      ingredients: string;
      measures: string;
      categories: string;
      glasses: string;
      tags: string;
    }>(
      `SELECT
         (SELECT COUNT(*)::text FROM drinks) AS drinks,
         (SELECT COUNT(*)::text FROM ingredients) AS ingredients,
         (SELECT COUNT(*)::text FROM measures) AS measures,
         (SELECT COUNT(*)::text FROM categories) AS categories,
         (SELECT COUNT(*)::text FROM glasses) AS glasses,
         (SELECT COUNT(*)::text FROM tags) AS tags`,
    );

    return counts.rows[0];
  });

  return {
    drinks: Number(result.drinks ?? 0),
    ingredients: Number(result.ingredients ?? 0),
    measures: Number(result.measures ?? 0),
    categories: Number(result.categories ?? 0),
    glasses: Number(result.glasses ?? 0),
    tags: Number(result.tags ?? 0),
  };
};
