# call_statistics.py - Analytics for emergency calls
from utils.database import Database
from collections import Counter
import matplotlib.pyplot as plt

def generate_statistics():
    """Generate call statistics and analytics"""
    db = Database()
    calls = db.get_all_calls()
    
    if not calls:
        print("No calls to analyze")
        return
    
    print("\n" + "="*80)
    print("📊 EMERGENCY CALL ANALYTICS")
    print("="*80)
    
    # Emergency type distribution
    emergency_types = [c['emergency_type'] for c in calls if c['emergency_type']]
    type_counts = Counter(emergency_types)
    
    print("\n🔹 Emergency Types:")
    for etype, count in type_counts.most_common():
        percentage = (count / len(calls)) * 100
        print(f"   {etype.title()}: {count} ({percentage:.1f}%)")
    
    # Urgency distribution
    urgency_levels = [c.get('urgency_level', 'normal') for c in calls]
    urgency_counts = Counter(urgency_levels)
    
    print("\n🔹 Urgency Levels:")
    for level, count in urgency_counts.most_common():
        print(f"   {level.title()}: {count}")
    
    # Response metrics
    dispatched = sum(1 for c in calls if c.get('nearest_ambulance_id'))
    print(f"\n🔹 Response Rate:")
    print(f"   Dispatched: {dispatched}/{len(calls)} ({dispatched/len(calls)*100:.1f}%)")
    
    # Average ETA
    etas = [c['estimated_arrival_minutes'] for c in calls if c.get('estimated_arrival_minutes')]
    if etas:
        avg_eta = sum(etas) / len(etas)
        print(f"   Average ETA: {avg_eta:.1f} minutes")
    
    print("="*80)

if __name__ == "__main__":
    generate_statistics()
