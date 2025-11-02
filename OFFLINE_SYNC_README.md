# Offline Sync Implementation Guide

This document explains the offline sync functionality that has been implemented for the app.

## Overview

The app now supports full offline functionality for:
- **Hotspots/Destinations** - All tourist destinations and businesses
- **Events** - All events created by admins and business owners
- **Trip Itineraries** - User's planned trips

## Architecture

### 1. Offline Data Service (`lib/services/offline_data_service.dart`)
- Uses Hive for persistent local storage
- Stores hotspots, events, and trips locally on the device
- Provides methods to save/load data from cache
- Tracks metadata (last sync time, item counts)

### 2. Offline Sync Service (`lib/services/offline_sync_service.dart`)
- Handles syncing data from Firestore to local storage
- Downloads images for offline viewing
- Tracks sync progress
- Automatically checks if sync is needed

### 3. Updated Repositories
- **EventRepository** - Cache-first loading (checks cache before Firestore)
- **DestinationRepository** - Cache-first loading
- **TripRepository** - Cache-first loading

### 4. UI Components
- **OfflineSyncDialog** - Progress dialog for manual syncs
- **OfflineStatusWidget** - Status widget showing sync information

## How It Works

### Automatic Background Sync
When the app starts:
1. Checks if data is older than 24 hours
2. If connected to internet, automatically syncs in the background
3. Does NOT download images during auto-sync (to save bandwidth)

### Cache-First Strategy
When loading data:
1. First checks local Hive cache
2. Returns cached data immediately (instant loading)
3. Syncs with Firestore in background if needed
4. Falls back to Firestore if cache is empty
5. Falls back to cache if Firestore fails (offline mode)

### Manual Sync
Users can manually trigger a full sync:
1. Shows progress dialog with detailed status
2. Downloads hotspots, events, and trips
3. Downloads all images for offline viewing
4. Updates cache with latest data

## Usage

### For Users

#### Manual Sync
To manually sync data for offline viewing:
1. Navigate to profile/settings screen
2. Look for "Offline Access" card
3. Tap "Download for Offline" button
4. Wait for sync to complete (progress shown)

#### Automatic Sync
- App automatically syncs when:
  - App starts and data is older than 24 hours
  - User is connected to internet
  - Background sync runs silently (no UI)

### For Developers

#### Initialize Offline Service
```dart
await OfflineDataService.initialize();
```

#### Sync All Data
```dart
final results = await OfflineSyncService.syncAllData(
  userId: user.uid,
  downloadImages: true,
  progressCallback: (dataType, progress, message) {
    // Update UI with progress
  },
);
```

#### Load from Cache
```dart
// Load hotspots
final hotspots = await OfflineDataService.loadHotspots();

// Load events
final events = await OfflineDataService.loadEvents();

// Load trips for user
final trips = await OfflineDataService.loadUserTrips(userId);
```

#### Check Sync Status
```dart
final status = OfflineSyncService.getSyncStatus(userId: userId);
print('Last sync: ${status['hotspots_last_sync']}');
print('Hotspots count: ${status['hotspots_count']}');
```

## Adding UI Components

### Add Sync Status Widget
Add to any screen to show offline status:
```dart
OfflineStatusWidget(
  showSyncButton: true,
)
```

### Show Sync Dialog
```dart
final results = await OfflineSyncDialog.show(
  context,
  userId: user.uid,
  downloadImages: true,
);
```

## Storage Information

- **Hive Boxes**: 
  - `offline_hotspots` - Stores all hotspots
  - `offline_events` - Stores all events
  - `offline_trips` - Stores user trips
  - `offline_metadata` - Stores sync metadata

- **Image Cache**: Uses existing `ImageCacheService` (Hive-based)
  - Images are cached when synced
  - Works automatically with `cached_network_image`

## Best Practices

1. **Always initialize** `OfflineDataService` before using it
2. **Check connectivity** before triggering manual syncs
3. **Use cache-first** repositories for offline support
4. **Background sync** should skip images to save bandwidth
5. **Manual sync** should include images for full offline experience

## Troubleshooting

### Cache Not Updating
- Clear cache: `await OfflineDataService.clearAll()`
- Force sync: Use manual sync button

### Sync Fails
- Check internet connection
- Verify Firestore permissions
- Check logs for specific errors

### Images Not Loading Offline
- Ensure images were downloaded during sync
- Check `ImageCacheService` is initialized
- Verify image URLs are valid

## Future Enhancements

- [ ] Incremental sync (only sync changed items)
- [ ] Sync scheduling (daily/weekly)
- [ ] Selective sync (choose what to sync)
- [ ] Compression for images
- [ ] Background sync service (Android/iOS)

