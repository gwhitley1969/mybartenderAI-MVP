# Friends via Code - Flutter UI Mockups Specification

## Overview

This document provides detailed specifications for all Flutter UI screens related to the Friends via Code feature. Each screen includes layout descriptions, component specifications, and interaction flows.

## Design System

### Color Palette
```dart
// Primary Colors (from existing app)
const Color primaryMagenta = Color(0xFFFF00FF);  // Electric magenta
const Color secondaryBlue = Color(0xFF00D4FF);   // Electric blue
const Color backgroundDark = Color(0xFF121212);  // Dark background
const Color surfaceDark = Color(0xFF1E1E1E);     // Card surface
const Color textPrimary = Color(0xFFFFFFFF);     // White text
const Color textSecondary = Color(0xFFB0B0B0);   // Gray text

// Social Feature Colors
const Color friendGreen = Color(0xFF4CAF50);     // Friend status
const Color shareOrange = Color(0xFFFF9800);     // Share actions
const Color invitePurple = Color(0xFF9C27B0);    // Invite actions
```

### Typography
```dart
// Headings
TextStyle h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary);
TextStyle h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary);
TextStyle h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textPrimary);

// Body
TextStyle body1 = TextStyle(fontSize: 16, color: textPrimary);
TextStyle body2 = TextStyle(fontSize: 14, color: textSecondary);

// Special
TextStyle alias = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: secondaryBlue);
TextStyle button = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
```

## 1. Social Hub Screen

**Route**: `/social`
**Access**: Bottom navigation tab (new icon: `Icons.people_outline`)

### Layout Structure
```
AppBar [
  Title: "Social"
  Actions: [
    IconButton(Icons.qr_code_scanner) // Scan invite code
    IconButton(Icons.share) // Send invite
  ]
]

Body [
  TabBar [
    Tab("Friends")
    Tab("Activity")
    Tab("Shared")
  ]

  TabBarView [
    FriendsListView()
    ActivityFeedView()
    SharedRecipesView()
  ]
]
```

### 1.1 Friends List Tab

```dart
// FriendsListView
Column [
  // Search Bar
  Padding(16) [
    TextField(
      decoration: InputDecoration(
        hintText: "Search friends...",
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: 12)
      )
    )
  ]

  // Friends Count
  Padding(horizontal: 16, vertical: 8) [
    Row [
      Text("${friends.length} Friends", style: h3)
      Spacer()
      TextButton.icon(
        icon: Icon(Icons.person_add),
        label: Text("Invite"),
        onPressed: () => showInviteBottomSheet()
      )
    ]
  ]

  // Friends List
  Expanded [
    ListView.builder [
      FriendTile(
        leading: CircleAvatar [
          Text(getInitials(friend.displayName ?? friend.alias))
        ]
        title: friend.displayName ?? friend.alias
        subtitle: "@${friend.alias}"
        trailing: Row [
          Icon(Icons.local_bar, size: 16)
          Text("${friend.sharedRecipes}")
        ]
        onTap: () => showFriendProfile(friend)
      )
    ]
  ]
]
```

### 1.2 Activity Feed Tab

```dart
// ActivityFeedView
RefreshIndicator [
  ListView.builder [
    ActivityCard(
      margin: EdgeInsets(8, 4)
      padding: EdgeInsets(16)
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12)
      )

      child: Column [
        // Header
        Row [
          CircleAvatar(radius: 20)
          SizedBox(width: 12)
          Column(crossAxisAlignment: start) [
            Text(friend.displayName ?? friend.alias, style: bodyBold)
            Text(timeAgo(activity.timestamp), style: caption)
          ]
          Spacer()
          Icon(getActivityIcon(activity.type))
        ]

        // Content
        Padding(top: 12) [
          if (activity.type == "recipe_shared") [
            RecipePreviewCard(
              recipe: activity.recipe
              message: activity.message
              onTap: () => viewRecipe(activity.recipe)
            )
          ]
          else if (activity.type == "friend_joined") [
            Text("${friend.alias} joined My AI Bartender!")
          ]
        ]

        // Actions
        Row [
          TextButton.icon(
            icon: Icon(Icons.favorite_border),
            label: Text("Like")
          )
          TextButton.icon(
            icon: Icon(Icons.share),
            label: Text("Share")
          )
        ]
      ]
    )
  ]
]
```

