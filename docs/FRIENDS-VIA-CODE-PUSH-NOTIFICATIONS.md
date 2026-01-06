# Friends via Code - Push Notification Payload Formats

## Overview

This document defines the exact payload formats for all push notifications in the Friends via Code feature. Includes structures for both iOS (APNs) and Android (FCM) platforms.

## Azure Notification Hubs Configuration

### Hub Setup
```json
{
  "notificationHubName": "nh-mybartenderai",
  "namespaceName": "nh-namespace-mybartenderai",
  "location": "South Central US",
  "sku": "Free",
  "platforms": {
    "apns": {
      "endpoint": "gateway.push.apple.com",
      "authentication": "certificate",
      "bundleId": "com.mybartender.ai"
    },
    "fcm": {
      "authentication": "serverKey",
      "packageName": "com.mybartender.ai"
    }
  }
}
```

### Registration Tags
```javascript
// User tags for targeting
[
  `user:${userId}`,           // Target specific user
  `tier:${userTier}`,        // Target by subscription tier
  `alias:${userAlias}`,      // Target by social alias
  `platform:${platform}`,    // ios or android
  `version:${appVersion}`    // Target specific app versions
]
```

## 1. Friend Request Accepted

### Trigger
When someone accepts your friend invitation

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "New Friend! 🎉",
      "subtitle": "@clever-dolphin-99",
      "body": "TestUser2 accepted your friend request",
      "sound": "default",
      "badge": 1
    },
    "category": "FRIEND_ACCEPTED",
    "thread-id": "friends"
  },
  "data": {
    "type": "friend_accepted",
    "friendId": "test-user-456",
    "friendAlias": "@clever-dolphin-99",
    "friendDisplayName": "TestUser2",
    "timestamp": "2025-11-14T10:30:00Z",
    "action": "view_profile"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "New Friend! 🎉",
    "body": "TestUser2 (@clever-dolphin-99) accepted your friend request",
    "icon": "ic_notification",
    "color": "#FF00FF",
    "sound": "default",
    "tag": "friend_accepted",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "friend_accepted",
    "friendId": "test-user-456",
    "friendAlias": "@clever-dolphin-99",
    "friendDisplayName": "TestUser2",
    "timestamp": "2025-11-14T10:30:00Z",
    "action": "view_profile",
    "navigate_to": "/social/friends/@clever-dolphin-99"
  },
  "android": {
    "priority": "high",
    "ttl": "86400s",
    "notification": {
      "channel_id": "social_channel",
      "notification_priority": "PRIORITY_HIGH"
    }
  }
}
```

### Flutter Handler
```dart
void handleFriendAccepted(Map<String, dynamic> data) {
  final friendAlias = data['friendAlias'];
  final friendDisplayName = data['friendDisplayName'];

  // Update local friends list
  friendsProvider.addFriend(Friend(
    id: data['friendId'],
    alias: friendAlias,
    displayName: friendDisplayName,
    friendsSince: DateTime.parse(data['timestamp'])
  ));

  // Navigate if app is in foreground
  if (data['action'] == 'view_profile') {
    router.go('/social/friends/$friendAlias');
  }
}
```

## 2. Recipe Shared with You

### Trigger
When a friend shares a recipe (internal share to friends)

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "New Recipe Share 🍹",
      "subtitle": "From @happy-penguin-42",
      "body": "CocktailMaster shared \"Margarita\" with you",
      "sound": "recipe_share.caf",
      "badge": 1
    },
    "category": "RECIPE_SHARED",
    "thread-id": "shares",
    "mutable-content": 1
  },
  "data": {
    "type": "recipe_shared",
    "senderId": "test-user-123",
    "senderAlias": "@happy-penguin-42",
    "senderDisplayName": "CocktailMaster",
    "recipeType": "standard",
    "recipeId": "11007",
    "recipeName": "Margarita",
    "recipeImageUrl": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg",
    "customMessage": "Try this amazing Margarita!",
    "shareId": "share-abc-123",
    "timestamp": "2025-11-14T11:00:00Z"
  },
  "fcm_options": {
    "image": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "New Recipe Share 🍹",
    "body": "CocktailMaster shared \"Margarita\" with you",
    "icon": "ic_recipe",
    "color": "#FF9800",
    "sound": "recipe_share.mp3",
    "tag": "recipe_shared",
    "image": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "recipe_shared",
    "senderId": "test-user-123",
    "senderAlias": "@happy-penguin-42",
    "senderDisplayName": "CocktailMaster",
    "recipeType": "standard",
    "recipeId": "11007",
    "recipeName": "Margarita",
    "recipeImageUrl": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg",
    "customMessage": "Try this amazing Margarita!",
    "shareId": "share-abc-123",
    "timestamp": "2025-11-14T11:00:00Z",
    "navigate_to": "/recipe/11007?from=share"
  },
  "android": {
    "priority": "high",
    "ttl": "172800s",
    "notification": {
      "channel_id": "shares_channel",
      "notification_priority": "PRIORITY_HIGH",
      "visibility": "VISIBILITY_PUBLIC",
      "style": {
        "type": "big_picture",
        "big_picture": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg"
      }
    }
  }
}
```

