# advanced_location_matcher.py - Advanced Location Matching with Fuzzy Search
from fuzzywuzzy import fuzz, process
from .indian_locations_database import (
    INDIAN_CITIES, CHENNAI_AREAS, BANGALORE_AREAS,
    MUMBAI_AREAS, INDIAN_LANDMARKS
)



class AdvancedLocationMatcher:
    """
    Advanced location matcher with:
    - Fuzzy string matching
    - Confidence scoring
    - Ambiguity detection
    """
    
    def __init__(self):
        # Combine all location databases
        self.all_locations = {}
        self.all_locations.update(INDIAN_CITIES)
        self.all_locations.update(CHENNAI_AREAS)
        self.all_locations.update(BANGALORE_AREAS)
        self.all_locations.update(MUMBAI_AREAS)
        self.all_locations.update(INDIAN_LANDMARKS)
              
        # Minimum confidence threshold
        self.min_confidence = 80  # 80% match required
        self.ambiguity_threshold = 10  # If top 2 matches are within 10% score
        
        print(f"✅ Location matcher initialized with {len(self.all_locations)} locations")
    
    def find_best_match(self, query):
        """
        Find best matching location with confidence score
        Returns: (location_name, coords, confidence, is_ambiguous, alternatives)
        """
        query_lower = query.lower().strip()
        
        # Step 1: Try exact match first (highest confidence)
        if query_lower in self.all_locations:
            coords = self.all_locations[query_lower]
            return {
                'location_name': query_lower,
                'coordinates': coords,
                'confidence': 100,
                'is_ambiguous': False,
                'alternatives': [],
                'match_type': 'exact'
            }
        
        # Step 2: Fuzzy matching with different algorithms
        matches = []
        
        for location_name in self.all_locations.keys():
            # Use multiple matching algorithms for better accuracy
            ratio = fuzz.ratio(query_lower, location_name)
            partial_ratio = fuzz.partial_ratio(query_lower, location_name)
            token_sort_ratio = fuzz.token_sort_ratio(query_lower, location_name)
            token_set_ratio = fuzz.token_set_ratio(query_lower, location_name)
            
            # Weighted average (token_set_ratio is best for word order variations)
            confidence = (
                ratio * 0.2 +
                partial_ratio * 0.2 +
                token_sort_ratio * 0.3 +
                token_set_ratio * 0.3
            )
            
            matches.append({
                'location_name': location_name,
                'confidence': confidence,
                'coordinates': self.all_locations[location_name]
            })
        
        # Sort by confidence
        matches.sort(key=lambda x: x['confidence'], reverse=True)
        
        # Get top matches
        best_match = matches[0]
        second_best = matches[1] if len(matches) > 1 else None
        
        # Check if match is good enough
        if best_match['confidence'] < self.min_confidence:
            return None  # No good match found
        
        # Check for ambiguity (two locations with similar scores)
        is_ambiguous = False
        alternatives = []
        
        if second_best and (best_match['confidence'] - second_best['confidence']) < self.ambiguity_threshold:
            is_ambiguous = True
            # Collect all similar matches
            for match in matches[:5]:  # Top 5 alternatives
                if match['confidence'] >= self.min_confidence:
                    alternatives.append({
                        'name': match['location_name'],
                        'confidence': match['confidence'],
                        'coordinates': match['coordinates']
                    })
        
        return {
            'location_name': best_match['location_name'],
            'coordinates': best_match['coordinates'],
            'confidence': best_match['confidence'],
            'is_ambiguous': is_ambiguous,
            'alternatives': alternatives,
            'match_type': 'fuzzy'
        }
    
    def get_detailed_match_info(self, query):
        """Get detailed information about all potential matches"""
        query_lower = query.lower().strip()
        
        # Get top 10 matches
        matches = process.extract(
            query_lower,
            self.all_locations.keys(),
            scorer=fuzz.token_set_ratio,
            limit=10
        )
        
        results = []
        for location_name, score in matches:
            results.append({
                'name': location_name,
                'confidence': score,
                'coordinates': self.all_locations[location_name]
            })
        
        return results