### 1.3 Shared Recipes Tab

```dart
// SharedRecipesView
Column [
  // Filter Chips
  SingleChildScrollView(horizontal) [
    Padding(16, 8) [
      Row [
        FilterChip(label: "All", selected: true)
        SizedBox(8)
        FilterChip(label: "Shared by me")
        SizedBox(8)
        FilterChip(label: "Shared with me")
        SizedBox(8)
        FilterChip(label: "Custom recipes")
      ]
    ]
  ]

  // Recipes Grid
  Expanded [
    GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75
      )

      itemBuilder: (context, index) [
        RecipeGridCard(
          image: NetworkImage(recipe.imageUrl)
          title: recipe.name
          subtitle: "by ${recipe.sharer.alias}"
          badge: recipe.type == "custom" ? "CUSTOM" : null
          onTap: () => viewRecipe(recipe)
        )
      ]
    )
  ]
]
```

## 2. Profile Setup Screen

**Route**: `/social/setup`
**Trigger**: First time accessing social features

### Layout Structure

```dart
Scaffold [
  body: SafeArea [
    Padding(24) [
      Column [
        // Welcome Section
        Spacer(flex: 1)

        Icon(Icons.celebration, size: 80, color: primaryMagenta)
        SizedBox(height: 24)

        Text("Welcome to Social!", style: h1, textAlign: center)
        SizedBox(height: 12)

        Text(
          "Connect with friends and share your favorite cocktail recipes",
          style: body2,
          textAlign: center
        )

        Spacer(flex: 1)

        // Alias Generation
        Container(
          padding: EdgeInsets(20),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: secondaryBlue.withOpacity(0.3))
          )

          child: Column [
            Text("Your unique alias:", style: body1)
            SizedBox(height: 12)

            Row(mainAxisAlignment: center) [
              if (generatingAlias) [
                CircularProgressIndicator()
              ] else [
                Text(generatedAlias, style: h2.copyWith(color: secondaryBlue))
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: regenerateAlias
                )
              ]
            ]

            SizedBox(height: 8)
            Text(
              "This is how friends will find you",
              style: caption
            )
          ]
        )

        SizedBox(height: 24)

        // Optional Display Name
        TextField(
          decoration: InputDecoration(
            labelText: "Display Name (optional)",
            hintText: "How friends will see you",
            border: OutlineInputBorder(borderRadius: 12),
            counterText: "${displayName.length}/30"
          ),
          maxLength: 30
        )

        Spacer(flex: 2)

        // Action Buttons
        Column [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMagenta,
              minimumSize: Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: 12)
            ),
            child: Text("Get Started", style: button),
            onPressed: confirmProfile
          )

          SizedBox(height: 12)

          TextButton(
            child: Text("Skip for now"),
            onPressed: skipSetup
          )
        ]
      ]
    ]
  ]
]
```

## 3. Share Recipe Bottom Sheet

**Trigger**: Share button on any recipe

### Layout Structure