### Rich Notification (iOS Notification Service Extension)
```swift
// NotificationService.swift
override func didReceive(_ request: UNNotificationRequest,
                        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {

    if let imageUrlString = request.content.userInfo["recipeImageUrl"] as? String,
       let imageUrl = URL(string: imageUrlString) {

        // Download and attach image
        URLSession.shared.downloadTask(with: imageUrl) { url, _, _ in
            if let url = url,
               let attachment = try? UNNotificationAttachment(
                   identifier: "recipe-image",
                   url: url,
                   options: nil
               ) {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }.resume()
    }
}
```

## 3. Custom Recipe Shared

### Trigger
When a friend shares their custom recipe creation

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "Custom Creation! ✨",
      "subtitle": "From @happy-penguin-42",
      "body": "CocktailMaster shared their creation \"Blue Sunset\"",
      "sound": "custom_share.caf",
      "badge": 1
    },
    "category": "CUSTOM_RECIPE_SHARED",
    "thread-id": "custom-shares"
  },
  "data": {
    "type": "custom_recipe_shared",
    "senderId": "test-user-123",
    "senderAlias": "@happy-penguin-42",
    "senderDisplayName": "CocktailMaster",
    "recipeType": "custom",
    "customRecipeId": "custom-123-abc",
    "recipeName": "Blue Sunset",
    "recipeDescription": "A tropical blend with a mysterious blue hue",
    "customMessage": "My signature cocktail creation!",
    "shareId": "share-xyz-789",
    "timestamp": "2025-11-14T12:00:00Z"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "Custom Creation! ✨",
    "body": "CocktailMaster shared their creation \"Blue Sunset\"",
    "icon": "ic_custom_recipe",
    "color": "#9C27B0",
    "sound": "custom_share.mp3",
    "tag": "custom_recipe_shared",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "custom_recipe_shared",
    "senderId": "test-user-123",
    "senderAlias": "@happy-penguin-42",
    "senderDisplayName": "CocktailMaster",
    "recipeType": "custom",
    "customRecipeId": "custom-123-abc",
    "recipeName": "Blue Sunset",
    "recipeDescription": "A tropical blend with a mysterious blue hue",
    "customMessage": "My signature cocktail creation!",
    "shareId": "share-xyz-789",
    "timestamp": "2025-11-14T12:00:00Z",
    "navigate_to": "/recipe/custom/custom-123-abc?from=share"
  },
  "android": {
    "priority": "high",
    "ttl": "172800s",
    "notification": {
      "channel_id": "custom_shares_channel",
      "notification_priority": "PRIORITY_HIGH"
    }
  }
}
```

## 4. Friend Joined App

### Trigger
When someone you invited joins the app

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "Your Friend Joined! 🎊",
      "subtitle": "Welcome them!",
      "body": "@swift-eagle-17 just joined My AI Bartender",
      "sound": "friend_joined.caf",
      "badge": 1
    },
    "category": "FRIEND_JOINED",
    "thread-id": "friends"
  },
  "data": {
    "type": "friend_joined",
    "friendId": "test-user-789",
    "friendAlias": "@swift-eagle-17",
    "inviteCode": "FRN-8K3M-2024",
    "timestamp": "2025-11-14T13:00:00Z",
    "action": "send_welcome"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "Your Friend Joined! 🎊",
    "body": "@swift-eagle-17 just joined My AI Bartender",
    "icon": "ic_friend_joined",
    "color": "#4CAF50",
    "sound": "friend_joined.mp3",
    "tag": "friend_joined",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "friend_joined",
    "friendId": "test-user-789",
    "friendAlias": "@swift-eagle-17",
    "inviteCode": "FRN-8K3M-2024",
    "timestamp": "2025-11-14T13:00:00Z",
    "action": "send_welcome",
    "navigate_to": "/social/friends/@swift-eagle-17"
  },
  "android": {
    "priority": "high",
    "ttl": "86400s",
    "notification": {
      "channel_id": "social_channel",
      "notification_priority": "PRIORITY_DEFAULT"
    }
  }
}
```

## 5. Weekly Recommendations

