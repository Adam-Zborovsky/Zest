// One-shot bridge for the Flutter contract demo. Only invented data; no listener.
import { buildApp } from '../src/app.js';

const app = buildApp({ apiKey: '1', fetcher: async (url) => {
  const endpoint = new URL(url).pathname.split('/').at(-1);
  const recipe = { idDrink: '990001', strDrink: 'Paper Orchard', strDrinkThumb: null,
    strInstructions: 'Stir the imaginary ingredients.', strIngredient1: 'Invented syrup', strMeasure1: '1 1/2 oz' };
  return Response.json({ drinks: endpoint === 'list.php' ? [{ strIngredient1: 'Invented syrup' }]
    : endpoint === 'filter.php' ? [{ idDrink: recipe.idDrink, strDrink: recipe.strDrink, strDrinkThumb: null }]
    : [recipe] });
} });
try {
  const url = new URL(process.argv[2] ?? 'http://127.0.0.1:3000/api/health');
  const response = await app.inject({ method: 'GET', url: url.pathname + url.search });
  console.info(JSON.stringify({ status: response.statusCode, body: response.body }));
} finally { await app.close(); }