```dart
DraggableScrollableSheet [
  Container(
    decoration: BoxDecoration(
      color: surfaceDark,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))
    )

    child: Column [
      // Handle Bar
      Center [
        Container(
          width: 40,
          height: 4,
          margin: EdgeInsets(12),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(2)
          )
        )
      ]

      // Title
      Padding(16) [
        Text("Share ${recipe.name}", style: h2)
      ]

      // Recipe Preview
      Container(
        margin: EdgeInsets(horizontal: 16),
        padding: EdgeInsets(12),
        decoration: BoxDecoration(
          color: backgroundDark,
          borderRadius: BorderRadius.circular(12)
        )

        child: Row [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(recipe.imageUrl, width: 60, height: 60)
          )
          SizedBox(width: 12)
          Expanded [
            Column [
              Text(recipe.name, style: bodyBold)
              Text("${recipe.ingredients.length} ingredients", style: caption)
            ]
          ]
        ]
      )

      // Custom Message
      Padding(16, 8) [
        TextField(
          decoration: InputDecoration(
            labelText: "Add a message (optional)",
            hintText: "Try this amazing cocktail!",
            border: OutlineInputBorder(borderRadius: 12),
            counterText: "${message.length}/200"
          ),
          maxLength: 200,
          maxLines: 3
        )
      ]

      // Share Options
      Padding(16) [
        Column [
          // Share with Friends
          ListTile(
            leading: Icon(Icons.people, color: friendGreen),
            title: Text("Share with Friends"),
            subtitle: Text("Your friends will see this in their feed"),
            shape: RoundedRectangleBorder(borderRadius: 12),
            tileColor: backgroundDark,
            onTap: shareWithFriends
          )

          SizedBox(height: 8)

          // Get Share Link
          ListTile(
            leading: Icon(Icons.link, color: shareOrange),
            title: Text("Get Share Link"),
            subtitle: Text("Anyone with the link can view"),
            shape: RoundedRectangleBorder(borderRadius: 12),
            tileColor: backgroundDark,
            onTap: getShareLink
          )

          SizedBox(height: 8)

          // Share to Social Media
          ListTile(
            leading: Icon(Icons.share, color: secondaryBlue),
            title: Text("Share to..."),
            subtitle: Text("WhatsApp, Instagram, etc."),
            shape: RoundedRectangleBorder(borderRadius: 12),
            tileColor: backgroundDark,
            onTap: shareExternal
          )
        ]
      ]
    ]
  )
]
```

## 4. Share Link Generated Dialog

**Trigger**: After generating share link

### Layout Structure

```dart
Dialog [
  Container(
    padding: EdgeInsets(24),
    decoration: BoxDecoration(
      color: surfaceDark,
      borderRadius: BorderRadius.circular(16)
    )

    child: Column(mainAxisSize: min) [
      // Success Icon
      Container(
        padding: EdgeInsets(16),
        decoration: BoxDecoration(
          color: shareOrange.withOpacity(0.1),
          shape: BoxShape.circle
        ),
        child: Icon(Icons.check_circle, color: shareOrange, size: 48)
      )

      SizedBox(height: 16)

      // Title
      Text("Share Link Ready!", style: h2, textAlign: center)

      SizedBox(height: 8)

      // Share Code
      Container(
        padding: EdgeInsets(12),
        decoration: BoxDecoration(
          color: backgroundDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: shareOrange.withOpacity(0.3))
        ),
        child: Row [
          Expanded [
            Column [
              Text("Share Code", style: caption)
              Text(shareCode, style: bodyBold)
            ]
          ]
          IconButton(
            icon: Icon(Icons.copy),
            onPressed: copyShareCode
          )
        ]
      )

      SizedBox(height: 12)

      // Share URL
      Container(
        padding: EdgeInsets(12),
        decoration: BoxDecoration(
          color: backgroundDark,
          borderRadius: BorderRadius.circular(8)
        ),
        child: Column [
          Text("Share URL", style: caption)
          SizedBox(height: 4)
          Text(
            shareUrl,
            style: body2.copyWith(color: secondaryBlue),
            overflow: TextOverflow.ellipsis
          )
        ]
      )

      SizedBox(height: 8)

      // Expiry Notice
      Row(mainAxisAlignment: center) [
        Icon(Icons.timer, size: 16, color: textSecondary)
        SizedBox(width: 4)
        Text("Expires in 30 days", style: caption)
      ]

      SizedBox(height: 16)

      // Actions
      Row [
        Expanded [
          OutlinedButton(
            child: Text("Copy Link"),
            onPressed: copyLink
          )
        ]
        SizedBox(width: 12)
        Expanded [
          ElevatedButton(
            child: Text("Share"),
            onPressed: shareNow
          )
        ]
      ]
    ]
  )
]
```

## 5. Send Invite Screen

**Route**: `/social/invite`
**Access**: Invite button in Social Hub