### Trigger
Weekly automated recommendation based on friend activity

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "Weekly Cocktail Picks 🍸",
      "subtitle": "Based on your friends' favorites",
      "body": "3 trending cocktails your friends love",
      "sound": "default",
      "badge": 1
    },
    "category": "WEEKLY_RECOMMENDATIONS",
    "thread-id": "recommendations"
  },
  "data": {
    "type": "weekly_recommendations",
    "recommendations": [
      {
        "recipeId": "11007",
        "recipeName": "Margarita",
        "sharedByCount": 5
      },
      {
        "recipeId": "17222",
        "recipeName": "A1",
        "sharedByCount": 3
      },
      {
        "recipeId": "11000",
        "recipeName": "Mojito",
        "sharedByCount": 2
      }
    ],
    "timestamp": "2025-11-14T09:00:00Z"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "Weekly Cocktail Picks 🍸",
    "body": "3 trending cocktails your friends love",
    "icon": "ic_recommendations",
    "color": "#00D4FF",
    "sound": "default",
    "tag": "weekly_recommendations",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "weekly_recommendations",
    "recommendations": "[{\"recipeId\":\"11007\",\"recipeName\":\"Margarita\",\"sharedByCount\":5}]",
    "timestamp": "2025-11-14T09:00:00Z",
    "navigate_to": "/social/trending"
  },
  "android": {
    "priority": "normal",
    "ttl": "604800s",
    "notification": {
      "channel_id": "recommendations_channel",
      "notification_priority": "PRIORITY_DEFAULT"
    }
  }
}
```

## 6. Batch Recipe Shares

### Trigger
When multiple friends share recipes while user is offline

### iOS (APNs) Payload
```json
{
  "aps": {
    "alert": {
      "title": "5 New Recipe Shares 🍹",
      "subtitle": "While you were away",
      "body": "Your friends shared amazing cocktails",
      "sound": "default",
      "badge": 5
    },
    "category": "BATCH_SHARES",
    "thread-id": "shares"
  },
  "data": {
    "type": "batch_shares",
    "shareCount": 5,
    "shares": [
      {
        "senderAlias": "@happy-penguin-42",
        "recipeName": "Margarita"
      },
      {
        "senderAlias": "@clever-dolphin-99",
        "recipeName": "Mojito"
      }
    ],
    "timestamp": "2025-11-14T14:00:00Z"
  }
}
```

### Android (FCM) Payload
```json
{
  "notification": {
    "title": "5 New Recipe Shares 🍹",
    "body": "Your friends shared amazing cocktails",
    "icon": "ic_batch_shares",
    "color": "#FF9800",
    "sound": "default",
    "tag": "batch_shares",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "type": "batch_shares",
    "shareCount": "5",
    "timestamp": "2025-11-14T14:00:00Z",
    "navigate_to": "/social?tab=shared"
  },
  "android": {
    "priority": "normal",
    "ttl": "172800s",
    "notification": {
      "channel_id": "shares_channel",
      "notification_priority": "PRIORITY_DEFAULT",
      "notification_count": 5
    }
  }
}
```

## Flutter Integration

### Setup and Initialization
```dart
// lib/src/services/notification_service.dart
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      final token = await _messaging.getToken();
      await _registerWithNotificationHub(token);

      // Handle token refresh
      _messaging.onTokenRefresh.listen(_registerWithNotificationHub);

      // Configure handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    }
  }

  Future<void> _registerWithNotificationHub(String? token) async {
    if (token == null) return;

    final userId = await _authService.getCurrentUserId();
    final userTier = await _authService.getUserTier();
    final userAlias = await _socialService.getUserAlias();

    // Register with Azure Notification Hub
    await _backendService.registerDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      tags: [
        'user:$userId',
        'tier:$userTier',
        'alias:$userAlias',
        'platform:${Platform.operatingSystem}',
        'version:${packageInfo.version}'
      ]
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'friend_accepted':
        _showLocalNotification(
          title: message.notification?.title ?? 'New Friend!',
          body: message.notification?.body ?? '',
          payload: jsonEncode(data)
        );
        _updateFriendsList(data);
        break;

      case 'recipe_shared':
      case 'custom_recipe_shared':
        _showRecipeNotification(message);
        _updateSharedRecipes(data);
        break;

      case 'friend_joined':
        _showLocalNotification(
          title: message.notification?.title ?? 'Friend Joined!',
          body: message.notification?.body ?? '',
          payload: jsonEncode(data)
        );
        break;

      case 'weekly_recommendations':
        _updateRecommendations(data);
        break;
    }
  }

  Future<void> _showRecipeNotification(RemoteMessage message) async {
    final data = message.data;
    final imageUrl = data['recipeImageUrl'];

    if (imageUrl != null && Platform.isAndroid) {
      // Show big picture notification on Android
      final BigPictureStyleInformation bigPicture =
          BigPictureStyleInformation(
        await _downloadImage(imageUrl),
        contentTitle: message.notification?.title,
        summaryText: data['customMessage'],
      );

      await _localNotifications.show(
        Random().nextInt(10000),
        message.notification?.title,
        message.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'shares_channel',
            'Recipe Shares',
            styleInformation: bigPicture,
          )
        ),
        payload: jsonEncode(data)
      );
    } else {
      // Standard notification
      _showLocalNotification(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        payload: jsonEncode(data)
      );
    }
  }
}
```

### Notification Channels (Android)
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
  android:name="com.google.firebase.messaging.default_notification_channel_id"
  android:value="social_channel" />

<!-- Define channels in strings.xml -->
<resources>
  <string name="social_channel_name">Social Updates</string>
  <string name="social_channel_description">Friend requests and social activity</string>

  <string name="shares_channel_name">Recipe Shares</string>
  <string name="shares_channel_description">Recipes shared by friends</string>

  <string name="custom_shares_channel_name">Custom Creations</string>
  <string name="custom_shares_channel_description">Custom recipes from friends</string>

  <string name="recommendations_channel_name">Recommendations</string>
  <string name="recommendations_channel_description">Weekly cocktail recommendations</string>
</resources>
```

