# real_time_monitor.py - UPDATED with final summary table
import socket
import json
import threading
import time
import os
from datetime import datetime
from colorama import init, Fore, Style

init(autoreset=True)

class RealTimeMonitor:
    def __init__(self, host='localhost', port=5555):
        self.host = host
        self.port = port
        self.running = True
        
        # Data storage
        self.conversation = []
        self.call_summary = {}
        self.ambulance_data = {
            'id': 'Not dispatched',
            'status': 'idle',
            'distance_km': 0,
            'speed_kmh': 0,
            'eta_minutes': 0,
            'departure_time': '--:--:--',
            'arrival_time': '--:--:--',
            'last_update': 'Never'
        }
        self.emergency_info = {
            'type': 'Unknown',
            'location': 'Not provided',
            'urgency': 'Normal'
        }
        self.call_active = False
        self.call_start_time = None
        self.final_summary_displayed = False
        
        # Socket server
        self.server = None
        self.client = None
        
        print(Fore.GREEN + "🚨 Real-Time Emergency Monitor Initialized" + Style.RESET_ALL)
        print(Fore.YELLOW + f"📡 Listening on {host}:{port}" + Style.RESET_ALL)
    
    def start_server(self):
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind((self.host, self.port))
        self.server.listen(1)
        
        print(Fore.CYAN + "⏳ Waiting for NLP system to connect..." + Style.RESET_ALL)
        
        accept_thread = threading.Thread(target=self.accept_connections, daemon=True)
        accept_thread.start()
    
    def accept_connections(self):
        while self.running:
            try:
                self.client, addr = self.server.accept()
                print(Fore.GREEN + f"✅ Connected to NLP system" + Style.RESET_ALL)
                
                receive_thread = threading.Thread(target=self.receive_data, daemon=True)
                receive_thread.start()
                
            except:
                break
    
    def receive_data(self):
        buffer = ""
        while self.running and self.client:
            try:
                data = self.client.recv(4096).decode()
                if not data:
                    break
                
                buffer += data
                
                while '\n' in buffer:
                    message, buffer = buffer.split('\n', 1)
                    if message.strip():
                        self.process_message(message.strip())
                        
            except:
                break
        
        print(Fore.YELLOW + "⚠️  NLP system disconnected" + Style.RESET_ALL)
        self.client = None
    
    def process_message(self, message_json):
        try:
            data = json.loads(message_json)
            msg_type = data.get('type')
            msg_data = data.get('data', {})
            timestamp = data.get('timestamp', datetime.now().isoformat())
            
            if msg_type == 'user_speech':
                self.conversation.append({
                    'time': datetime.fromisoformat(timestamp).strftime("%H:%M:%S"),
                    'speaker': 'user',
                    'message': msg_data.get('text', '')
                })
                
            elif msg_type == 'ai_response':
                self.conversation.append({
                    'time': datetime.fromisoformat(timestamp).strftime("%H:%M:%S"),
                    'speaker': 'ai',
                    'message': msg_data.get('text', '')
                })
                
            elif msg_type == 'emergency_info':
                self.emergency_info.update(msg_data)
                
            elif msg_type == 'location_info':
                self.emergency_info['location_details'] = msg_data
                if 'address' in msg_data:
                    self.emergency_info['location'] = msg_data['address']
                
            elif msg_type == 'ambulance_info':
                self.ambulance_data.update(msg_data)
                self.ambulance_data['last_update'] = datetime.now().strftime("%H:%M:%S")
                
            elif msg_type == 'call_started':
                self.call_active = True
                self.final_summary_displayed = False
                self.call_start_time = datetime.now()
                self.conversation = []
                print(Fore.GREEN + "📞 New emergency call started!" + Style.RESET_ALL)
                
            elif msg_type == 'call_summary':
                self.call_summary = msg_data
                
            elif msg_type == 'call_ended':
                self.call_active = False
                print(Fore.YELLOW + "\n📞 Emergency call completed" + Style.RESET_ALL)
                print(Fore.CYAN + "Displaying final summary... (Press Ctrl+C to exit monitor)" + Style.RESET_ALL)
                self.final_summary_displayed = True
                self.display_final_summary_table()
                
        except json.JSONDecodeError as e:
            print(Fore.RED + f"❌ JSON error: {e}" + Style.RESET_ALL)
        except Exception as e:
            print(Fore.RED + f"❌ Error: {e}" + Style.RESET_ALL)
    
    def display_final_summary_table(self):
        """Display final summary in a formatted table"""
        time.sleep(2)  # Give time for final data to arrive
        self.clear_screen()
        
        print(Fore.GREEN + "╔════════════════════════════════════════════════════════════════════════════════╗")
        print(Fore.GREEN + "║                         FINAL CALL SUMMARY - COMPLETE                         ║")
        print(Fore.GREEN + "╠════════════════════════════════════════════════════════════════════════════════╣")
        
        if self.call_summary:
            summary = self.call_summary
            
            # Emergency Information Table
            print(Fore.CYAN + "📋 EMERGENCY INFORMATION" + Style.RESET_ALL)
            print(Fore.WHITE + "─" * 80)
            
            table_data = [
                ["Call ID:", f"{summary.get('call_id', 'N/A')}"],
                ["Emergency Type:", f"{summary.get('emergency_type', 'Unknown').upper()}"],
                ["Location:", f"{summary.get('location', 'Not provided')}"],
                ["Timestamp:", f"{summary.get('timestamp', 'N/A')}"],
                ["Call Duration:", f"{summary.get('duration', 'N/A')}"],
                ["Questions Asked:", f"{summary.get('questions_asked', 0)}"],
                ["Injuries:", f"{'✅ Yes' if summary.get('injuries') else '❌ No'}"],
                ["Currently Safe:", f"{'✅ Yes' if summary.get('is_safe') else '❌ No'}"],
                ["Urgency Level:", f"{summary.get('urgency', 'Normal').upper()}"]
            ]
            
            for label, value in table_data:
                print(f"{Fore.CYAN}{label:<20} {Fore.WHITE}{value}")
            
            print()
            
            # Location Details
            if 'location_details' in summary:
                loc = summary['location_details']
                print(Fore.CYAN + "📍 LOCATION DETAILS" + Style.RESET_ALL)
                print(Fore.WHITE + "─" * 80)
                print(f"{Fore.CYAN}Address:{Fore.WHITE} {loc.get('address', 'N/A')}")
                print(f"{Fore.CYAN}Coordinates:{Fore.WHITE} {loc.get('coordinates', 'N/A')}")
                print(f"{Fore.CYAN}Latitude:{Fore.WHITE} {loc.get('latitude', 'N/A')}")
                print(f"{Fore.CYAN}Longitude:{Fore.WHITE} {loc.get('longitude', 'N/A')}")
                print()
            
            # Ambulance Details Table
            if 'ambulance' in summary:
                amb = summary['ambulance']
                print(Fore.RED + "🚑 AMBULANCE DISPATCH DETAILS" + Style.RESET_ALL)
                print(Fore.WHITE + "─" * 80)
                
                amb_table = [
                    ["Ambulance ID:", f"{amb.get('id', 'N/A')}"],
                    ["Status:", f"{amb.get('status', 'Unknown').upper()}"],
                    ["Distance:", f"{amb.get('distance_km', 0):.1f} km"],
                    ["Speed:", f"{amb.get('speed_kmh', 0)} km/h"],
                    ["ETA:", f"{amb.get('eta_minutes', 0)} minutes"],
                    ["Departure Time:", f"{amb.get('departure_time', 'N/A')}"],
                    ["Expected Arrival:", f"{amb.get('arrival_time', 'N/A')}"]
                ]
                
                for label, value in amb_table:
                    print(f"{Fore.CYAN}{label:<20} {Fore.WHITE}{value}")
                
                # Visual progress bar for ETA
                eta = amb.get('eta_minutes', 0)
                if eta > 0:
                    print(f"\n{Fore.CYAN}Progress:{Fore.WHITE} ", end="")
                    total_segments = 20
                    progress = min(100, (60 - eta) / 60 * 100)  # Assuming 60 min max
                    filled = int(total_segments * progress / 100)
                    print(f"{Fore.GREEN}{'█' * filled}{Fore.YELLOW}{'░' * (total_segments - filled)} {progress:.0f}%")
                print()
        
        # FULL CONVERSATION LOG
        print(Fore.MAGENTA + "💬 COMPLETE CONVERSATION LOG" + Style.RESET_ALL)
        print(Fore.WHITE + "─" * 80)
        
        if self.conversation:
            for conv in self.conversation:
                time_str = conv.get('time', '--:--:--')
                speaker = conv.get('speaker', 'unknown')
                message = conv.get('message', '')
                
                if speaker == 'user':
                    print(f"{Fore.WHITE}[{time_str}] {Fore.CYAN}👤 USER: {Fore.WHITE}{message}")
                else:
                    print(f"{Fore.WHITE}[{time_str}] {Fore.GREEN}🤖 AI: {Fore.WHITE}{message}")
        else:
            print(Fore.YELLOW + "No conversation recorded" + Style.RESET_ALL)
        
        print()
        print(Fore.GREEN + "╠════════════════════════════════════════════════════════════════════════════════╣")
        print(Fore.YELLOW + "📊 Call Summary Complete | 💾 Data Saved to File | 🚨 Ready for Next Call" + Style.RESET_ALL)
        print(Fore.CYAN + "Press Ctrl+C to exit monitor and start new NLP call" + Style.RESET_ALL)
        print(Fore.GREEN + "╚════════════════════════════════════════════════════════════════════════════════╝")
        
        # Save summary to file
        self.save_summary_to_file()
    
    def save_summary_to_file(self):
        summary_data = {
            'timestamp': datetime.now().isoformat(),
            'emergency_info': self.emergency_info,
            'ambulance_data': self.ambulance_data,
            'conversation': self.conversation,
            'call_summary': self.call_summary,
            'call_duration': str(datetime.now() - self.call_start_time) if self.call_start_time else "N/A"
        }
        
        os.makedirs('call_summaries', exist_ok=True)
        filename = f"call_summaries/summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(summary_data, f, indent=2)
        
        print(Fore.GREEN + f"\n💾 Full summary saved to: {filename}" + Style.RESET_ALL)
    
    def clear_screen(self):
        os.system('cls' if os.name == 'nt' else 'clear')
    
    def create_dashboard(self):
        """Create and display the real-time dashboard"""
        if self.final_summary_displayed:
            # Don't update dashboard when showing final summary
            time.sleep(1)
            return
            
        self.clear_screen()
        
        # Header
        print(Fore.BLUE + "╔══════════════════════════════════════════════════════════════════════╗")
        print(Fore.RED + "║              108 EMERGENCY - LIVE CALL MONITOR                      ║")
        print(Fore.BLUE + "╠══════════════════════════════════════════════════════════════════════╣")
        
        # Current time and status
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        status_color = Fore.GREEN if self.call_active else Fore.YELLOW
        status_text = "📞 LIVE CALL IN PROGRESS" if self.call_active else "⏸️  NO ACTIVE CALL"
        
        print(f"{Fore.CYAN}🕒 {current_time} | {status_color}{status_text}{Style.RESET_ALL}")
        print(Fore.BLUE + "╠══════════════════════════════════════════════════════════════════════╣")
        
        # Emergency Information
        if self.call_active:
            print(Fore.GREEN + "📋 ACTIVE EMERGENCY" + Style.RESET_ALL)
            print(Fore.WHITE + "─" * 70)
            
            emergency_icons = {
                'ACCIDENT': '🚗',
                'MEDICAL': '🏥',
                'FIRE': '🔥',
                'ASSAULT': '👊'
            }
            
            icon = emergency_icons.get(self.emergency_info['type'].upper(), '🚨')
            
            print(f"{Fore.CYAN}• Type: {Fore.WHITE}{icon} {self.emergency_info['type']}")
            print(f"{Fore.CYAN}• Location: {Fore.WHITE}{self.emergency_info['location']}")
            print(f"{Fore.CYAN}• Urgency: {Fore.WHITE}{self.emergency_info['urgency'].upper()}")
            print()
        
        # Ambulance Status Table
        print(Fore.MAGENTA + "🚑 AMBULANCE STATUS" + Style.RESET_ALL)
        print(Fore.WHITE + "─" * 70)
        
        # Create a mini table
        print(f"{Fore.CYAN}{'Parameter':<15} {Fore.WHITE}{'Value':<15} {Fore.CYAN}{'Unit':<10}")
        print(Fore.WHITE + "─" * 45)
        
        table_data = [
            ["ID", self.ambulance_data['id'], ""],
            ["Status", self.ambulance_data['status'].upper(), ""],
            ["Distance", f"{self.ambulance_data['distance_km']:.1f}", "km"],
            ["Speed", f"{self.ambulance_data['speed_kmh']}", "km/h"],
            ["ETA", f"{self.ambulance_data['eta_minutes']}", "min"],
            ["Departure", self.ambulance_data['departure_time'], ""],
            ["Arrival", self.ambulance_data['arrival_time'], ""]
        ]
        
        for param, value, unit in table_data:
            print(f"{Fore.CYAN}{param:<15} {Fore.WHITE}{value:<15} {Fore.YELLOW}{unit:<10}")
        
        print(f"\n{Fore.CYAN}Last Update: {Fore.YELLOW}{self.ambulance_data['last_update']}")
        print()
        
        # LIVE CONVERSATION
        print(Fore.CYAN + "💬 LIVE CONVERSATION" + Style.RESET_ALL)
        print(Fore.WHITE + "─" * 70)
        
        if self.conversation:
            total_messages = len(self.conversation)
            start_idx = max(0, total_messages - 10)
            
            if start_idx > 0:
                print(Fore.YELLOW + f"... showing last 10 of {total_messages} messages ..." + Style.RESET_ALL)
            
            for conv in self.conversation[start_idx:]:
                time_str = conv.get('time', '--:--:--')
                speaker = conv.get('speaker', 'unknown')
                message = conv.get('message', '')
                
                if len(message) > 65:
                    message = message[:62] + "..."
                
                if speaker == 'user':
                    print(f"{Fore.WHITE}[{time_str}] {Fore.CYAN}👤 USER: {Fore.WHITE}{message}")
                else:
                    print(f"{Fore.WHITE}[{time_str}] {Fore.GREEN}🤖 AI: {Fore.WHITE}{message}")
        else:
            print(Fore.YELLOW + "Waiting for conversation..." + Style.RESET_ALL)
        
        # Footer
        print()
        print(Fore.BLUE + "╠══════════════════════════════════════════════════════════════════════╣")
        
        if self.client:
            print(Fore.GREEN + "✅ CONNECTED to NLP System | 🎤 Voice-Only Mode Active" + Style.RESET_ALL)
        else:
            print(Fore.RED + "❌ DISCONNECTED - Run main_ai.py to connect" + Style.RESET_ALL)
        
        print(Fore.CYAN + "Press Ctrl+C to exit" + Style.RESET_ALL)
        print(Fore.BLUE + "╚══════════════════════════════════════════════════════════════════════╝")
    
    def run(self):
        self.start_server()
        
        try:
            while self.running:
                if not self.final_summary_displayed:
                    self.create_dashboard()
                time.sleep(1)
        except KeyboardInterrupt:
            print(f"\n{Fore.YELLOW}🛑 Monitor stopped" + Style.RESET_ALL)
            self.running = False
        finally:
            if self.server:
                self.server.close()

