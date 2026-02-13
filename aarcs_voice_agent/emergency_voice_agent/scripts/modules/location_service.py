# location_service.py - Enhanced with Confirmation System
from geopy.geocoders import Nominatim
from geopy.distance import geodesic
from geopy.exc import GeocoderTimedOut, GeocoderServiceError
import time
from .advanced_location_matcher import AdvancedLocationMatcher

class LocationService:
    """Enhanced location service with confirmation system"""
    
    def __init__(self):
        self.geolocator = Nominatim(user_agent="emergency_voice_agent_108")
        self.matcher = AdvancedLocationMatcher()
        self.service_center = (13.0827, 80.2707)  # Chennai
        self.service_radius_km = 100
        
        print("📍 Enhanced Location Service initialized")
    
    def get_coordinates_with_confirmation(self, address_text, voice_out=None):
        """
        Get coordinates with user confirmation for ambiguous locations
        Returns: (location_data, needs_confirmation, alternatives)
        """
        print(f"🔍 Searching: '{address_text}'")
        
        # Try offline database with fuzzy matching first
        match_result = self.matcher.find_best_match(address_text)
        
        if match_result:
            lat, lng = match_result['coordinates']
            confidence = match_result['confidence']
            
            print(f"✅ Found: {match_result['location_name'].title()}")
            print(f"📊 Confidence: {confidence:.1f}%")
            print(f"📍 Coordinates: {lat:.4f}, {lng:.4f}")
            
            location_data = {
                'latitude': lat,
                'longitude': lng,
                'formatted_address': f"{match_result['location_name'].title()}, India",
                'raw_input': address_text,
                'within_service_area': self.is_within_service_area(lat, lng),
                'confidence': confidence,
                'match_type': match_result['match_type']
            }
            
            # Check if ambiguous
            if match_result['is_ambiguous']:
                print("⚠️ Multiple similar locations found!")
                return location_data, True, match_result['alternatives']
            else:
                # High confidence, no confirmation needed
                if confidence >= 95:
                    return location_data, False, []
                else:
                    # Medium confidence, confirm just in case
                    return location_data, True, []
        
        # Fallback to online geocoding
        print("⚠️ Not in offline database, trying online...")
        online_result = self._try_online_geocoding(address_text)
        
        if online_result:
            return online_result, True, []  # Always confirm online results
        
        return None, False, []
    
    def _try_online_geocoding(self, address_text):
        """Fallback online geocoding"""
        search_queries = [
            f"{address_text}, Tamil Nadu, India",
            f"{address_text}, India",
            address_text
        ]
        
        for query in search_queries:
            try:
                location = self.geolocator.geocode(query, timeout=10)
                if location:
                    return {
                        'latitude': location.latitude,
                        'longitude': location.longitude,
                        'formatted_address': location.address,
                        'raw_input': address_text,
                        'within_service_area': self.is_within_service_area(
                            location.latitude, location.longitude
                        ),
                        'confidence': 70,  # Lower confidence for online results
                        'match_type': 'online'
                    }
            except:
                continue
        
        return None
    
    def is_within_service_area(self, lat, lng):
        """Check if within service radius"""
        distance = geodesic(self.service_center, (lat, lng)).kilometers
        return distance <= self.service_radius_km
    
    def get_distance(self, lat1, lng1, lat2, lng2):
        """Calculate distance in kilometers"""
        return geodesic((lat1, lng1), (lat2, lng2)).kilometers
    
    def find_nearest_ambulance(self, caller_lat, caller_lng, ambulances):
        """Find nearest ambulance"""
        if not ambulances:
            return None
        
        nearest = None
        min_distance = float('inf')
        
        for ambulance in ambulances:
            distance = self.get_distance(
                caller_lat, caller_lng,
                ambulance['lat'], ambulance['lng']
            )
            
            if distance < min_distance:
                min_distance = distance
                nearest = ambulance
        
        if nearest:
            nearest['distance_km'] = round(min_distance, 2)
            nearest['eta_minutes'] = round(min_distance / 0.5, 0)
        
        return nearest
