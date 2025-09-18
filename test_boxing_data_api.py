import requests
from datetime import datetime, timedelta
import json

class BoxingDataAPI:
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://boxing-data-api.p.rapidapi.com/v1"
        self.headers = {
            "x-rapidapi-host": "boxing-data-api.p.rapidapi.com",
            "x-rapidapi-key": api_key
        }

    def get_all_events(self):
        """Get all boxing events"""
        url = f"{self.base_url}/events"
        response = requests.get(url, headers=self.headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error: {response.status_code}")
            return None

    def get_event_by_id(self, event_id):
        """Get specific event details by ID"""
        url = f"{self.base_url}/events/{event_id}"
        response = requests.get(url, headers=self.headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error: {response.status_code}")
            return None

    def search_events(self, page_num=1, page_size=25, date_sort="DESC"):
        """Search events with pagination"""
        url = f"{self.base_url}/events/"
        params = {
            "page_num": page_num,
            "page_size": page_size,
            "date_sort": date_sort
        }
        response = requests.get(url, headers=self.headers, params=params)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error: {response.status_code}")
            return None

    def get_schedule(self, days=7, past_hours=12, date_sort="ASC", page_num=1, page_size=25):
        """Get event schedule for specified time period"""
        url = f"{self.base_url}/events/schedule"
        params = {
            "days": days,
            "past_hours": past_hours,
            "date_sort": date_sort,
            "page_num": page_num,
            "page_size": page_size
        }
        response = requests.get(url, headers=self.headers, params=params)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error: {response.status_code}")
            print(f"Response: {response.text}")
            return None

    def format_event_display(self, event):
        """Format event for display"""
        date_obj = datetime.fromisoformat(event['date'].replace('Z', '+00:00'))
        formatted_date = date_obj.strftime("%B %d, %Y at %I:%M %p")

        output = f"\n{'='*60}\n"
        output += f"Event: {event['title']}\n"
        output += f"Date: {formatted_date}\n"
        output += f"Location: {event.get('location', 'TBA')}\n"
        output += f"Venue: {event.get('venue', 'TBA')}\n"

        if event.get('promotion'):
            output += f"Promotion: {event['promotion']}\n"

        if event.get('broadcasters'):
            broadcasters = []
            for broadcaster in event['broadcasters']:
                for country, network in broadcaster.items():
                    broadcasters.append(f"{country}: {network}")
            output += f"Broadcast: {', '.join(broadcasters)}\n"

        if event.get('poster_image_url'):
            output += f"Poster: {event['poster_image_url']}\n"

        return output

def main():
    # Your RapidAPI key
    API_KEY = "c050e36faamshb3c100793a53076p19a527jsn589f090905a5"

    # Initialize API client
    api = BoxingDataAPI(API_KEY)

    print("Boxing Data API Test\n")
    print("="*60)

    # Test 1: Get upcoming schedule (7 days)
    print("\n1. UPCOMING EVENTS (Next 7 Days):")
    schedule = api.get_schedule(days=7)
    if schedule:
        if isinstance(schedule, list):
            for event in schedule[:5]:  # Show first 5 events
                print(api.format_event_display(event))
        else:
            print("No events found or error in response")

    # Test 2: Search events with pagination
    print("\n2. SEARCH EVENTS (Page 1, Latest First):")
    events = api.search_events(page_num=1, page_size=5, date_sort="DESC")
    if events:
        for event in events[:3]:  # Show first 3 events
            print(api.format_event_display(event))

    # Test 3: Get specific event details
    print("\n3. SPECIFIC EVENT DETAILS:")
    # Using Canelo vs Crawford event ID from earlier test
    event_id = "682a0c659912d4416a13bff4"
    event_details = api.get_event_by_id(event_id)
    if event_details:
        print(api.format_event_display(event_details))

        # Show additional details if available
        if event_details.get('ring_announcers'):
            print(f"Ring Announcers: {', '.join(event_details['ring_announcers'])}")
        if event_details.get('tv_announcers'):
            print(f"TV Announcers: {', '.join(event_details['tv_announcers'])}")
        if event_details.get('co_promotion'):
            print(f"Co-Promotions: {', '.join(event_details['co_promotion'])}")

if __name__ == "__main__":
    main()