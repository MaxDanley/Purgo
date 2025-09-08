const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Set global options for cost control
setGlobalOptions({maxInstances: 10});

// MARK: - Friend Request Notifications
exports.sendNotification = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const notification = event.data.data();
      console.log("📱 Processing notification:", notification);

      try {
        if (notification.type === "friend_request") {
          await sendFriendRequestNotification(notification);
        }

        // Delete the processed notification document
        await event.data.ref.delete();
        console.log("✅ Notification processed and deleted");
      } catch (error) {
        console.error("❌ Error processing notification:", error);
      }
    },
);

/**
 * Send friend request notification
 * @param {Object} notification - The notification data
 */
async function sendFriendRequestNotification(notification) {
  const message = {
    token: notification.recipientToken,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: {
      type: "friend_request",
      senderId: notification.data.senderId || "",
      senderName: notification.senderName || "",
    },
    apns: {
      payload: {
        aps: {
          "sound": "default",
          "badge": 1,
          "content-available": 1,
          "category": "FRIEND_REQUEST",
        },
      },
    },
  };

  try {
    const response = await messaging.send(message);
    console.log("✅ Friend request notification sent:", response);
  } catch (error) {
    console.error("❌ Error sending friend request notification:", error);
  }
}

// MARK: - Leaderboard Notifications (Weekly)
exports.weeklyLeaderboardNotifications = onSchedule({
  schedule: "0 0 * * 1", // Every Monday at midnight UTC
  timeZone: "UTC",
}, async (event) => {
  console.log("📊 Running weekly leaderboard notifications...");

  try {
    await processLeaderboardNotifications("weekly");
  } catch (error) {
    console.error("❌ Error in weekly leaderboard notifications:", error);
  }
});

// MARK: - Leaderboard Notifications (Monthly)
exports.monthlyLeaderboardNotifications = onSchedule({
  schedule: "0 0 1 * *", // First day of every month at midnight UTC
  timeZone: "UTC",
}, async (event) => {
  console.log("📊 Running monthly leaderboard notifications...");

  try {
    await processLeaderboardNotifications("monthly");
  } catch (error) {
    console.error("❌ Error in monthly leaderboard notifications:", error);
  }
});

/**
 * Process leaderboard notifications for a given period
 * @param {string} period - 'weekly' or 'monthly'
 */
async function processLeaderboardNotifications(period) {
  const scopes = ["town", "state", "country"];

  for (const scope of scopes) {
    console.log(`📊 Processing ${period} ${scope} leaderboard...`);

    try {
      // Get all users with location data
      const usersSnapshot = await db.collection("users")
          .where("location", "!=", null)
          .get();

      if (usersSnapshot.empty) {
        console.log(`No users found for ${scope} leaderboard`);
        continue;
      }

      // Group users by location scope
      const locationGroups = {};

      usersSnapshot.docs.forEach((doc) => {
        const user = doc.data();
        const location = user.location;

        if (!location) return;

        let groupKey;
        switch (scope) {
          case "town":
            groupKey = `${location.city}, ${location.state}, ` +
              `${location.country}`;
            break;
          case "state":
            groupKey = `${location.state}, ${location.country}`;
            break;
          case "country":
            groupKey = location.country;
            break;
        }

        if (!locationGroups[groupKey]) {
          locationGroups[groupKey] = [];
        }

        locationGroups[groupKey].push({
          id: doc.id,
          ...user,
        });
      });

      // Process each location group
      for (const [locationKey, users] of
        Object.entries(locationGroups)) {
        if (users.length < 2) continue; // Need at least 2 users for rankings

        await processLocationGroup(users, locationKey, scope, period);
      }
    } catch (error) {
      console.error(`❌ Error processing ${period} ${scope} ` +
        `leaderboard:`, error);
    }
  }
}

/**
 * Process a location group for leaderboard notifications
 * @param {Array} users - Users in this location
 * @param {string} locationKey - Location identifier
 * @param {string} scope - town/state/country
 * @param {string} period - weekly/monthly
 */