class MonitorClient:
    def __init__(self, host='localhost', port=5555):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.connect()
    
    def connect(self):
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            self.connected = True
            print(Fore.GREEN + "✅ Connected to real-time monitor" + Style.RESET_ALL)
        except ConnectionRefusedError:
            print(Fore.YELLOW + "⚠️  Monitor not running. Run real_time_monitor.py first!" + Style.RESET_ALL)
            self.connected = False
        except Exception as e:
            print(Fore.RED + f"❌ Connection error: {e}" + Style.RESET_ALL)
            self.connected = False
    
    def send(self, msg_type, data):
        if not self.connected:
            return False
        
        try:
            message = json.dumps({
                'type': msg_type,
                'timestamp': datetime.now().isoformat(),
                'data': data
            }) + '\n'
            self.socket.sendall(message.encode())
            return True
        except:
            self.connected = False
            return False
    
    def close(self):
        if self.socket:
            self.socket.close()

def main():
    print(Fore.MAGENTA + """
    ╔═══════════════════════════════════════════════════╗
    ║        108 EMERGENCY - REAL-TIME MONITOR         ║
    ║    Shows Live Call Log & Emergency Information   ║
    ╚═══════════════════════════════════════════════════╝
    """ + Style.RESET_ALL)
    
    print("\n" + Fore.CYAN + "📊 Features:" + Style.RESET_ALL)
    print(Fore.WHITE + "  • Voice-only mode (no typing)")
    print("  • Real-time ambulance tracking with speed")
    print("  • Complete call log with timestamps")
    print("  • Final summary table after call completion")
    print("  • Automatic data saving to JSON files" + Style.RESET_ALL)
    
    print("\n" + Fore.GREEN + "="*80 + Style.RESET_ALL)
    
    monitor = RealTimeMonitor()
    monitor.run()

if __name__ == "__main__":
    main()