### Deep Link Navigation
```dart
// lib/src/router/app_router.dart
GoRoute(
  path: '/notification',
  builder: (context, state) {
    final data = state.extra as Map<String, dynamic>?;
    if (data == null) return const SocialHub();

    final navigateTo = data['navigate_to'] as String?;
    if (navigateTo != null) {
      // Navigate after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(navigateTo);
      });
    }

    return const SplashScreen();
  }
)
```

## Testing Push Notifications

### Test via Azure Portal
```bash
# Send test notification
az notification-hub test-send \
  --resource-group rg-mba-prod \
  --namespace-name nh-namespace-mybartenderai \
  --notification-hub-name nh-mybartenderai \
  --notification-format gcm \
  --payload '{
    "notification": {
      "title": "Test Notification",
      "body": "This is a test"
    },
    "data": {
      "type": "test",
      "timestamp": "2025-11-14T15:00:00Z"
    }
  }' \
  --tags "user:test-user-123"
```

### Test via Function
```javascript
// backend/functions/test-notification/index.js
const { NotificationHubsClient } = require("@azure/notification-hubs");

module.exports = async function (context, req) {
  const client = new NotificationHubsClient(
    process.env.NOTIFICATION_HUB_CONNECTION_STRING,
    "nh-mybartenderai"
  );

  const message = {
    notification: {
      title: req.body.title,
      body: req.body.body
    },
    data: req.body.data
  };

  const result = await client.sendNotification({
    body: JSON.stringify(message),
    tags: req.body.tags,
    platform: "fcm"
  });

  context.res = {
    status: 200,
    body: { success: true, trackingId: result.trackingId }
  };
};
```

## Notification Settings UI

### Settings Screen Fragment
```dart
// lib/src/features/settings/notification_settings.dart
class NotificationSettings extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Friend Requests'),
          subtitle: Text('When someone accepts your invite'),
          value: settings.friendRequests,
          onChanged: (value) => updateSetting('friend_requests', value)
        ),
        SwitchListTile(
          title: Text('Recipe Shares'),
          subtitle: Text('When friends share recipes'),
          value: settings.recipeShares,
          onChanged: (value) => updateSetting('recipe_shares', value)
        ),
        SwitchListTile(
          title: Text('Custom Creations'),
          subtitle: Text('When friends share custom recipes'),
          value: settings.customCreations,
          onChanged: (value) => updateSetting('custom_creations', value)
        ),
        SwitchListTile(
          title: Text('Weekly Recommendations'),
          subtitle: Text('Trending cocktails from friends'),
          value: settings.weeklyRecommendations,
          onChanged: (value) => updateSetting('weekly_recommendations', value)
        ),
        Divider(),
        ListTile(
          title: Text('Quiet Hours'),
          subtitle: Text(settings.quietHours
            ? '${settings.quietStart} - ${settings.quietEnd}'
            : 'Disabled'),
          trailing: Switch(
            value: settings.quietHours,
            onChanged: (value) => showQuietHoursDialog()
          )
        )
      ]
    );
  }
}
```

## Analytics Tracking

### Notification Events
```javascript
// Track in Application Insights
trackEvent('NotificationSent', {
  type: 'friend_accepted',
  recipient: userId,
  platform: 'ios',
  delivered: true
});

trackEvent('NotificationOpened', {
  type: 'recipe_shared',
  recipeId: '11007',
  timeToOpen: '5.2s'
});

trackMetric('NotificationDeliveryRate', 0.98);
trackMetric('NotificationOpenRate', 0.45);
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Notification Hub SDK**: @azure/notification-hubs ^1.0.0