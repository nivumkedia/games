#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
import json, subprocess, os

class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/notify':
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length))
            title = body.get('title', 'Notification')
            message = body.get('message', '')
            # Send persistent macOS alert
            subprocess.Popen([
                'osascript', '-e',
                f'display alert "{title}" message "{message}"'
            ])
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

os.chdir(os.path.dirname(os.path.abspath(__file__)))
print("Serving on http://localhost:8091 (game hub + notifications)")
HTTPServer(('', 8091), Handler).serve_forever()
