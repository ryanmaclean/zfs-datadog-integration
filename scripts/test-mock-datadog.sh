#!/bin/bash
#
# Mock Datadog Server for Testing
# Runs a simple HTTP server to capture Datadog API calls
# Run this in the VM to test without real Datadog credentials
#

echo "Starting Mock Datadog Server..."
echo "This will capture API calls from zedlets"
echo ""

# Create a simple Python server to log requests
python3 -c '
import http.server
import json
from datetime import datetime

class MockDatadogHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8")
        
        print(f"\n{'='*60}")
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Received Event")
        print(f"{'='*60}")
        print(f"Path: {self.path}")
        print(f"Headers: {dict(self.headers)}")
        print(f"Body: {body}")
        
        try:
            data = json.loads(body)
            print(f"\nParsed Event:")
            print(f"  Title: {data.get('title')}")
            print(f"  Alert Type: {data.get('alert_type')}")
            print(f"  Tags: {data.get('tags')}")
            print(f"  Text: {data.get('text')}")
        except:
            pass
        
        print(f"{'='*60}\n")
        
        # Send success response
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "ok"}')
    
    def log_message(self, format, *args):
        pass  # Suppress default logging

print("Mock Datadog API Server running on http://localhost:8080")
print("Modify zfs-datadog-lib.sh to use: DD_API_URL='http://localhost:8080'")
print("Press Ctrl+C to stop\n")

server = http.server.HTTPServer(("0.0.0.0", 8080), MockDatadogHandler)
server.serve_forever()
' || echo "Python3 not available"
