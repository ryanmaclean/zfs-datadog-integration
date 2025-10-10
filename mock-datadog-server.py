#!/usr/bin/env python3
"""
Mock Datadog Server for Testing ZFS Integration
Captures and validates Events API and DogStatsD metrics
"""

import http.server
import json
import socket
import threading
import sys
from datetime import datetime

# Storage for captured data
events = []
metrics = []

class MockDatadogHTTPHandler(http.server.BaseHTTPRequestHandler):
    """Handler for Datadog Events API"""
    
    def do_POST(self):
        """Handle POST requests (Events API)"""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8")
        
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        try:
            data = json.loads(body)
            event = {
                "timestamp": timestamp,
                "path": self.path,
                "data": data
            }
            events.append(event)
            
            print(f"\n{'='*70}")
            print(f"[{timestamp}] 📨 EVENT RECEIVED")
            print(f"{'='*70}")
            print(f"Title:      {data.get('title', 'N/A')}")
            print(f"Alert Type: {data.get('alert_type', 'N/A')}")
            print(f"Tags:       {', '.join(data.get('tags', []))}")
            print(f"Host:       {data.get('host', 'N/A')}")
            print(f"Text:       {data.get('text', 'N/A')[:100]}")
            print(f"{'='*70}\n")
            
        except json.JSONDecodeError:
            print(f"[{timestamp}] ⚠️  Invalid JSON received")
        
        # Send success response
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        response = {"status": "ok", "event_id": len(events)}
        self.wfile.write(json.dumps(response).encode())
    
    def do_GET(self):
        """Handle GET requests (status endpoint)"""
        if self.path == "/status":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            status = {
                "events_received": len(events),
                "metrics_received": len(metrics),
                "events": events[-10:],  # Last 10 events
                "metrics": metrics[-10:]  # Last 10 metrics
            }
            self.wfile.write(json.dumps(status, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default HTTP logging"""
        pass

def dogstatsd_server(host='0.0.0.0', port=8125):
    """UDP server for DogStatsD metrics"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))
    
    print(f"📊 DogStatsD server listening on {host}:{port}")
    
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            message = data.decode('utf-8').strip()
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            metric = {
                "timestamp": timestamp,
                "message": message,
                "source": addr[0]
            }
            metrics.append(metric)
            
            # Parse metric
            parts = message.split('|')
            if len(parts) >= 2:
                metric_name_value = parts[0].split(':')
                metric_type = parts[1]
                tags = parts[2].replace('#', '') if len(parts) > 2 else ''
                
                print(f"[{timestamp}] 📈 METRIC: {metric_name_value[0]} = {metric_name_value[1]} ({metric_type}) [{tags}]")
        
        except Exception as e:
            print(f"Error processing metric: {e}")

def main():
    """Start both HTTP and UDP servers"""
    print("=" * 70)
    print("🐕 Mock Datadog Server Starting")
    print("=" * 70)
    print()
    
    # Start DogStatsD UDP server in background thread
    statsd_thread = threading.Thread(target=dogstatsd_server, daemon=True)
    statsd_thread.start()
    
    # Start HTTP server for Events API
    http_port = 8080
    print(f"📡 Events API server listening on http://0.0.0.0:{http_port}")
    print(f"   Use: DD_API_URL='http://localhost:{http_port}'")
    print()
    print(f"📊 Status endpoint: http://localhost:{http_port}/status")
    print()
    print("Press Ctrl+C to stop")
    print("="*70)
    print()
    
    server = http.server.HTTPServer(("0.0.0.0", http_port), MockDatadogHTTPHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\nShutting down...")
        print("\n📊 Final Stats:")
        print(f"   Events received: {len(events)}")
        print(f"   Metrics received: {len(metrics)}")
        sys.exit(0)

if __name__ == "__main__":
    main()
