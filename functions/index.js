const functions = require('firebase-functions');
const tf = require('@tensorflow/tfjs-node');
const sharp = require('sharp');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

exports.detectDisease = functions.https.onRequest(async (req, res) => {
  try {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.status(204).send('');
      return;
    }

    // Check request method
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const { image, isUrl } = req.body;
    
    if (!image) {
      res.status(400).send('No image provided');
      return;
    }

    // Load and preprocess image
    let imageBuffer;
    if (isUrl) {
      const response = await fetch(image);
      imageBuffer = await response.buffer();
    } else {
      imageBuffer = Buffer.from(image, 'base64');
    }

    // Resize image to model input size
    const preprocessedImage = await sharp(imageBuffer)
      .resize(640, 640, { fit: 'contain', background: { r: 0, g: 0, b: 0 } })
      .raw()
      .toBuffer();

    // Load model
    const model = await tf.node.loadSavedModel('model');
    
    // Convert image to tensor
    const tensor = tf.node.decodeImage(preprocessedImage, 3)
      .expandDims(0)
      .div(255.0);

    // Run inference
    const predictions = await model.predict(tensor);
    const data = await predictions.data();

    // Process results (similar to native implementation)
    let maxConfidence = 0;
    let maxClassIndex = 0;
    
    for (let i = 0; i < data.length; i += 85) {
      const confidence = data[i + 4];
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        maxClassIndex = i;
      }
    }

    // Get disease label
    const labels = ['algal-leaf', 'brown-blight', 'grey-blight']; // Update with your labels
    
    res.json({
      disease: labels[Math.floor(maxClassIndex / 85)],
      confidence: maxConfidence,
      bbox: [
        data[maxClassIndex],
        data[maxClassIndex + 1],
        data[maxClassIndex + 2],
        data[maxClassIndex + 3]
      ]
    });

    // Cleanup
    tensor.dispose();
    predictions.dispose();
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send('Internal Server Error: ' + error.message);
  }
});

// Triggered when a new farmer report is created
exports.processFarmerReport = functions.firestore
  .document('farmer_reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const reportId = context.params.reportId;
      
      console.log(`Processing farmer report: ${reportId}`);
      
      // Update regional analysis
      await updateRegionalAnalysis(reportData);
      
      // Check for outbreak conditions
      await checkForOutbreaks(reportData);
      
      // Update analytics
      await updateAnalytics(reportData);
      
      console.log(`Successfully processed farmer report: ${reportId}`);
    } catch (error) {
      console.error('Error processing farmer report:', error);
    }
  });

