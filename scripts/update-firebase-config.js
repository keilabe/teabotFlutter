const fs = require('fs');
const path = require('path');

// Read the Flutter Firebase options file
const firebaseOptionsPath = path.join(__dirname, '../lib/firebase_options.dart');
const webConfigPath = path.join(__dirname, '../web/firebase-config.js');

try {
  const firebaseOptionsContent = fs.readFileSync(firebaseOptionsPath, 'utf8');
  
  // Extract web configuration values using regex
  const apiKeyMatch = firebaseOptionsContent.match(/apiKey: '([^']+)'/);
  const appIdMatch = firebaseOptionsContent.match(/appId: '([^']+)'/);
  const messagingSenderIdMatch = firebaseOptionsContent.match(/messagingSenderId: '([^']+)'/);
  const projectIdMatch = firebaseOptionsContent.match(/projectId: '([^']+)'/);
  const authDomainMatch = firebaseOptionsContent.match(/authDomain: '([^']+)'/);
  const storageBucketMatch = firebaseOptionsContent.match(/storageBucket: '([^']+)'/);
  const measurementIdMatch = firebaseOptionsContent.match(/measurementId: '([^']+)'/);
  
  if (!apiKeyMatch || !appIdMatch || !messagingSenderIdMatch || !projectIdMatch || !authDomainMatch || !storageBucketMatch) {
    throw new Error('Could not extract all required Firebase configuration values');
  }
  
  const firebaseConfig = {
    apiKey: apiKeyMatch[1],
    authDomain: authDomainMatch[1],
    projectId: projectIdMatch[1],
    storageBucket: storageBucketMatch[1],
    messagingSenderId: messagingSenderIdMatch[1],
    appId: appIdMatch[1],
    measurementId: measurementIdMatch ? measurementIdMatch[1] : undefined
  };
  
  // Generate the web configuration file content
  const webConfigContent = `// Firebase configuration for service worker
// This file is auto-generated from lib/firebase_options.dart
// Do not edit manually - run 'node scripts/update-firebase-config.js' to update

const firebaseConfig = ${JSON.stringify(firebaseConfig, null, 2)};

// Export for use in service worker
if (typeof module !== 'undefined' && module.exports) {
  module.exports = firebaseConfig;
}
`;
  
  // Write the configuration file
  fs.writeFileSync(webConfigPath, webConfigContent);
  
  console.log('✅ Firebase configuration updated successfully!');
  console.log(`📁 Updated: ${webConfigPath}`);
  
} catch (error) {
  console.error('❌ Error updating Firebase configuration:', error.message);
  process.exit(1);
} 