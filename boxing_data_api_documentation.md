# Boxing Data API Documentation

## API Overview
**Base URL:** `https://boxing-data-api.p.rapidapi.com/v1`
**Authentication:** RapidAPI Key required in headers

## Available Endpoints

### 1. Get Fights (Full Fight Cards)
**Endpoint:** `/fights`
**Method:** GET
**Description:** Returns all fights with full card structure including undercard bouts

**Response Structure:**
```json
{
  "title": "Fighter1 vs Fighter2",
  "date": "ISO 8601 date",
  "status": "NOT_STARTED/COMPLETED",
  "fighters": {
    "fighter_1": {"name": "", "full_name": "", "fighter_id": ""},
    "fighter_2": {"name": "", "full_name": "", "fighter_id": ""}
  },
  "scheduled_rounds": 10,
  "venue": "Venue Name",
  "event": {
    "id": "event_id",
    "title": "Main Event Title",
    "promotion": "Promoter"
  },
  "division": {
    "name": "Weight Class",
    "weight_lb": 140,
    "weight_kg": 63.5
  },
  "titles": [{"name": "Championship Title"}]
}
```

### 2. Get Fighters
**Endpoint:** `/fighters`
**Method:** GET
**Description:** Returns fighter profiles with stats

**Response Structure:**
```json
{
  "name": "Fighter Name",
  "age": 31,
  "height": "5' 10\"",
  "nationality": "Country",
  "reach": "69\"",
  "stance": "orthodox/southpaw",
  "stats": {
    "wins": 21,
    "losses": 4,
    "draws": 0,
    "ko_percentage": 48,
    "ko_wins": 10
  },
  "division": {"name": "Weight Class"},
  "titles": []
}
```

### 3. Get All Events
**Endpoint:** `/events`
**Method:** GET
**Description:** Returns a list of all boxing events

**Response Structure:**
```json
[
  {
    "title": "Event Title",
    "date": "ISO 8601 date string",
    "location": "Venue, City, Country",
    "venue": "Venue Name",
    "broadcasters": [{"Country": "Network"}],
    "broadcast": [{"country": "Country", "broadcasters": ["Network"]}],
    "promotion": "Promoter Name",
    "co_promotion": ["Co-promoters"],
    "id": "unique_event_id",
    "poster_image_url": "URL to poster image"
  }
]
```

### 2. Get Specific Event
**Endpoint:** `/events/{id}`
**Method:** GET
**Description:** Returns detailed information for a specific event

**Response:** Same structure as individual event in list, with additional fields:
- `ring_announcers`: Array of ring announcer names
- `tv_announcers`: Array of TV announcer names

### 3. Search Events with Pagination
**Endpoint:** `/events/`
**Method:** GET
**Parameters:**
- `page_num`: Page number (default: 1)
- `page_size`: Results per page (default: 25)
- `date_sort`: Sort order (DESC/ASC)

### 4. Get Event Schedule
**Endpoint:** `/events/schedule`
**Method:** GET
**Parameters:**
- `days`: Number of days ahead to look (max depends on subscription)
- `past_hours`: Include events from past hours
- `date_sort`: Sort order (ASC/DESC)
- `page_num`: Page number
- `page_size`: Results per page

**Note:** Free tier has date range limitations (typically 14-day window)

## Key Features
- Real-time event updates
- Comprehensive event details including venue, promotion, and broadcast info
- Poster images for events
- Pagination support for large result sets
- Schedule filtering by date range

## Limitations
- Date range restrictions on free tier (approximately 2-week window)
- No fighter-specific data in the tested endpoints
- No fight results or historical data observed
- Limited to event scheduling information

## Integration Benefits
1. **Current Events:** Provides up-to-date boxing event information
2. **Rich Metadata:** Includes venue, promotion, broadcast details
3. **Visual Content:** Poster images for events
4. **Reliable Structure:** Consistent JSON response format

## Recommended Use Cases
- Displaying upcoming boxing events
- Event schedule calendars
- Broadcast information for fans
- Event promotion details