// Update regional analysis when new reports come in
async function updateRegionalAnalysis(reportData) {
  try {
    const regionId = await getRegionIdFromCoordinates(
      reportData.latitude, 
      reportData.longitude
    );
    
    if (!regionId) {
      console.log('No region found for coordinates:', reportData.latitude, reportData.longitude);
      return;
    }
    
    const regionRef = db.collection('regional_analysis').doc(regionId);
    
    await db.runTransaction(async (transaction) => {
      const regionDoc = await transaction.get(regionRef);
      
      if (!regionDoc.exists) {
        // Create new regional analysis
        const newRegionData = {
          regionId: regionId,
          regionName: await getRegionName(regionId),
          country: 'Sri Lanka', // Default
          latitude: reportData.latitude,
          longitude: reportData.longitude,
          totalFarmers: 1,
          activeFarmers: 1,
          diseaseOutbreaks: {
            [reportData.disease]: {
              disease: reportData.disease,
              totalCases: 1,
              newCasesThisWeek: 1,
              averageConfidence: reportData.confidence,
              firstDetected: admin.firestore.Timestamp.fromDate(new Date()),
              lastDetected: admin.firestore.Timestamp.fromDate(new Date()),
              affectedFarms: [reportData.farmLocation],
              severity: calculateSeverity(1, reportData.confidence),
              weeklyTrend: {
                [getCurrentWeek()]: 1
              }
            }
          },
          riskLevel: calculateRiskLevel(1, reportData.confidence),
          lastUpdated: admin.firestore.Timestamp.fromDate(new Date()),
          affectedAreas: [reportData.farmLocation],
          cropTypes: {
            [reportData.cropType]: 1
          }
        };
        
        transaction.set(regionRef, newRegionData);
      } else {
        // Update existing regional analysis
        const regionData = regionDoc.data();
        const diseaseOutbreaks = regionData.diseaseOutbreaks || {};
        const currentDisease = diseaseOutbreaks[reportData.disease];
        
        if (currentDisease) {
          // Update existing disease outbreak
          currentDisease.totalCases += 1;
          currentDisease.newCasesThisWeek += 1;
          currentDisease.averageConfidence = 
            (currentDisease.averageConfidence * (currentDisease.totalCases - 1) + reportData.confidence) / currentDisease.totalCases;
          currentDisease.lastDetected = admin.firestore.Timestamp.fromDate(new Date());
          
          if (!currentDisease.affectedFarms.includes(reportData.farmLocation)) {
            currentDisease.affectedFarms.push(reportData.farmLocation);
          }
          
          currentDisease.severity = calculateSeverity(currentDisease.totalCases, currentDisease.averageConfidence);
          
          const currentWeek = getCurrentWeek();
          currentDisease.weeklyTrend[currentWeek] = (currentDisease.weeklyTrend[currentWeek] || 0) + 1;
        } else {
          // Create new disease outbreak
          diseaseOutbreaks[reportData.disease] = {
            disease: reportData.disease,
            totalCases: 1,
            newCasesThisWeek: 1,
            averageConfidence: reportData.confidence,
            firstDetected: admin.firestore.Timestamp.fromDate(new Date()),
            lastDetected: admin.firestore.Timestamp.fromDate(new Date()),
            affectedFarms: [reportData.farmLocation],
            severity: calculateSeverity(1, reportData.confidence),
            weeklyTrend: {
              [getCurrentWeek()]: 1
            }
          };
        }
        
        // Update region data
        const updatedRegionData = {
          ...regionData,
          activeFarmers: Math.max(regionData.activeFarmers || 0, 1),
          diseaseOutbreaks: diseaseOutbreaks,
          riskLevel: calculateRiskLevel(
            Object.values(diseaseOutbreaks).reduce((sum, outbreak) => sum + outbreak.totalCases, 0),
            Object.values(diseaseOutbreaks).reduce((sum, outbreak) => sum + outbreak.averageConfidence, 0) / Object.keys(diseaseOutbreaks).length
          ),
          lastUpdated: admin.firestore.Timestamp.fromDate(new Date()),
          affectedAreas: [...new Set([...(regionData.affectedAreas || []), reportData.farmLocation])],
          cropTypes: {
            ...(regionData.cropTypes || {}),
            [reportData.cropType]: (regionData.cropTypes?.[reportData.cropType] || 0) + 1
          }
        };
        
        transaction.update(regionRef, updatedRegionData);
      }
    });
    
    console.log(`Updated regional analysis for region: ${regionId}`);
  } catch (error) {
    console.error('Error updating regional analysis:', error);
  }
}

// Check for outbreak conditions and create alerts
async function checkForOutbreaks(reportData) {
  try {
    const regionId = await getRegionIdFromCoordinates(
      reportData.latitude, 
      reportData.longitude
    );
    
    if (!regionId) return;
    
    const regionDoc = await db.collection('regional_analysis').doc(regionId).get();
    if (!regionDoc.exists) return;
    
    const regionData = regionDoc.data();
    const diseaseOutbreaks = regionData.diseaseOutbreaks || {};
    const currentDisease = diseaseOutbreaks[reportData.disease];
    
    if (!currentDisease) return;
    
    // Check outbreak conditions
    const isOutbreak = 
      currentDisease.newCasesThisWeek >= 5 || // 5+ cases this week
      currentDisease.totalCases >= 10 || // 10+ total cases
      currentDisease.severity === 'Critical' || // Critical severity
      currentDisease.affectedFarms.length >= 3; // 3+ affected farms
    
    if (isOutbreak) {
      // Create or update outbreak alert
      const alertRef = db.collection('disease_outbreaks').doc(`${regionId}_${reportData.disease}`);
      
      const alertData = {
        regionId: regionId,
        regionName: regionData.regionName,
        disease: reportData.disease,
        severity: currentDisease.severity,
        totalCases: currentDisease.totalCases,
        newCasesThisWeek: currentDisease.newCasesThisWeek,
        affectedFarms: currentDisease.affectedFarms,
        firstDetected: currentDisease.firstDetected,
        lastUpdated: admin.firestore.Timestamp.fromDate(new Date()),
        status: 'Active',
        recommendations: generateRecommendations(reportData.disease, currentDisease.severity),
        coordinates: {
          latitude: regionData.latitude,
          longitude: regionData.longitude
        }
      };
      
      await alertRef.set(alertData, { merge: true });
      console.log(`Created outbreak alert for ${reportData.disease} in ${regionData.regionName}`);
    }
  } catch (error) {
    console.error('Error checking for outbreaks:', error);
  }
}

