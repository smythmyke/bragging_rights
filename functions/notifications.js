/**
 * Push Notification Cloud Functions for Bragging Rights App
 * Handles FCM notifications for various app events
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Ensure Firebase is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();
const FieldValue = admin.firestore.FieldValue;

// Notification Types
const NOTIFICATION_TYPES = {
  BET_WON: 'bet_won',
  BET_LOST: 'bet_lost',
  WEEKLY_ALLOWANCE: 'weekly_allowance',
  POOL_INVITATION: 'pool_invitation',
  POOL_WON: 'pool_won',
  FRIEND_REQUEST: 'friend_request',
  GAME_REMINDER: 'game_reminder',
  ACHIEVEMENT_UNLOCKED: 'achievement_unlocked',
  LEADERBOARD_RANK: 'leaderboard_rank'
};

// ============================================
// TRIGGERED NOTIFICATIONS
// ============================================

/**
 * Send notification when a bet is settled
 */
exports.onBetSettledNotification = functions.firestore
  .document('bets/{betId}')
  .onUpdate(async (change, context) => {
    const previousData = change.before.data();
    const currentData = change.after.data();
    
    // Only send notification if bet just got settled
    if (previousData.status === 'pending' && 
        (currentData.status === 'won' || currentData.status === 'lost')) {
      
      const userId = currentData.userId;
      const betId = context.params.betId;
      
      try {
        if (currentData.status === 'won') {
          await sendBetWonNotification(userId, currentData);
        } else if (currentData.status === 'lost') {
          await sendBetLostNotification(userId, currentData);
        }
      } catch (error) {
        console.error(`Error sending bet settlement notification:`, error);
      }
    }
    
    return null;
  });

/**
 * Send notification for pool invitations
 */
exports.onPoolInvitation = functions.firestore
  .document('pools/{poolId}/invitations/{invitationId}')
  .onCreate(async (snap, context) => {
    const invitation = snap.data();
    const poolId = context.params.poolId;
    
    try {
      await sendPoolInvitationNotification(invitation.inviteeId, poolId, invitation);
    } catch (error) {
      console.error(`Error sending pool invitation notification:`, error);
    }
    
    return null;
  });

/**
 * Send notification when user receives weekly allowance
 */
exports.onWeeklyAllowanceNotification = functions.firestore
  .document('transactions/{transactionId}')
  .onCreate(async (snap, context) => {
    const transaction = snap.data();
    
    if (transaction.type === 'allowance') {
      try {
        await sendWeeklyAllowanceNotification(transaction.userId, transaction.amount);
      } catch (error) {
        console.error(`Error sending allowance notification:`, error);
      }
    }
    
    return null;
  });

/**
 * Send notification for friend requests
 */
exports.onFriendRequest = functions.firestore
  .document('users/{userId}/friendRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();
    const userId = context.params.userId;
    
    try {
      await sendFriendRequestNotification(userId, request);
    } catch (error) {
      console.error(`Error sending friend request notification:`, error);
    }
    
    return null;
  });

/**
 * Send notification when user achieves a new rank
 */
exports.onLeaderboardRankChange = functions.firestore
  .document('leaderboards/realtime/users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const previousData = change.before.data();
    const currentData = change.after.data();
    
    // Check for significant rank improvement
    const previousProfit = previousData.profit || 0;
    const currentProfit = currentData.profit || 0;
    
    if (currentProfit > previousProfit && currentProfit > 100) {
      try {
        await sendLeaderboardNotification(userId, currentData);
      } catch (error) {
        console.error(`Error sending leaderboard notification:`, error);
      }
    }
    
    return null;
  });

// ============================================
// SCHEDULED NOTIFICATIONS
// ============================================

/**
 * Send game reminders 30 minutes before game start
 */
exports.sendGameReminders = functions.pubsub
  .schedule('*/15 * * * *') // Run every 15 minutes
  .onRun(async (context) => {
    const now = new Date();
    const thirtyMinutesFromNow = new Date(now.getTime() + 30 * 60000);
    const fortyFiveMinutesFromNow = new Date(now.getTime() + 45 * 60000);
    
    try {
      // Get games starting in the next 30-45 minutes window
      const gamesSnapshot = await db.collection('games')
        .where('startTime', '>=', thirtyMinutesFromNow)
        .where('startTime', '<=', fortyFiveMinutesFromNow)
        .where('reminderSent', '!=', true)
        .get();
      
      for (const gameDoc of gamesSnapshot.docs) {
        const game = gameDoc.data();
        await sendGameReminderNotifications(gameDoc.id, game);
        
        // Mark reminder as sent
        await gameDoc.ref.update({
          reminderSent: true
        });
      }
      
      console.log(`Sent reminders for ${gamesSnapshot.size} games`);
    } catch (error) {
      console.error('Error sending game reminders:', error);
    }
    
    return null;
  });