### Layout Structure

```dart
Scaffold [
  AppBar [
    title: Text("Invite Friends")
    leading: IconButton(Icons.close)
  ]

  body: Padding(16) [
    Column [
      // Illustration
      Center [
        Image.asset(
          'assets/images/invite_friends.png',
          height: 200
        )
      ]

      SizedBox(height: 24)

      // Description
      Text(
        "Invite friends to share cocktail recipes",
        style: h2,
        textAlign: center
      )

      SizedBox(height: 12)

      Text(
        "Send an invite link to connect with friends and discover new cocktails together",
        style: body2,
        textAlign: center
      )

      SizedBox(height: 32)

      // Custom Message
      TextField(
        decoration: InputDecoration(
          labelText: "Personal message",
          hintText: "Let's share our favorite cocktails!",
          border: OutlineInputBorder(borderRadius: 12)
        ),
        maxLines: 3
      )

      Spacer()

      // Pending Invites Notice
      if (pendingInvites > 0) [
        Container(
          padding: EdgeInsets(12),
          decoration: BoxDecoration(
            color: invitePurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Row [
            Icon(Icons.info_outline, color: invitePurple)
            SizedBox(width: 8)
            Text("$pendingInvites pending invites")
          ]
        )

        SizedBox(height: 12)
      ]

      // Generate Invite Button
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: invitePurple,
          minimumSize: Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: 12)
        ),
        child: Text("Generate Invite Link", style: button),
        onPressed: pendingInvites < 5 ? generateInvite : null
      )

      if (pendingInvites >= 5) [
        SizedBox(height: 8)
        Text(
          "Maximum pending invites reached (5)",
          style: caption.copyWith(color: Colors.orange),
          textAlign: center
        )
      ]
    ]
  ]
]
```

## 6. Accept Invite Screen

**Route**: `/social/invite/accept?code={inviteCode}`
**Access**: Deep link from invite URL

### Layout Structure

```dart
Scaffold [
  body: SafeArea [
    Center [
      Padding(24) [
        Column(mainAxisAlignment: center) [
          // Loading State
          if (loading) [
            Column [
              CircularProgressIndicator()
              SizedBox(height: 16)
              Text("Loading invite details...")
            ]
          ]

          // Success State
          else if (inviteDetails != null) [
            Column [
              // Avatar
              CircleAvatar(
                radius: 50,
                child: Text(
                  getInitials(inviteDetails.sender.displayName ?? inviteDetails.sender.alias),
                  style: h1
                )
              )

              SizedBox(height: 24)

              // Sender Info
              Text(
                inviteDetails.sender.displayName ?? inviteDetails.sender.alias,
                style: h2
              )
              Text(inviteDetails.sender.alias, style: alias)

              SizedBox(height: 16)

              // Message
              if (inviteDetails.message != null) [
                Container(
                  padding: EdgeInsets(16),
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                    inviteDetails.message,
                    style: body1,
                    textAlign: center
                  )
                )

                SizedBox(height: 24)
              ]

              // Actions
              Row [
                Expanded [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 48)
                    ),
                    child: Text("Decline"),
                    onPressed: declineInvite
                  )
                ]
                SizedBox(width: 12)
                Expanded [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: friendGreen,
                      minimumSize: Size(0, 48)
                    ),
                    child: Text("Accept"),
                    onPressed: acceptInvite
                  )
                ]
              ]
            ]
          ]

          // Error State
          else [
            Column [
              Icon(Icons.error_outline, size: 64, color: Colors.red)
              SizedBox(height: 16)
              Text("Invalid or Expired Invite", style: h2)
              SizedBox(height: 8)
              Text(
                "This invite link may have expired or already been used",
                style: body2,
                textAlign: center
              )
              SizedBox(height: 24)
              ElevatedButton(
                child: Text("Go to Social"),
                onPressed: () => Navigator.pushReplacementNamed(context, '/social')
              )
            ]
          ]
        ]
      ]
    ]
  ]
]
```

## 7. Friend Profile Bottom Sheet

**Trigger**: Tap on friend in list

