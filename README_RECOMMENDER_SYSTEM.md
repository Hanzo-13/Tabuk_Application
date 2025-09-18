# Content Recommender System for Tabuk Application

## Overview

The Content Recommender System is a comprehensive solution that provides personalized destination recommendations to users based on four main categories. It's designed to enhance user engagement and discovery of places in Bukidnon.

## Features

### 🎯 Four Recommendation Categories

1. **For You** - Personalized recommendations based on user preferences and favorites
2. **Popular** - Most visited and well-known destinations in Bukidnon
3. **Nearby** - Destinations close to the user's current location
4. **Discover** - Hidden gems and lesser-known places

### 🚀 Key Capabilities

- **Smart Caching**: 15-minute cache to reduce API calls and improve performance
- **Location-Aware**: Real-time location updates for nearby recommendations
- **Personalized Scoring**: AI-powered scoring system based on user behavior
- **Real-time Updates**: Live favorites and preferences integration
- **Responsive UI**: Beautiful, animated interface with smooth transitions

## Architecture

### Services

#### `ContentRecommenderService`
- Main service for all recommendation operations
- Handles caching, scoring, and data fetching
- Provides methods for each recommendation category

#### `LocationService`
- Manages user location permissions and updates
- Provides real-time location streaming
- Handles location accuracy and distance calculations

### Widgets

#### `RecommendationSectionWidget`
- Reusable component for displaying recommendation sections
- Handles animations and section headers
- Configurable for different recommendation types

#### `HotspotCardWidget`
- Individual destination card with rich information
- Interactive favorites functionality
- Beautiful image display with fallbacks

#### `HotspotDetailsDialog`
- Comprehensive destination information modal
- Rich content display with amenities
- Interactive favorites management

#### `SearchBarWidget`
- Search functionality with filter options
- Clean, modern design with animations

### Models

#### `ScoredHotspot`
- Helper class for recommendation scoring
- Combines hotspot data with calculated scores
- Enables intelligent sorting and filtering

## Usage

### Basic Implementation

```dart
// Get all recommendations
final recommendations = await ContentRecommenderService.getAllRecommendations(
  userLat: userLatitude,
  userLng: userLongitude,
  forYouLimit: 6,
  popularLimit: 6,
  nearbyLimit: 6,
  discoverLimit: 6,
);

// Get specific category
final forYou = await ContentRecommenderService.getForYouRecommendations(limit: 6);
final popular = await ContentRecommenderService.getPopularRecommendations(limit: 6);
final nearby = await ContentRecommenderService.getNearbyRecommendations(
  userLat: latitude,
  userLng: longitude,
  limit: 6,
);
final discover = await ContentRecommenderService.getDiscoverRecommendations(limit: 6);
```

### Using Recommendation Sections

```dart
RecommendationSectionWidget(
  title: 'Just For You',
  subtitle: 'Personalized recommendations',
  categoryKey: 'forYou',
  accentColor: AppColors.homeForYouColor,
  icon: Icons.person_outline,
  hotspots: hotspots,
  animationDelay: 200,
  onViewAll: () => navigateToViewAll(),
)
```

### Location Integration

```dart
final locationService = LocationService();

// Get current position
final position = await locationService.getCurrentPosition();

// Start location updates
await locationService.startLocationUpdates();

// Listen to location changes
locationService.locationStream.listen((position) {
  // Update nearby recommendations
});
```

## Configuration

### Constants

Update `lib/utils/constants.dart` to customize limits:

```dart
// Home screen limits
static const int homeForYouLimit = 6;
static const int homePopularLimit = 6;
static const int homeNearbyLimit = 6;
static const int homeDiscoverLimit = 6;
```

### Colors

Customize section colors in `lib/utils/colors.dart`:

```dart
static const Color homeForYouColor = Colors.blue;
static const Color homeTrendingColor = Colors.orange;
static const Color homeNearbyColor = Colors.green;
static const Color homeSeasonalColor = Colors.purple;
```

## Scoring Algorithm

### For You Recommendations
- **Base Score**: 1.0
- **Favorites Boost**: +5.0
- **Preference Match**: +3.0 per match
- **Category Bonus**: +1.2 to +1.8 based on type
- **Amenities**: +0.5 for restroom/food access

