import { buildApp } from '../src/app.js';

let requests = 0;
const app = buildApp({ apiKey: '1', fetcher: async () => {
  requests++;
  return Response.json({ drinks: [{ idDrink: '990001', strDrink: 'Paper Orchard',
    strInstructions: 'Stir the imaginary ingredients.', strIngredient1: 'Invented syrup', strMeasure1: '1 part' }] });
} });
try {
  const health = await app.inject('/api/health');
  const first = await app.inject('/api/cocktails/search.php?s=Paper');
  const second = await app.inject('/api/cocktails/search.php?s=Paper');
  if (health.statusCode !== 200 || first.statusCode !== 200 || second.body !== first.body || requests !== 1) {
    throw new Error('Synthetic demo failed.');
  }
  console.info('Synthetic gateway demo: health OK; two searches, one upstream call.');
  console.info('No listener, real provider request, private key or provider content used.');
} finally { await app.close(); }