### Layout Structure

```dart
DraggableScrollableSheet [
  Container(
    child: Column [
      // Header with Avatar
      Stack [
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryMagenta, secondaryBlue]
            )
          )
        )

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center [
            CircleAvatar(
              radius: 40,
              backgroundColor: surfaceDark,
              child: Text(getInitials(friend))
            )
          ]
        )
      ]

      // Friend Info
      Padding(16) [
        Column [
          Text(friend.displayName ?? friend.alias, style: h2)
          Text(friend.alias, style: alias)

          SizedBox(height: 16)

          // Stats Row
          Row(mainAxisAlignment: spaceEvenly) [
            Column [
              Text("${friend.sharedRecipes}", style: h2)
              Text("Shared", style: caption)
            ]
            Container(width: 1, height: 40, color: Colors.grey)
            Column [
              Text(formatDate(friend.friendsSince), style: h2)
              Text("Friends Since", style: caption)
            ]
          ]

          SizedBox(height: 24)

          // Recent Shares
          Text("Recent Shares", style: h3)
          SizedBox(height: 12)

          ...friend.recentShares.map((recipe) =>
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(recipe.imageUrl, width: 50)
              ),
              title: Text(recipe.name),
              subtitle: Text(timeAgo(recipe.sharedAt)),
              onTap: () => viewRecipe(recipe)
            )
          )

          SizedBox(height: 24)

          // Actions
          Row [
            Expanded [
              OutlinedButton.icon(
                icon: Icon(Icons.person_remove),
                label: Text("Remove Friend"),
                onPressed: confirmRemoveFriend
              )
            ]
          ]
        ]
      ]
    ]
  )
]
```

## 8. QR Code Scanner Screen

**Route**: `/social/scan`
**Access**: QR code icon in Social Hub

### Layout Structure

```dart
Scaffold [
  AppBar [
    title: Text("Scan Invite Code")
    backgroundColor: Colors.transparent
  ]

  body: Stack [
    // Camera Preview
    QRView(
      key: qrKey,
      onQRViewCreated: onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: secondaryBlue,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: 300
      )
    )

    // Instructions
    Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets(horizontal: 20),
        padding: EdgeInsets(20),
        decoration: BoxDecoration(
          color: surfaceDark.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column [
          Text(
            "Point camera at QR code",
            style: body1,
            textAlign: center
          ),
          SizedBox(height: 8),
          Text(
            "Or enter code manually",
            style: caption,
            textAlign: center
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: "Enter code (e.g., FRN-8K3M-2024)",
              suffixIcon: IconButton(
                icon: Icon(Icons.arrow_forward),
                onPressed: submitManualCode
              ),
              border: OutlineInputBorder(borderRadius: 8)
            )
          )
        ]
      )
    )

    // Flash Toggle
    Positioned(
      top: 100,
      right: 20,
      child: IconButton(
        icon: Icon(flashOn ? Icons.flash_on : Icons.flash_off),
        color: Colors.white,
        onPressed: toggleFlash
      )
    )
  ]
]
```

## 9. Notifications Permission Dialog

**Trigger**: After accepting first friend invite

### Layout Structure

```dart
Dialog [
  Container(
    padding: EdgeInsets(24),
    child: Column(mainAxisSize: min) [
      Icon(Icons.notifications_outlined, size: 64, color: primaryMagenta)

      SizedBox(height: 16)

      Text("Stay Connected!", style: h2)

      SizedBox(height: 12)

      Text(
        "Get notified when friends share recipes or accept your invites",
        style: body2,
        textAlign: center
      )

      SizedBox(height: 24)

      // Feature List
      Column(crossAxisAlignment: start) [
        Row [
          Icon(Icons.check_circle, color: friendGreen, size: 20)
          SizedBox(width: 8)
          Text("New recipe shares from friends")
        ]
        SizedBox(height: 8)
        Row [
          Icon(Icons.check_circle, color: friendGreen, size: 20)
          SizedBox(width: 8)
          Text("Friend invite acceptances")
        ]
        SizedBox(height: 8)
        Row [
          Icon(Icons.check_circle, color: friendGreen, size: 20)
          SizedBox(width: 8)
          Text("Weekly cocktail recommendations")
        ]
      ]

      SizedBox(height: 24)

      // Actions
      Column [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48)
          ),
          child: Text("Enable Notifications"),
          onPressed: requestNotificationPermission
        )

        TextButton(
          child: Text("Not now"),
          onPressed: () => Navigator.pop(context)
        )
      ]
    ]
  )
]
```