### Popular Recommendations
- **Base Score**: 1.0
- **Known Destinations (Favorites Count)**: +1.8 × ln(1 + favorites)
- **Category Popularity**: +0.6 to +2.2
- **Media Presence (images)**: +0.1 to +0.7
- **Central Areas Bonus**: +1.0 to +1.2 (e.g., Malaybalay, Valencia)
- **Established Spot Bonus**: +0.0 to +0.6 by age
- **Random Factor**: +0.0 to +0.3 for variety 

### Nearby Recommendations
- **Distance-Based**: Closer locations get higher scores (sorted closest-first)
- **Range**: 30km maximum distance 
- **Real-time**: Updates as user moves

### Discover Recommendations
- **Hidden Gems**: Lesser-known categories get higher scores
- **Remote Locations**: +2.0 for off-the-beaten-path municipalities (e.g., Impasugong, Cabanglasan, Kitaotao, Dangcagan, Damulog, Kalilangan)
- **Low Popularity Preference**: −1.5 × ln(1 + favorites) to de-emphasize known spots
- **Unique Features**: +0.6 to +1.0 for special amenities/guides/suggestions

## Performance Features

### Caching Strategy
- **Cache Duration**: 15 minutes
- **Cache Keys**: Separate for each recommendation category
- **Force Refresh**: Available for real-time updates

### Memory Management
- **Stream Management**: Proper disposal of location streams
- **State Management**: Efficient state updates
- **Image Caching**: Built-in image optimization

## Error Handling

The system includes comprehensive error handling:

- **Location Permissions**: Graceful fallback for denied permissions
- **Network Issues**: Retry mechanisms and fallback data
- **Empty States**: User-friendly empty state displays
- **Loading States**: Smooth loading animations

## Customization

### Adding New Categories

1. Update `RecommendationSections` class
2. Add scoring logic in `ContentRecommenderService`
3. Update constants and colors
4. Add to main screen

### Modifying Scoring

Override scoring methods in `ContentRecommenderService`:

```dart
static List<ScoredHotspot> _scoreHotspotsForUser(
  List<Hotspot> hotspots,
  Map<String, dynamic>? preferences,
  List<String> favorites,
) {
  // Custom scoring logic here
}
```

## Dependencies

### Required Packages
```yaml
dependencies:
  geolocator: ^latest
  cloud_firestore: ^latest
  firebase_auth: ^latest
  flutter: ^latest
```

### Optional Enhancements
```yaml
dependencies:
  cached_network_image: ^latest  # For better image handling
  shared_preferences: ^latest    # For local preferences
```

## Best Practices

### Performance
- Use caching for frequently accessed data
- Implement lazy loading for large lists
- Optimize image loading and caching

### User Experience
- Provide clear loading states
- Handle empty states gracefully
- Implement smooth animations

### Security
- Validate user permissions
- Sanitize user inputs
- Implement proper error boundaries

## Troubleshooting

### Common Issues

1. **Location Not Working**
   - Check location permissions
   - Verify GPS is enabled
   - Test with location service

2. **Recommendations Not Loading**
   - Check Firebase connection
   - Verify data structure
   - Check cache settings

3. **Performance Issues**
   - Reduce cache duration
   - Limit recommendation counts
   - Optimize image loading

### Debug Mode

Enable debug logging:

```dart
if (kDebugMode) {
  print('Debug info: $data');
}
```

## Future Enhancements

### Planned Features
- **Machine Learning**: Advanced recommendation algorithms
- **Social Features**: User reviews and ratings
- **Offline Support**: Local recommendation storage
- **Analytics**: User behavior tracking

### Integration Opportunities
- **Maps Integration**: Interactive map views
- **Social Media**: Share recommendations
- **Notifications**: Location-based alerts
- **Gamification**: Points and achievements

## Support

For questions or issues:
1. Check the troubleshooting section
2. Review the code examples
3. Check Firebase configuration
4. Verify all dependencies are installed

---

**Note**: This system is designed to be scalable and maintainable. Follow the established patterns when making modifications or adding new features.
