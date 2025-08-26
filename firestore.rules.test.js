// firestore.rules.test.js
// Run with: npm test or firebase emulators:exec --only firestore "npm test"

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { initializeTestEnvironment, cleanup } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

describe('Firestore Security Rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'bragging-rights-test',
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
        host: 'localhost',
        port: 8080
      }
    });
  });

  after(async () => {
    await cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe('Users Collection', () => {
    it('should allow users to read their own profile', async () => {
      const alice = testEnv.authenticatedContext('alice', { email: 'alice@test.com' });
      const aliceDb = alice.firestore();
      
      // Create Alice's profile
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('alice').set({
          uid: 'alice',
          email: 'alice@test.com',
          displayName: 'Alice'
        });
      });

      // Alice should be able to read her own profile
      await assertSucceeds(
        aliceDb.collection('users').doc('alice').get()
      );
    });

    it('should prevent users from reading other profiles', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      // Alice should NOT be able to read Bob's profile
      await assertFails(
        aliceDb.collection('users').doc('bob').get()
      );
    });

    it('should prevent users from modifying wallet balance', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      // Alice should NOT be able to modify her wallet
      await assertFails(
        aliceDb.collection('users').doc('alice')
          .collection('wallet').doc('current')
          .update({ balance: 9999 })
      );
    });

    it('should allow users to update their own profile except protected fields', async () => {
      const alice = testEnv.authenticatedContext('alice', { email: 'alice@test.com' });
      const aliceDb = alice.firestore();

      // Set up Alice's profile
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('alice').set({
          uid: 'alice',
          email: 'alice@test.com',
          displayName: 'Alice',
          createdAt: new Date()
        });
      });

      // Should allow updating display name
      await assertSucceeds(
        aliceDb.collection('users').doc('alice').update({
          displayName: 'Alice Updated'
        })
      );

      // Should NOT allow updating uid
      await assertFails(
        aliceDb.collection('users').doc('alice').update({
          uid: 'different-uid'
        })
      );
    });
  });

  describe('Bets Collection', () => {
    beforeEach(async () => {
      // Setup test data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        
        // Create a game
        await db.collection('games').doc('game1').set({
          sport: 'NBA',
          status: 'scheduled',
          gameTime: new Date(Date.now() + 86400000) // Tomorrow
        });

        // Create user with wallet
        await db.collection('users').doc('alice').set({
          uid: 'alice',
          email: 'alice@test.com'
        });
        
        await db.collection('users').doc('alice')
          .collection('wallet').doc('current').set({
            balance: 500
          });
      });
    });

    it('should allow users to place valid bets', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertSucceeds(
        aliceDb.collection('bets').add({
          userId: 'alice',
          gameId: 'game1',
          betType: 'moneyline',
          selection: 'home',
          odds: -110,
          wagerAmount: 50,
          status: 'pending',
          placedAt: new Date()
        })
      );
    });

    it('should prevent bets over user balance', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('bets').add({
          userId: 'alice',
          gameId: 'game1',
          betType: 'moneyline',
          selection: 'home',
          odds: -110,
          wagerAmount: 600, // Over balance
          status: 'pending',
          placedAt: new Date()
        })
      );
    });

    it('should prevent bets on started games', async () => {
      // Update game to live status
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('games').doc('game1').update({
          status: 'live'
        });
      });

      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('bets').add({
          userId: 'alice',
          gameId: 'game1',
          betType: 'moneyline',
          selection: 'home',
          odds: -110,
          wagerAmount: 50,
          status: 'pending',
          placedAt: new Date()
        })
      );
    });

    it('should prevent users from modifying existing bets', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      // Create a bet with admin privileges
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('bets').doc('bet1').set({
          userId: 'alice',
          gameId: 'game1',
          wagerAmount: 50,
          status: 'pending'
        });
      });

      // Alice should NOT be able to modify her bet
      await assertFails(
        aliceDb.collection('bets').doc('bet1').update({
          wagerAmount: 100
        })
      );
    });
  });

  describe('Pools Collection', () => {
    it('should allow users to create pools', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertSucceeds(
        aliceDb.collection('pools').add({
          name: 'Test Pool',
          createdBy: 'alice',
          participants: [],
          totalPot: 0,
          status: 'open',
          buyIn: 50
        })
      );
    });

    it('should prevent creating pools with wrong creator ID', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('pools').add({
          name: 'Test Pool',
          createdBy: 'bob', // Wrong ID
          participants: [],
          totalPot: 0,
          status: 'open',
          buyIn: 50
        })
      );
    });

    it('should allow joining open pools', async () => {
      // Create a pool
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('pools').doc('pool1').set({
          name: 'Test Pool',
          createdBy: 'bob',
          participants: [],
          totalPot: 0,
          status: 'open',
          buyIn: 50
        });
      });

      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertSucceeds(
        aliceDb.collection('pools').doc('pool1').update({
          participants: ['alice'],
          totalPot: 50
        })
      );
    });
  });

  describe('Games Collection', () => {
    it('should allow authenticated users to read games', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertSucceeds(
        aliceDb.collection('games').get()
      );
    });

    it('should prevent unauthenticated users from reading games', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthDb = unauth.firestore();

      await assertFails(
        unauthDb.collection('games').get()
      );
    });

    it('should prevent regular users from creating games', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('games').add({
          sport: 'NBA',
          homeTeam: 'Lakers',
          awayTeam: 'Celtics'
        })
      );
    });
  });

  describe('Transactions Collection', () => {
    it('should allow users to read their own transactions', async () => {
      // Create a transaction
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('transactions').doc('trans1').set({
          userId: 'alice',
          type: 'wager',
          amount: 50
        });
      });

      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertSucceeds(
        aliceDb.collection('transactions').doc('trans1').get()
      );
    });

    it('should prevent users from creating transactions', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('transactions').add({
          userId: 'alice',
          type: 'deposit',
          amount: 1000
        })
      );
    });
  });

  describe('Leaderboards Collection', () => {
    it('should allow public read access', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthDb = unauth.firestore();

      await assertSucceeds(
        unauthDb.collection('leaderboards').get()
      );
    });

    it('should prevent writes to leaderboards', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceDb = alice.firestore();

      await assertFails(
        aliceDb.collection('leaderboards').doc('weekly').set({
          rankings: []
        })
      );
    });
  });
});