## Navigation Flow

### Main Flow
1. **Home Screen** → Social Tab → **Social Hub**
2. **Social Hub** → Friends Tab → Friend Tile → **Friend Profile**
3. **Social Hub** → Activity Tab → Share Button → **Share Recipe**
4. **Social Hub** → Invite Button → **Send Invite**

### First Time Flow
1. **Home Screen** → Social Tab → **Profile Setup**
2. **Profile Setup** → Generate Alias → Optional Name → **Social Hub**

### Invite Flow
1. **Send Invite** → Generate Link → Share externally
2. Recipient clicks link → **Accept Invite** → Accept → **Social Hub**
3. OR: **QR Scanner** → Scan code → **Accept Invite**

### Share Flow
1. Recipe Screen → Share Button → **Share Recipe Sheet**
2. Select share method → **Share Link Dialog** → Copy/Share
3. Recipient views → Downloads app or opens recipe

## Gesture Interactions

### Swipe Gestures
- **Friends List**: Swipe right to message (future), swipe left to remove
- **Activity Feed**: Pull to refresh
- **Shared Recipes**: Long press to multi-select

### Tap Interactions
- **Single Tap**: Primary action (view profile, open recipe)
- **Double Tap**: Like/favorite
- **Long Press**: Context menu (share, remove, report)

## Animations

### Screen Transitions
```dart
// Slide up for bottom sheets
showModalBottomSheet(
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  transitionAnimationController: AnimationController(
    duration: Duration(milliseconds: 300)
  )
)

// Fade for dialogs
showGeneralDialog(
  transitionDuration: Duration(milliseconds: 200),
  transitionBuilder: (context, a1, a2, widget) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: a1,
        curve: Curves.easeOut
      ),
      child: widget
    )
  }
)

// Hero animation for recipe images
Hero(
  tag: "recipe-${recipe.id}",
  child: Image.network(recipe.imageUrl)
)
```

### Micro-animations
- **Loading states**: Shimmer effect on placeholders
- **Button press**: Scale down to 0.95 on tap
- **Success states**: Check mark with bounce animation
- **New content**: Fade in with slight slide up

## Error States

### No Friends Yet
```dart
Center [
  Column(mainAxisAlignment: center) [
    Image.asset('assets/images/no_friends.png', height: 150)
    SizedBox(height: 16)
    Text("No friends yet", style: h3)
    Text("Invite friends to start sharing", style: body2)
    SizedBox(height: 24)
    ElevatedButton.icon(
      icon: Icon(Icons.person_add),
      label: Text("Send Invite"),
      onPressed: () => Navigator.pushNamed(context, '/social/invite')
    )
  ]
]
```

### Network Error
```dart
Center [
  Column(mainAxisAlignment: center) [
    Icon(Icons.wifi_off, size: 64, color: textSecondary)
    SizedBox(height: 16)
    Text("Connection error", style: h3)
    Text("Check your internet connection", style: body2)
    SizedBox(height: 24)
    OutlinedButton(
      child: Text("Retry"),
      onPressed: retry
    )
  ]
]
```

## Accessibility

### Screen Readers
```dart
Semantics(
  label: "Friend ${friend.displayName}, ${friend.sharedRecipes} shared recipes",
  child: FriendTile(...)
)
```

### Contrast Ratios
- Text on dark background: 7:1 minimum
- Interactive elements: 4.5:1 minimum
- Decorative elements: No requirement

### Touch Targets
- Minimum size: 48x48dp
- Spacing between targets: 8dp minimum

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Design System**: Material Design 3 with custom theme