async function processLocationGroup(users, locationKey,
    scope, period) {
  console.log(`📊 Processing ${locationKey} with ${users.length} users`);

  // Calculate period dates
  const now = new Date();
  let startDate; let endDate;

  if (period === "weekly") {
    // Last Monday to Sunday
    const lastMonday = new Date(now);
    lastMonday.setDate(now.getDate() - now.getDay() - 6);
    lastMonday.setHours(0, 0, 0, 0);

    startDate = lastMonday;
    endDate = new Date(lastMonday);
    endDate.setDate(lastMonday.getDate() + 6);
    endDate.setHours(23, 59, 59, 999);
  } else {
    // Last month
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0);
    lastMonthEnd.setHours(23, 59, 59, 999);

    startDate = lastMonth;
    endDate = lastMonthEnd;
  }

  // Get sessions for this period for all users
  const userStats = [];

  for (const user of users) {
    try {
      const sessionsSnapshot = await db.collection("sessions")
          .where("userId", "==", user.id)
          .where("completedAt", ">=", startDate)
          .where("completedAt", "<=", endDate)
          .get();

      const sessions = sessionsSnapshot.docs.map((doc) => doc.data());
      const totalSessions = sessions.length;
      const totalTime = sessions.reduce((sum, session) =>
        sum + (session.duration || 0), 0);

      userStats.push({
        user,
        totalSessions,
        totalTime,
        // Sessions worth 100 points, minutes worth 1 point
        score: totalSessions * 100 + totalTime / 60,
      });
    } catch (error) {
      console.error(`❌ Error getting sessions for user ${user.id}:`, error);
    }
  }

  // Sort by score (descending)
  userStats.sort((a, b) => b.score - a.score);

  // Send notifications to top 3
  const topUsers = userStats.slice(0, 3);

  for (let i = 0; i < topUsers.length; i++) {
    const userStat = topUsers[i];
    const rank = i + 1;
    const user = userStat.user;

    if (!user.fcmToken) {
      console.log(`No FCM token for user ${user.id}`);
      continue;
    }

    try {
      await sendLeaderboardNotification(user, rank, scope,
          period, locationKey, userStat);
    } catch (error) {
      console.error(`❌ Error sending notification to user ${user.id}:`, error);
    }
  }
}

/**
 * Send leaderboard notification to a user
 * @param {Object} user - User object
 * @param {number} rank - User's rank (1, 2, 3)
 * @param {string} scope - town/state/country
 * @param {string} period - weekly/monthly
 * @param {string} locationKey - Location identifier
 * @param {Object} userStats - User's stats for the period
 */
async function sendLeaderboardNotification(user, rank, scope,
    period, locationKey, userStats) {
  const ordinals = ["", "1st", "2nd", "3rd"];
  const scopeNames = {
    "town": "locally",
    "state": "in your state",
    "country": "in your country",
  };

  const rankText = ordinals[rank] || `${rank}th`;
  const scopeText = scopeNames[scope] || scope;
  const periodText = period === "weekly" ? "this week" : "this month";

  const title = `🏆 ${rankText} Place ` +
    `${period === "weekly" ? "This Week" : "This Month"}!`;
  const body = `Great job! You placed ${rankText} ${periodText} ` +
    `in sauna sessions ${scopeText}! Keep it up!`;

  const message = {
    token: user.fcmToken,
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: "leaderboard_ranking",
      rank: rank.toString(),
      scope: scope,
      period: period,
      location: locationKey,
      sessions: userStats.totalSessions.toString(),
      // minutes
      totalTime: Math.round(userStats.totalTime / 60).toString(),
    },
    apns: {
      payload: {
        aps: {
          "sound": "default",
          "badge": 1,
          "content-available": 1,
          "category": "LEADERBOARD",
        },
      },
    },
  };

  try {
    const response = await messaging.send(message);
    console.log(`✅ Leaderboard notification sent to ` +
      `${user.displayName} (${rankText} place):`, response);
  } catch (error) {
    console.error(`❌ Error sending leaderboard notification to ` +
      `${user.displayName}:`, error);
  }
}

