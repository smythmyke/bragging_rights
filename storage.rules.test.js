/**
 * Storage Security Rules Test Suite
 * Tests Firebase Storage security rules for the Bragging Rights app
 */

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { initializeTestEnvironment, cleanup } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

let testEnv;

describe('Firebase Storage Security Rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'bragging-rights-test',
      storage: {
        rules: fs.readFileSync('storage.rules', 'utf8'),
        host: 'localhost',
        port: 9199
      }
    });
  });

  after(async () => {
    await cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
  });

  describe('User Avatars (/avatars)', () => {
    it('should allow users to upload their own avatar', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('avatars/alice/profile.jpg');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should prevent users from uploading to another user avatar folder', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('avatars/bob/profile.jpg');
      
      await assertFails(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should enforce 5MB size limit for avatars', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('avatars/alice/profile.jpg');
      
      // Create a file larger than 5MB
      const largeFile = new Uint8Array(6 * 1024 * 1024);
      
      await assertFails(
        file.put(largeFile, {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should only allow image files for avatars', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('avatars/alice/document.pdf');
      
      await assertFails(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'application/pdf'
        })
      );
    });

    it('should allow public read access to avatars', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthStorage = unauth.storage();
      const file = unauthStorage.ref('avatars/alice/profile.jpg');
      
      await assertSucceeds(
        file.getDownloadURL()
      );
    });

    it('should allow users to delete their own avatar', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('avatars/alice/profile.jpg');
      
      // First upload
      await file.put(new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg'
      });
      
      // Then delete
      await assertSucceeds(file.delete());
    });
  });

  describe('Team Logos (/teams)', () => {
    it('should allow public read access to team logos', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthStorage = unauth.storage();
      const file = unauthStorage.ref('teams/nba/lakers/logo.png');
      
      await assertSucceeds(
        file.getDownloadURL()
      );
    });

    it('should prevent regular users from uploading team logos', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('teams/nba/lakers/logo.png');
      
      await assertFails(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/png'
        })
      );
    });

    it('should allow admins to upload team logos', async () => {
      const admin = testEnv.authenticatedContext('admin', { admin: true });
      const adminStorage = admin.storage();
      const file = adminStorage.ref('teams/nba/lakers/logo.png');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/png'
        })
      );
    });
  });

  describe('Pool Images (/pools)', () => {
    it('should allow authenticated users to upload pool covers', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('pools/pool123/cover/image.jpg');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should enforce 3MB limit for pool covers', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('pools/pool123/cover/image.jpg');
      
      const largeFile = new Uint8Array(4 * 1024 * 1024);
      
      await assertFails(
        file.put(largeFile, {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should require authentication to view pool images', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthStorage = unauth.storage();
      const file = unauthStorage.ref('pools/pool123/cover/image.jpg');
      
      await assertFails(
        file.getDownloadURL()
      );
    });
  });

  describe('Verification Documents (/verification)', () => {
    it('should allow users to upload their own verification docs', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('verification/alice/id/drivers_license.jpg');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should prevent users from viewing others verification docs', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('verification/bob/id/drivers_license.jpg');
      
      await assertFails(
        file.getDownloadURL()
      );
    });

    it('should allow admins to view any verification docs', async () => {
      const admin = testEnv.authenticatedContext('admin', { admin: true });
      const adminStorage = admin.storage();
      const file = adminStorage.ref('verification/alice/id/drivers_license.jpg');
      
      await assertSucceeds(
        file.getDownloadURL()
      );
    });

    it('should prevent updates to verification docs', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('verification/alice/id/drivers_license.jpg');
      
      // Upload first
      await file.put(new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg'
      });
      
      // Try to update - should fail
      await assertFails(
        file.put(new Uint8Array([4, 5, 6]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should enforce 10MB limit for verification docs', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('verification/alice/id/document.pdf');
      
      const largeFile = new Uint8Array(11 * 1024 * 1024);
      
      await assertFails(
        file.put(largeFile, {
          contentType: 'application/pdf'
        })
      );
    });
  });

  describe('Temporary Uploads (/temp)', () => {
    it('should allow users to upload to their temp area', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('temp/alice/session123/temp.jpg');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should prevent access to other users temp files', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('temp/bob/session456/temp.jpg');
      
      await assertFails(
        file.getDownloadURL()
      );
    });

    it('should prevent updates to temp files', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('temp/alice/session123/temp.jpg');
      
      // Upload first
      await file.put(new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg'
      });
      
      // Try to update - should fail
      await assertFails(
        file.put(new Uint8Array([4, 5, 6]), {
          contentType: 'image/jpeg'
        })
      );
    });
  });

  describe('Chat Attachments (/chat)', () => {
    it('should allow authenticated users to upload chat attachments', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('chat/pool123/messages/msg456/image.jpg');
      
      await assertSucceeds(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should enforce 5MB limit for chat attachments', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('chat/pool123/messages/msg456/image.jpg');
      
      const largeFile = new Uint8Array(6 * 1024 * 1024);
      
      await assertFails(
        file.put(largeFile, {
          contentType: 'image/jpeg'
        })
      );
    });

    it('should require authentication to view chat attachments', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthStorage = unauth.storage();
      const file = unauthStorage.ref('chat/pool123/messages/msg456/image.jpg');
      
      await assertFails(
        file.getDownloadURL()
      );
    });
  });

  describe('App Assets (/app_assets)', () => {
    it('should allow public read access to app assets', async () => {
      const unauth = testEnv.unauthenticatedContext();
      const unauthStorage = unauth.storage();
      const file = unauthStorage.ref('app_assets/icons/app_icon.png');
      
      await assertSucceeds(
        file.getDownloadURL()
      );
    });

    it('should prevent regular users from uploading app assets', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('app_assets/icons/new_icon.png');
      
      await assertFails(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'image/png'
        })
      );
    });
  });

  describe('Default Deny Rule', () => {
    it('should deny access to undefined paths', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('random/path/file.txt');
      
      await assertFails(
        file.put(new Uint8Array([1, 2, 3]), {
          contentType: 'text/plain'
        })
      );
    });

    it('should deny read access to undefined paths', async () => {
      const alice = testEnv.authenticatedContext('alice');
      const aliceStorage = alice.storage();
      const file = aliceStorage.ref('undefined/location/file.jpg');
      
      await assertFails(
        file.getDownloadURL()
      );
    });
  });
});