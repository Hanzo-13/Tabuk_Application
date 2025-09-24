const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;


// Replace with your actual Google Directions API key
const GOOGLE_API_KEY = 'AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE';

app.use(cors());

app.get('/directions', async (req, res) => {
  const { origin, destination, mode = 'driving', overview = 'full', units = 'metric' } = req.query;
  if (!origin || !destination) {
    return res.status(400).json({ error: 'origin and destination are required' });
  }
  const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${GOOGLE_API_KEY}&mode=${encodeURIComponent(mode)}&overview=${encodeURIComponent(overview)}&units=${encodeURIComponent(units)}`;
  try {
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch directions', details: err.toString() });
  }
});

app.get('/geocode', async (req, res) => {
  const { latlng } = req.query;
  if (!latlng) {
    return res.status(400).json({ error: 'latlng is required' });
  }
  const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${encodeURIComponent(latlng)}&key=${GOOGLE_API_KEY}`;
  try {
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch geocode', details: err.toString() });
  }
});

app.listen(PORT, () => {
  console.log(`Directions proxy server running on port ${PORT}`);
}); 
