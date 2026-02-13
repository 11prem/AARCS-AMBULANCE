# test_location_accuracy.py - Test location matching accuracy
from modules.advanced_location_matcher import AdvancedLocationMatcher

matcher = AdvancedLocationMatcher()

print("=" * 80)
print("🧪 TESTING ENHANCED LOCATION MATCHING")
print("=" * 80)

# Test cases with similar names
test_cases = [
    "Bharath Institute of Science and Technology",
    "SRM Institute of Science and Technology",
    "Bharath University",
    "SRM University",
    "BITS Pilani",
    "Anna University",
    "IIT Madras",
    "MIT Chennai",
    "Phoenix Mall",
    "Express Avenue",
    "Tambaram",
    "Velachery"
]

for test in test_cases:
    print(f"\n{'='*80}")
    print(f"🔍 Input: '{test}'")
    print("-"*80)
    
    result = matcher.find_best_match(test)
    
    if result:
        print(f"✅ Best Match: {result['location_name'].title()}")
        print(f"📍 Coordinates: {result['coordinates']}")
        print(f"📊 Confidence: {result['confidence']:.1f}%")
        print(f"🎯 Match Type: {result['match_type']}")
        
        if result['is_ambiguous']:
            print(f"⚠️ AMBIGUOUS - {len(result['alternatives'])} similar locations:")
            for i, alt in enumerate(result['alternatives'], 1):
                print(f"   {i}. {alt['name'].title()} ({alt['confidence']:.1f}%)")
    else:
        print("❌ No match found")

print("\n" + "="*80)
