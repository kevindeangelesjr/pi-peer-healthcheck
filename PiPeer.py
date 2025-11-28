#!/usr/bin/env python3

### Author: Kevin DeAngeles
### Date: 11/28/2025
### Python Version: 3.14.0
### Description: Defines the PiPeer class for managing Raspberry Pi peer healthchecks

### Imports ###
import socket
import subprocess

### Classes ###
class PiPeer:
    """
    Class representing a Raspberry Pi peer in the network.
    """

    def __init__(self, hostname):
        self.hostname = hostname
        self.status = "unknown"

        self.ip_address = self.resolve_ip()
        if self.ip_address is None:
            raise ValueError(f"Could not resolve hostname for peer: {hostname}")
    
    def resolve_ip(self):
        """
        Resolve the IP address of the peer from its hostname.
        """
        try:
            return socket.gethostbyname(self.hostname)
            self.status = "healthy"
        except Exception:
            return None
    
    def peer_ping(self, timeout=5):
        """
        Perform a ping to the peer to check its health.
        """
        try:
            ping_command = f"ping -c 4 -W {timeout} {self.ip_address}"
            ping_result = subprocess.run(ping_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if ping_result.returncode != 0:
                self.status = "unhealthy"
                return False
            self.status = "healthy"
            return True
        except Exception:
            self.status = "unhealthy"
            return False
    
    def test_dns(self, timeout=5):
        """
        Test that the peer is responding to DNS queries.
        """
        try:
            dns_command = f"timeout {timeout} nslookup {self.hostname} {self.ip_address}"
            dns_result = subprocess.run(dns_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if dns_result.returncode != 0:
                self.status = "unhealthy"
                return False
            self.status = "healthy"
            return True
        except Exception:
            self.status = "unhealthy"
            return False