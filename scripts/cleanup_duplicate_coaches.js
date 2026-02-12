#!/usr/bin/env node

/**
 * Cleanup script for duplicate Sport Coach entries
 * 
 * This script will:
 * 1. Find the duplicate coaches
 * 2. Keep the first one and update its visibility to public
 * 3. Delete the second duplicate
 * 
 * Usage:
 *   node scripts/cleanup_duplicate_coaches.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
// Make sure you have GOOGLE_APPLICATION_CREDENTIALS set or provide service account
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'simon-7a833'
});

const db = admin.firestore();

async function cleanupDuplicates() {
  console.log('🔍 Searching for duplicate Sport Coach entries...\n');
  
  const duplicateIds = [
    'f19f06ee-ee24-4184-adf2-82d5da93dce3',
    '84090842-3c1c-486c-92d6-dc180a42c770'
  ];
  
  try {
    // Fetch both coaches
    const coaches = await Promise.all(
      duplicateIds.map(id => db.collection('coaches').doc(id).get())
    );
    
    // Display info
    coaches.forEach((doc, index) => {
      if (doc.exists) {
        const data = doc.data();
        console.log(`Coach ${index + 1}:`);
        console.log(`  ID: ${doc.id}`);
        console.log(`  Title: ${data.title}`);
        console.log(`  Promise: ${data.promise}`);
        console.log(`  Visibility: ${data.visibility}`);
        console.log(`  Created: ${data.created_at?.toDate()}`);
        console.log(`  Owner: ${data.owner_uid}`);
        console.log('');
      } else {
        console.log(`Coach ${index + 1}: Not found (ID: ${duplicateIds[index]})\n`);
      }
    });
    
    // Keep first, delete second
    const [first, second] = coaches;
    
    if (first.exists && second.exists) {
      console.log('📝 Action Plan:');
      console.log(`  1. Update ${first.id} visibility to "public"`);
      console.log(`  2. Delete ${second.id}\n`);
      
      // Update first coach to public
      await db.collection('coaches').doc(first.id).update({
        visibility: 'public',
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Updated ${first.id} to public`);
      
      // Delete second coach
      await db.collection('coaches').doc(second.id).delete();
      console.log(`✅ Deleted ${second.id}`);
      
      console.log('\n🎉 Cleanup complete!');
      console.log(`\nThe Sport Coach is now visible at:`);
      console.log(`  Coach ID: ${first.id}`);
      console.log(`  Visibility: public`);
    } else {
      console.log('⚠️  One or both coaches not found. Manual cleanup may be needed.');
    }
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

// Run cleanup
cleanupDuplicates()
  .then(() => {
    console.log('\n✨ Script completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
