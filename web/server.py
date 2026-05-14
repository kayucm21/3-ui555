#!/usr/bin/env python3
#============================================================================
# 3x-ui - Лёгкий веб-сервер с Basic Auth
# Оптимизировано для 512MB RAM
#============================================================================

import http.server
import socketserver
import base64
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
AUTH_FILE = "/etc/3x-ui/panel_credentials.txt"
WEB_DIR = "/etc/3x-ui/web"

def get_credentials():
    user = "admin"
    passwd = "admin"
    try:
        with open(AUTH_FILE, "r") as f:
            for line in f:
                if line.startswith("Username:"):
                    user = line.split(":", 1)[1].strip()
                elif line.startswith("Password:"):
                    passwd = line.split(":", 1)[1].strip()
    except:
        pass
    return user, passwd

VALID_USER, VALID_PASS = get_credentials()
VALID_AUTH = base64.b64encode(f"{VALID_USER}:{VALID_PASS}".encode()).decode()

class AuthHandler(http.server.SimpleHTTPRequestHandler):
    def do_AUTHHEAD(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="3x-ui Panel"')
        self.send_header("Content-type", "text/html")
        self.end_headers()

    def do_GET(self):
        auth_header = self.headers.get("Authorization")
        if auth_header is None or not auth_header.startswith("Basic "):
            self.do_AUTHHEAD()
            self.wfile.write(b"<html><body><h1>401 Unauthorized</h1></body></html>")
            return
        
        auth_token = auth_header.split(" ", 1)[1]
        if auth_token != VALID_AUTH:
            self.do_AUTHHEAD()
            self.wfile.write(b"<html><body><h1>401 Unauthorized</h1></body></html>")
            return
        
        super().do_GET()

    def log_message(self, format, *args):
        pass  # Отключаем логи для экономии ресурсов

if __name__ == "__main__":
    os.chdir(WEB_DIR)
    with socketserver.TCPServer(("0.0.0.0", PORT), AuthHandler) as httpd:
        print(f"3x-ui web panel running on port {PORT}")
        httpd.serve_forever()
