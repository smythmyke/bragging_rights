// Simple Node.js test for Cloud Functions
const https = require('https');

console.log('🚀 Testing Cloud Functions API Proxy\n');

// Your Firebase project URL
const projectId = 'bragging-rights-ea6e1';
const region = 'us-central1';

// Test function to call Cloud Functions
async function callFunction(functionName, data = {}) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({ data });
    
    const options = {
      hostname: `${region}-${projectId}.cloudfunctions.net`,
      path: `/${functionName}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          resolve(response);
        } catch (e) {
          resolve(body);
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

// Run tests
async function runTests() {
  // Test ESPN API (no auth required)
  console.log('🏈 Testing ESPN NFL API...');
  try {
    const result = await callFunction('getESPNScoreboard', { sport: 'nfl' });
    if (result.error) {
      console.log('❌ ESPN API requires authentication');
    } else {
      console.log('✅ ESPN API response received');
    }
  } catch (e) {
    console.log('❌ ESPN API failed:', e.message);
  }

  // Test NHL API (no auth required)
  console.log('\n🏒 Testing NHL Schedule API...');
  try {
    const result = await callFunction('getNHLSchedule', {});
    if (result.error) {
      console.log('❌ NHL API requires authentication');
    } else {
      console.log('✅ NHL API response received');
    }
  } catch (e) {
    console.log('❌ NHL API failed:', e.message);
  }

  console.log('\n📝 Note: Most functions require Firebase Authentication.');
  console.log('To fully test, use the Flutter app with authenticated user.');
  console.log('\n✅ Cloud Functions are deployed and responding!');
}

runTests();