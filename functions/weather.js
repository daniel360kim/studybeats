const functions = require('firebase-functions');
const axios = require('axios');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

// Function to retrieve the OpenWeatherMap API key from Google Cloud Secret Manager
async function getApiKey() {
    const client = new SecretManagerServiceClient();
    const secretName = 'projects/flourish-web-fa343/secrets/OPENWEATHERMAP_API_KEY/versions/latest';
  
    try {
      const [accessResponse] = await client.accessSecretVersion({ name: secretName });
      const apiKey = accessResponse.payload.data.toString('utf8');
      return apiKey;
    } catch (error) {
      console.error('Error accessing secret:', error.message);
      throw new Error('Failed to retrieve OpenWeatherMap API key.');
    }
  }
  
exports.getWeather = functions.https.onCall(async (data, context) => {
  let { latitude, longitude } = data;

  // Try parsing to numbers in case they came through as strings
  latitude = parseFloat(latitude);
  longitude = parseFloat(longitude);

  if (isNaN(latitude) || isNaN(longitude)) {
    throw new functions.https.HttpsError('invalid-argument', 'Latitude and longitude must be valid numbers.');
  }

  try {
    const apiKey = await getApiKey();
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${latitude}&lon=${longitude}&appid=${apiKey}`;
    const response = await axios.get(url);
    return response.data;
  } catch (error) {
    console.error('Error fetching weather data:', error.message);
    throw new functions.https.HttpsError('internal', 'Failed to fetch weather data.');
  }
});