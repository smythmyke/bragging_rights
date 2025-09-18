const admin = require('firebase-admin');

// Initialize admin SDK with application default credentials
// This will use the credentials from Firebase CLI login
admin.initializeApp({
  projectId: 'bragging-rights-ea6e1'
});

const db = admin.firestore();

async function initializeBoxingCollections() {
  console.log('Initializing Boxing collections in Firestore...\n');

  try {
    // 1. Initialize metadata document
    console.log('1. Creating boxing_cache/metadata document...');
    await db.doc('boxing_cache/metadata').set({
      apiCallsThisMonth: 0,
      apiCallsRemaining: 100,
      lastUpdated: null,
      nextScheduledUpdate: new Date(Date.now() + 24 * 60 * 60 * 1000),
      monthStarted: admin.firestore.FieldValue.serverTimestamp(),
      cacheVersion: '1.0',
      initialized: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Boxing Data API cache metadata - tracks API usage and cache status'
    });
    console.log('   ✅ Metadata document created');

    // 2. Create sample structure for boxing_events collection
    console.log('\n2. Creating boxing_events collection structure...');
    const sampleEventRef = db.collection('boxing_events').doc('sample_structure');
    await sampleEventRef.set({
      _sample: true,
      _description: 'This is a sample structure document',
      title: 'Sample Event Title',
      date: admin.firestore.Timestamp.fromDate(new Date()),
      venue: 'Sample Venue',
      location: 'Sample Location',
      posterUrl: null,
      promotion: 'Sample Promotion',
      broadcasters: ['Sample Network'],
      source: 'boxing_data',
      hasFullData: true,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✅ boxing_events collection initialized');

    // 3. Create sample structure for boxing_fights collection
    console.log('\n3. Creating boxing_fights collection structure...');
    const sampleFightRef = db.collection('boxing_fights').doc('sample_structure');
    await sampleFightRef.set({
      _sample: true,
      _description: 'This is a sample structure document',
      title: 'Fighter A vs Fighter B',
      eventId: 'sample_event_id',
      fighters: {
        fighter_1: {
          fighter_id: 'sample_id_1',
          name: 'Fighter A',
          full_name: 'Fighter A Full Name'
        },
        fighter_2: {
          fighter_id: 'sample_id_2',
          name: 'Fighter B',
          full_name: 'Fighter B Full Name'
        }
      },
      division: 'Welterweight',
      scheduled_rounds: 12,
      titles: [],
      cardPosition: 1,
      status: 'upcoming',
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✅ boxing_fights collection initialized');

    // 4. Create sample structure for boxing_fighters collection
    console.log('\n4. Creating boxing_fighters collection structure...');
    const sampleFighterRef = db.collection('boxing_fighters').doc('sample_structure');
    await sampleFighterRef.set({
      _sample: true,
      _description: 'This is a sample structure document',
      name: 'Sample Fighter',
      nationality: 'United States',
      stats: {
        wins: 0,
        losses: 0,
        draws: 0,
        ko_wins: 0,
        total_bouts: 0
      },
      height: "5' 10\"",
      reach: "70\"",
      stance: 'Orthodox',
      division: 'Welterweight',
      titles: [],
      source: 'boxing_data',
      updatePriority: 3,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✅ boxing_fighters collection initialized');

    // 5. Create activity log collection
    console.log('\n5. Creating boxing_activity_log collection...');
    await db.collection('boxing_activity_log').add({
      status: 'initialized',
      message: 'Boxing collections initialized',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✅ boxing_activity_log collection created');

    // 6. Create errors collection
    console.log('\n6. Creating boxing_errors collection...');
    await db.collection('boxing_errors').add({
      service: 'initialization',
      error: 'No errors - initialization successful',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✅ boxing_errors collection created');

    console.log('\n✅ All Boxing collections initialized successfully!');
    console.log('\nNext steps:');
    console.log('1. The dailyBoxingUpdate function will run at 3 AM EST');
    console.log('2. To trigger an immediate update, you can manually run the function from Firebase Console');
    console.log('3. Monitor API usage in boxing_cache/metadata document');
    console.log('4. Check boxing_activity_log for update history');

    // Clean up sample documents after a delay
    console.log('\nNote: Sample structure documents will be deleted when real data is added.');

  } catch (error) {
    console.error('❌ Error initializing collections:', error);
  }

  process.exit(0);
}

// Run initialization
initializeBoxingCollections();