// ============================================
// CORE NOTIFICATION FUNCTIONS
// ============================================

/**
 * Send bet won notification
 */
async function sendBetWonNotification(userId, betData) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken) return;
  
  const notification = {
    title: '🎉 Bet Won!',
    body: `Congratulations! You won ${betData.winAmount} BR on your ${betData.betType} bet!`,
    icon: '/icons/win.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.BET_WON,
      betId: betData.id,
      amount: String(betData.winAmount),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/bet-details'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

/**
 * Send bet lost notification
 */
async function sendBetLostNotification(userId, betData) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken || !user.notificationPreferences?.betLost) return;
  
  const notification = {
    title: 'Bet Settled',
    body: `Your ${betData.betType} bet of ${betData.wagerAmount} BR didn't win this time. Better luck next bet!`,
    icon: '/icons/loss.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.BET_LOST,
      betId: betData.id,
      amount: String(betData.wagerAmount),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/bet-details'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

/**
 * Send weekly allowance notification
 */
async function sendWeeklyAllowanceNotification(userId, amount) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken) return;
  
  const notification = {
    title: '💰 Weekly Allowance Received!',
    body: `Your ${amount} BR weekly allowance has been added to your wallet!`,
    icon: '/icons/money.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.WEEKLY_ALLOWANCE,
      amount: String(amount),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/wallet'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

/**
 * Send pool invitation notification
 */
async function sendPoolInvitationNotification(userId, poolId, invitation) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken) return;
  
  const pool = await getPoolData(poolId);
  const inviter = await getUserData(invitation.inviterId);
  
  const notification = {
    title: '🏊 Pool Invitation!',
    body: `${inviter?.displayName || 'A friend'} invited you to join "${pool?.name || 'a pool'}"`,
    icon: '/icons/pool.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.POOL_INVITATION,
      poolId: poolId,
      inviterId: invitation.inviterId,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/pool-invitation'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

/**
 * Send friend request notification
 */
async function sendFriendRequestNotification(userId, request) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken) return;
  
  const requester = await getUserData(request.fromUserId);
  
  const notification = {
    title: '👥 New Friend Request!',
    body: `${requester?.displayName || 'Someone'} wants to be your friend!`,
    icon: '/icons/friend.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.FRIEND_REQUEST,
      requesterId: request.fromUserId,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/friend-requests'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

/**
 * Send game reminder notifications
 */
async function sendGameReminderNotifications(gameId, gameData) {
  // Get all users with pending bets on this game
  const betsSnapshot = await db.collection('bets')
    .where('gameId', '==', gameId)
    .where('status', '==', 'pending')
    .get();
  
  const userIds = new Set();
  betsSnapshot.docs.forEach(doc => {
    userIds.add(doc.data().userId);
  });
  
  for (const userId of userIds) {
    const user = await getUserData(userId);
    if (!user || !user.fcmToken || !user.notificationPreferences?.gameReminders) continue;
    
    const notification = {
      title: '🏈 Game Starting Soon!',
      body: `${gameData.homeTeam} vs ${gameData.awayTeam} starts in 30 minutes!`,
      icon: '/icons/game.png',
      badge: '/icons/badge.png',
      data: {
        type: NOTIFICATION_TYPES.GAME_REMINDER,
        gameId: gameId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: '/active-bets'
      }
    };
    
    await sendNotification(user.fcmToken, notification);
  }
}

/**
 * Send leaderboard achievement notification
 */
async function sendLeaderboardNotification(userId, rankData) {
  const user = await getUserData(userId);
  if (!user || !user.fcmToken) return;
  
  const notification = {
    title: '🏆 Leaderboard Achievement!',
    body: `You're climbing the ranks! Current profit: ${rankData.profit} BR`,
    icon: '/icons/trophy.png',
    badge: '/icons/badge.png',
    data: {
      type: NOTIFICATION_TYPES.LEADERBOARD_RANK,
      profit: String(rankData.profit),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: '/leaderboard'
    }
  };
  
  await sendNotification(user.fcmToken, notification);
  await saveNotificationToHistory(userId, notification);
}

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Send FCM notification
 */
async function sendNotification(token, notification) {
  try {
    const message = {
      token: token,
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.icon
      },
      data: notification.data,
      android: {
        priority: 'high',
        notification: {
          icon: 'ic_notification',
          color: '#FF6B6B',
          sound: 'default',
          channelId: 'bragging_rights_notifications'
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body
            },
            badge: 1,
            sound: 'default',
            contentAvailable: true
          }
        }
      }
    };
    
    const response = await messaging.send(message);
    console.log('Successfully sent notification:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification:', error);
    
    // If token is invalid, remove it
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      await removeInvalidToken(token);
    }
    
    throw error;
  }
}

