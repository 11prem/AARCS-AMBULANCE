# database.py - Phase 2 with GPS support
import sqlite3
from datetime import datetime

class Database:
    def __init__(self, db_path='data/emergency.db'):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Create tables with GPS support"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create table with ALL Phase 2 columns
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS emergency_calls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                emergency_type TEXT,
                confidence_score REAL,
                location_text TEXT,
                latitude REAL,
                longitude REAL,
                formatted_address TEXT,
                within_service_area BOOLEAN,
                injuries BOOLEAN,
                injury_count INTEGER,
                is_safe BOOLEAN,
                description TEXT,
                urgency_level TEXT,
                status TEXT DEFAULT 'pending',
                nearest_ambulance_id TEXT,
                estimated_arrival_minutes INTEGER
            )
        ''')
        
        conn.commit()
        conn.close()
        print("✅ Database initialized with GPS support")
    
    def save_call(self, data, location_data=None):
        """Save emergency call with GPS data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        timestamp = datetime.now().isoformat()
        
        # Extract location data if available
        lat, lng, formatted_addr, within_area = None, None, None, None
        if location_data:
            lat = location_data.get('latitude')
            lng = location_data.get('longitude')
            formatted_addr = location_data.get('formatted_address')
            within_area = location_data.get('within_service_area')
        
        cursor.execute('''
            INSERT INTO emergency_calls 
            (timestamp, emergency_type, confidence_score, location_text, 
             latitude, longitude, formatted_address, within_service_area,
             injuries, injury_count, is_safe, description, urgency_level)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            timestamp,
            data.get('emergency_type'),
            data.get('confidence', 0.0),
            data.get('location'),
            lat,
            lng,
            formatted_addr,
            within_area,
            data.get('injuries'),
            data.get('injury_count'),
            data.get('is_safe'),
            data.get('description'),
            data.get('urgency_level', 'normal')
        ))
        
        call_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return call_id
    
    def update_ambulance_dispatch(self, call_id, ambulance_id, eta_minutes):
        """Update call with ambulance dispatch info"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE emergency_calls
            SET nearest_ambulance_id = ?,
                estimated_arrival_minutes = ?,
                status = 'dispatched'
            WHERE id = ?
        ''', (ambulance_id, eta_minutes, call_id))
        
        conn.commit()
        conn.close()
    
    def get_all_calls(self):
        """Retrieve all emergency calls"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM emergency_calls ORDER BY timestamp DESC')
        calls = cursor.fetchall()
        
        conn.close()
        return [dict(call) for call in calls]
