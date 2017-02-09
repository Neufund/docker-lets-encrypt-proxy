#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

class Handler(BaseHTTPRequestHandler):
    
    def do_HEAD(self):
        self.send_response(200)
        self.url = urlparse(self.path)
        self.query = parse_qs(self.url.query)
        for key, value in self.query.items():
            if key == 'content':
                continue
            self.send_header(key, value[0])
        self.end_headers()
    
    def do(self):
        self.do_HEAD()
        if 'content' in self.query:
            self.wfile.write(self.query['content'][0].encode('utf8'))
    
    def do_GET(self):
        self.do()
    
    def do_POST(self):
        self.do()

# Server on port 80
httpd = HTTPServer(("", 8000), Handler)
httpd.serve_forever()