/**
 * Save notification to user's history
 */
async function saveNotificationToHistory(userId, notification) {
  try {
    await db.collection('users').doc(userId)
      .collection('notifications').add({
        ...notification,
        read: false,
        timestamp: FieldValue.serverTimestamp()
      });
  } catch (error) {
    console.error('Error saving notification to history:', error);
  }
}

/**
 * Get user data
 */
async function getUserData(userId) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc.data() : null;
  } catch (error) {
    console.error('Error getting user data:', error);
    return null;
  }
}

/**
 * Get pool data
 */
async function getPoolData(poolId) {
  try {
    const poolDoc = await db.collection('pools').doc(poolId).get();
    return poolDoc.exists ? poolDoc.data() : null;
  } catch (error) {
    console.error('Error getting pool data:', error);
    return null;
  }
}

/**
 * Remove invalid FCM token
 */
async function removeInvalidToken(token) {
  try {
    // Find user with this token
    const usersSnapshot = await db.collection('users')
      .where('fcmToken', '==', token)
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      await userDoc.ref.update({
        fcmToken: FieldValue.delete()
      });
      console.log(`Removed invalid token for user ${userDoc.id}`);
    }
  } catch (error) {
    console.error('Error removing invalid token:', error);
  }
}

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Register or update FCM token
 */
exports.registerFCMToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const { token, platform } = data;
  
  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'FCM token is required'
    );
  }
  
  try {
    await db.collection('users').doc(userId).update({
      fcmToken: token,
      fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
      platform: platform || 'unknown'
    });
    
    return {
      success: true,
      message: 'FCM token registered successfully'
    };
  } catch (error) {
    console.error('Error registering FCM token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to register FCM token'
    );
  }
});

/**
 * Update notification preferences
 */
exports.updateNotificationPreferences = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const { preferences } = data;
  
  if (!preferences) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preferences are required'
    );
  }
  
  try {
    await db.collection('users').doc(userId).update({
      notificationPreferences: preferences,
      notificationPreferencesUpdatedAt: FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      message: 'Notification preferences updated successfully'
    };
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update notification preferences'
    );
  }
});

/**
 * Send test notification (Admin only)
 */
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
  // Verify admin status
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can send test notifications'
    );
  }
  
  const { userId, title, body } = data;
  
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId, title, and body are required'
    );
  }
  
  try {
    const user = await getUserData(userId);
    
    if (!user || !user.fcmToken) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User does not have a registered FCM token'
      );
    }
    
    const notification = {
      title: title,
      body: body,
      icon: '/icons/test.png',
      badge: '/icons/badge.png',
      data: {
        type: 'test',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: '/home'
      }
    };
    
    await sendNotification(user.fcmToken, notification);
    
    return {
      success: true,
      message: 'Test notification sent successfully'
    };
  } catch (error) {
    console.error('Error sending test notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send test notification'
    );
  }
});

/**
 * Mark notifications as read
 */
exports.markNotificationsRead = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const { notificationIds } = data;
  
  if (!notificationIds || !Array.isArray(notificationIds)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'notificationIds array is required'
    );
  }
  
  try {
    const batch = db.batch();
    
    for (const notificationId of notificationIds) {
      const notificationRef = db.collection('users').doc(userId)
        .collection('notifications').doc(notificationId);
      
      batch.update(notificationRef, {
        read: true,
        readAt: FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    
    return {
      success: true,
      message: `Marked ${notificationIds.length} notifications as read`
    };
  } catch (error) {
    console.error('Error marking notifications as read:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to mark notifications as read'
    );
  }
});

console.log('Notification Cloud Functions initialized');