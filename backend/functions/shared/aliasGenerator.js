/**
 * Alias Generation Utility for Friends via Code Feature
 *
 * Generates system aliases in the format: @adjective-animal-###
 * Example: @happy-penguin-42
 *
 * Privacy-focused: Aliases are randomized and don't reveal user identity
 */

const adjectives = [
  // Positive emotions
  'happy', 'clever', 'swift', 'bright', 'cool',
  'wild', 'calm', 'bold', 'wise', 'keen',
  'brave', 'quick', 'sharp', 'smooth', 'fresh',

  // Cocktail-themed descriptors
  'crisp', 'warm', 'chill', 'mellow', 'zesty',
  'bitter', 'sweet', 'sour', 'spicy', 'tangy',
  'fizzy', 'smoky', 'fruity', 'tropical', 'classic',

  // Additional variety
  'cosmic', 'electric', 'golden', 'silver', 'ruby',
  'vibrant', 'stellar', 'neon', 'radiant', 'mystic'
];

const animals = [
  // Birds of prey
  'owl', 'hawk', 'eagle', 'raven', 'falcon',

  // Mammals
  'fox', 'bear', 'wolf', 'lynx', 'otter',
  'seal', 'panda', 'koala', 'lemur', 'tiger',

  // Marine creatures
  'whale', 'shark', 'ray', 'crab', 'squid',
  'dolphin', 'octopus', 'seahorse', 'starfish', 'jellyfish',

  // Reptiles & exotic
  'gecko', 'cobra', 'dragon', 'phoenix', 'griffin'
];

/**
 * Generate a random system alias
 * @returns {string} Alias in format @adjective-animal-###
 */
function generateAlias() {
  const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
  const animal = animals[Math.floor(Math.random() * animals.length)];
  const number = Math.floor(Math.random() * 900) + 100; // 100-999

  return `@${adjective}-${animal}-${number}`;
}

/**
 * Generate a unique alias (checks against existing aliases in database)
 * @param {object} dbClient - PostgreSQL client instance
 * @param {number} maxAttempts - Maximum retry attempts (default: 10)
 * @returns {Promise<string>} Unique alias
 * @throws {Error} If unable to generate unique alias after maxAttempts
 */
async function generateUniqueAlias(dbClient, maxAttempts = 10) {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const alias = generateAlias();

    // Check if alias already exists
    const result = await dbClient.query(
      'SELECT 1 FROM user_profile WHERE alias = $1',
      [alias]
    );

    if (result.rows.length === 0) {
      return alias; // Found unique alias
    }
  }

  throw new Error(`Failed to generate unique alias after ${maxAttempts} attempts`);
}

/**
 * Validate alias format
 * @param {string} alias - Alias to validate
 * @returns {boolean} True if alias matches expected format
 */
function isValidAliasFormat(alias) {
  // Format: @word-word-###
  const aliasPattern = /^@[a-z]+-[a-z]+-\d{3}$/;
  return aliasPattern.test(alias);
}

/**
 * Validate display name
 * @param {string} displayName - Display name to validate
 * @returns {object} { valid: boolean, error?: string }
 */
function validateDisplayName(displayName) {
  if (!displayName) {
    return { valid: true }; // Display name is optional
  }

  if (typeof displayName !== 'string') {
    return { valid: false, error: 'Display name must be a string' };
  }

  if (displayName.length > 30) {
    return { valid: false, error: 'Display name must be 30 characters or less' };
  }

  // Check for prohibited characters (e.g., control characters)
  if (/[\x00-\x1F\x7F]/.test(displayName)) {
    return { valid: false, error: 'Display name contains invalid characters' };
  }

  return { valid: true };
}

module.exports = {
  generateAlias,
  generateUniqueAlias,
  isValidAliasFormat,
  validateDisplayName
};