// Update analytics data
async function updateAnalytics(reportData) {
  try {
    const analyticsRef = db.collection('analytics').doc('global');
    
    await db.runTransaction(async (transaction) => {
      const analyticsDoc = await transaction.get(analyticsRef);
      
      const currentData = analyticsDoc.exists ? analyticsDoc.data() : {
        totalReports: 0,
        totalDiseases: {},
        regionalStats: {},
        weeklyTrends: {},
        lastUpdated: admin.firestore.Timestamp.fromDate(new Date())
      };
      
      // Update total reports
      currentData.totalReports += 1;
      
      // Update disease statistics
      currentData.totalDiseases[reportData.disease] = 
        (currentData.totalDiseases[reportData.disease] || 0) + 1;
      
      // Update regional statistics
      const regionId = await getRegionIdFromCoordinates(
        reportData.latitude, 
        reportData.longitude
      );
      
      if (regionId) {
        currentData.regionalStats[regionId] = currentData.regionalStats[regionId] || {
          totalReports: 0,
          diseases: {}
        };
        
        currentData.regionalStats[regionId].totalReports += 1;
        currentData.regionalStats[regionId].diseases[reportData.disease] = 
          (currentData.regionalStats[regionId].diseases[reportData.disease] || 0) + 1;
      }
      
      // Update weekly trends
      const currentWeek = getCurrentWeek();
      currentData.weeklyTrends[currentWeek] = currentData.weeklyTrends[currentWeek] || {
        totalReports: 0,
        diseases: {}
      };
      
      currentData.weeklyTrends[currentWeek].totalReports += 1;
      currentData.weeklyTrends[currentWeek].diseases[reportData.disease] = 
        (currentData.weeklyTrends[currentWeek].diseases[reportData.disease] || 0) + 1;
      
      currentData.lastUpdated = admin.firestore.Timestamp.fromDate(new Date());
      
      transaction.set(analyticsRef, currentData);
    });
    
    console.log('Updated analytics data');
  } catch (error) {
    console.error('Error updating analytics:', error);
  }
}

// Helper functions
async function getRegionIdFromCoordinates(latitude, longitude) {
  // This is a simplified implementation
  // In production, you'd use a proper geocoding service or predefined region boundaries
  const regions = [
    { id: 'colombo', name: 'Colombo', bounds: { north: 7.0, south: 6.8, east: 80.0, west: 79.8 } },
    { id: 'kandy', name: 'Kandy', bounds: { north: 7.3, south: 7.1, east: 80.7, west: 80.5 } },
    { id: 'nuwara_eliya', name: 'Nuwara Eliya', bounds: { north: 7.0, south: 6.8, east: 80.8, west: 80.6 } }
  ];
  
  for (const region of regions) {
    if (latitude >= region.bounds.south && latitude <= region.bounds.north &&
        longitude >= region.bounds.west && longitude <= region.bounds.east) {
      return region.id;
    }
  }
  
  return null;
}

async function getRegionName(regionId) {
  const regionNames = {
    'colombo': 'Colombo',
    'kandy': 'Kandy',
    'nuwara_eliya': 'Nuwara Eliya'
  };
  
  return regionNames[regionId] || 'Unknown Region';
}

function calculateSeverity(totalCases, averageConfidence) {
  if (totalCases >= 20 || averageConfidence >= 0.9) return 'Critical';
  if (totalCases >= 10 || averageConfidence >= 0.8) return 'High';
  if (totalCases >= 5 || averageConfidence >= 0.7) return 'Moderate';
  return 'Low';
}

function calculateRiskLevel(totalCases, averageConfidence) {
  // Calculate risk level from 0.0 to 1.0
  const caseFactor = Math.min(totalCases / 50, 1.0); // Normalize to 50 cases max
  const confidenceFactor = averageConfidence;
  
  return Math.min((caseFactor * 0.6 + confidenceFactor * 0.4), 1.0);
}

function getCurrentWeek() {
  const now = new Date();
  const startOfYear = new Date(now.getFullYear(), 0, 1);
  const days = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000));
  return Math.ceil((days + startOfYear.getDay() + 1) / 7);
}

function generateRecommendations(disease, severity) {
  const recommendations = {
    'algal-leaf': {
      'Low': ['Monitor affected areas', 'Improve air circulation'],
      'Moderate': ['Apply copper-based fungicides', 'Prune affected leaves'],
      'High': ['Apply systemic fungicides', 'Increase plant spacing'],
      'Critical': ['Immediate fungicide application', 'Consider crop rotation']
    },
    'brown-blight': {
      'Low': ['Remove infected leaves', 'Avoid overhead irrigation'],
      'Moderate': ['Apply copper fungicides', 'Improve drainage'],
      'High': ['Apply systemic fungicides', 'Reduce plant density'],
      'Critical': ['Emergency fungicide treatment', 'Isolate affected areas']
    },
    'grey-blight': {
      'Low': ['Remove infected parts', 'Improve ventilation'],
      'Moderate': ['Apply fungicides', 'Reduce humidity'],
      'High': ['Apply systemic fungicides', 'Increase spacing'],
      'Critical': ['Immediate treatment required', 'Consider replanting']
    }
  };
  
  return recommendations[disease]?.[severity] || ['Monitor the situation', 'Contact agricultural expert'];
} 