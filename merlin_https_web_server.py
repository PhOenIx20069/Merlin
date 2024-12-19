import http.server
import ssl
import socket

PORT = 4443
CERTFILE = "https_cert.pem"
KEYFILE = "https_key.pem"

def get_local_ip():
    """
    Run a UDP socket to get the local IP address
    If it fails, return localhost
    """
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        local_ip = s.getsockname()[0]  
        s.close()
        return local_ip
    except Exception as e:
        print(f"Cannot find ip address : {e}")
        return "localhost"  
 
LOCALHOST = get_local_ip()

# HTTP Server
server_address = ('', PORT)  
httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)

# SSL context
context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
context.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)

# Wrap the server socket with the SSL context
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(f"HTTPS server started on https://{LOCALHOST}:{PORT}")
httpd.serve_forever()
