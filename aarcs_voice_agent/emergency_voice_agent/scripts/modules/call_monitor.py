# call_monitor.py - Real-time call monitoring dashboard
from database import Database
from datetime import datetime
import os

def display_all_calls():
    """Display all emergency calls with detailed info"""
    db = Database()
    calls = db.get_all_calls()
    
    os.system('cls' if os.name == 'nt' else 'clear')
    
    print("\n" + "="*100)
    print("📊 108 EMERGENCY SERVICE - CALL MONITORING DASHBOARD")
    print("="*100)
    print(f"⏰ Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📞 Total Calls: {len(calls)}")
    print("="*100)
    
    if not calls:
        print("\n📭 No emergency calls recorded yet.")
        return
    
    # Display each call
    for i, call in enumerate(calls, 1):
        urgency_emoji = {
            'critical': '🔴',
            'urgent': '🟠',
            'normal': '🟢'
        }.get(call.get('urgency_level', 'normal'), '⚪')
        
        print(f"\n{urgency_emoji} CALL #{i} - ID: {call['id']}")
        print("-"*100)
        print(f"   📅 Timestamp: {call['timestamp']}")
        print(f"   🚨 Emergency Type: {call['emergency_type'].upper() if call['emergency_type'] else 'Unknown'}")
        print(f"   ⚡ Urgency: {call.get('urgency_level', 'normal').upper()}")
        
        if call.get('confidence_score'):
            print(f"   🤖 ML Confidence: {call['confidence_score']:.1%}")
        
        # Location
        if call.get('latitude') and call.get('longitude'):
            print(f"   📍 Location: {call['formatted_address']}")
            print(f"   🗺️ GPS: ({call['latitude']:.4f}, {call['longitude']:.4f})")
            print(f"   {'✅' if call.get('within_service_area') else '⚠️'} Service Area: {'Yes' if call.get('within_service_area') else 'No'}")
        else:
            print(f"   📍 Location: {call.get('location_text', 'Not provided')}")
        
        # Incident details
        print(f"   🩹 Injuries: {'Yes' if call.get('injuries') else 'No'}", end='')
        if call.get('injury_count'):
            print(f" ({call['injury_count']} person(s))")
        else:
            print()
        
        print(f"   🛡️ Currently Safe: {'Yes' if call.get('is_safe') else 'No'}")
        
        # Ambulance status
        if call.get('nearest_ambulance_id'):
            print(f"   🚑 Ambulance: {call['nearest_ambulance_id']}")
            print(f"   ⏱️ ETA: {call['estimated_arrival_minutes']} minutes")
            print(f"   📊 Status: {call['status'].upper()}")
        else:
            print(f"   📊 Status: {call['status'].upper()}")
        
        print("-"*100)
    
    # Statistics
    print("\n" + "="*100)
    print("📊 STATISTICS")
    print("="*100)
    
    critical = sum(1 for c in calls if c.get('urgency_level') == 'critical')
    urgent = sum(1 for c in calls if c.get('urgency_level') == 'urgent')
    normal = sum(1 for c in calls if c.get('urgency_level') == 'normal')
    
    print(f"🔴 Critical: {critical} | 🟠 Urgent: {urgent} | 🟢 Normal: {normal}")
    
    dispatched = sum(1 for c in calls if c.get('nearest_ambulance_id'))
    print(f"🚑 Dispatched: {dispatched}/{len(calls)} ({dispatched/len(calls)*100:.1f}%)")
    
    print("="*100)

if __name__ == "__main__":
    display_all_calls()
