const { __dangerous__setPool, __dangerous__resetPool } = require('../shared/db/postgresPool');
const cocktailPreview = require('./index');

// A row as getCocktailById's query returns it (drinks joined with ingredients).
const MARGARITA_ROW = {
    id: '11007',
    name: 'Margarita',
    category: 'Ordinary Drink',
    glass: 'Cocktail glass',
    instructions: 'Rub the rim of the glass with the lime slice to make the salt stick to it.',
    thumbnail: 'https://www.thecocktaildb.com/images/media/drink/5noda61589575158.jpg',
    ingredients: [
        { name: 'Tequila', measure: '1 1/2 oz ' },
        { name: 'Triple sec', measure: '1/2 oz ' },
        { name: 'Lime juice', measure: '1 oz ' },
        { name: 'Salt', measure: null }
    ]
};

beforeEach(() => {
    __dangerous__setPool({ query: async () => ({ rowCount: 1, rows: [MARGARITA_ROW] }) });
    jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterEach(async () => {
    jest.restoreAllMocks();
    await __dangerous__resetPool();
});

async function previewPage(id) {
    const response = await cocktailPreview({}, { params: { id } });
    expect(response.status).toBe(200);
    return response.body;
}

function openInAppAttributes(html) {
    const tag = html.match(/<a\b[^>]*\bid="open-in-app"[^>]*>/);
    expect(tag).not.toBeNull();
    return Object.fromEntries(
        [...tag[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(([, name, value]) => [name, value])
    );
}

test('og:url is the /cocktail/{id} share link', async () => {
    const html = await previewPage('11007');

    expect(html.match(/<meta property="og:url" content="([^"]*)">/)[1])
        .toBe('https://share.mybartenderai.com/cocktail/11007');
});

describe('Open in the app link', () => {
    test('Android opens the /cocktail App Link in the app, or the Play Store without it', async () => {
        const link = openInAppAttributes(await previewPage('11007'));

        expect(link['data-android-href']).toBe(
            'intent://share.mybartenderai.com/cocktail/11007#Intent;scheme=https;' +
            'package=ai.mybartender.mybartenderai;' +
            'S.browser_fallback_url=https%3A%2F%2Fplay.google.com%2Fstore%2Fapps%2Fdetails%3Fid%3Dai.mybartender.mybartenderai;end'
        );
    });

    test('iOS opens the custom scheme with the cocktail in the path', async () => {
        const link = openInAppAttributes(await previewPage('11007'));

        expect(link['data-ios-href']).toBe('mybartender:///cocktail/11007');
    });
});
