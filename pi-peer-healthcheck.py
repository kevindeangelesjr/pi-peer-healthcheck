#!/usr/bin/env python3

### Author: Kevin DeAngeles
### Date: 11/28/2025
### Python Version: 3.14.0
### Script Version: 1.0.0
### Description: This script allows Raspberry Pi devices to perform healthchecks on their peers in a network.

### Imports ###
import PiPeer
import argparse
import logging
from logging.handlers import RotatingFileHandler
import smtplib
from email.mime.text import MIMEText
from email.utils import make_msgid
import socket

### Constants
SCRIPT_VERSION = "1.0.0"
SUBJECT_PREFIX = "[pi-peer-healthcheck ALERT]: "
EMAIL_FROM = f"pi-peer-healthcheck@{socket.gethostname()}.kevind.link"

### Functions ###
def get_args():
    """
    Parse command line arguments
    Return:
        dict: Dictionary of parsed arguments
    """

    parser = argparse.ArgumentParser(description="Raspberry Pi Peer Healthcheck Script")
    parser.add_argument("--peers",
                        type=str,
                        nargs='+',
                        help="List of Raspberry Pi peer hostnames to check",
                        required=True)
    parser.add_argument("--daemonize",
                        action="store_true",
                        help="Run the script as a daemon",
                        required=False)
    parser.add_argument("-timeout",
                        type=int,
                        default=5,
                        help="Timeout in seconds for peer healthchecks (default: 5)",
                        required=False)
    parser.add_argument("--version",
                        action="version",
                        version="pi-peer-healthcheck " + SCRIPT_VERSION,
                        help="Show program's version number and exit")
    parser.add_argument("-v",  
                        "--verbose",
                        action="store_true",
                        help="Enable verbose logging output",
                        required=False)
    parser.add_argument("--dnscheck",
                        action="store_true",
                        help="Enable DNS healthcheck for peers",
                        required=False)
    parser.add_argument("--email",
                        type=str,
                        help="Email address to send alerts to",
                        required=False)
    parser.add_argument("--interval",
                        type=int,
                        default=300,
                        help="Interval in seconds between healthchecks when daemonized (default: 300)",
                        required=False)
    parser.add_argument("--smtp-server",
                        type=str,
                        default="mail.protonmail.ch",
                        help="SMTP server for sending email alerts (default: mail.protonmail.ch)",
                        required=False)
    parser.add_argument("--logfile",
                        type=str,
                        default="/var/log/pi-peer-healthcheck.log",
                        help="Path to logfile",
                        required=False)

    parsedArgs = parser.parse_args()

    return {
        "peerList": parsedArgs.peers,
        "daemonize": parsedArgs.daemonize,
        "timeout": parsedArgs.timeout,
        "verbose": parsedArgs.verbose,
        "dnscheck": parsedArgs.dnscheck,
        "email": parsedArgs.email,
        "interval": parsedArgs.interval,
        "smtp_server": parsedArgs.smtp_server,
        "logfile": parsedArgs.logfile
    }

def send_email(email_address, smtp_server, subject, body):
    """
    Send email alert
    """

    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = EMAIL_FROM
    msg['To'] = email_address
    msg['Message-ID'] = make_msgid()

    try:
        with smtplib.SMTP(smtp_server) as server:
            server.sendmail(msg['From'], [msg['To']], msg.as_string())
    except Exception as e:
        raise RuntimeError(f"Failed to send email to {email_address}: {e}")
    
    return msg.as_string()

def main():
    """
    Main function
    """

    # Parse command line arguments
    argDict = get_args()

    # Initialize logger
    logging.basicConfig(level=logging.DEBUG if argDict["verbose"] else logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s',
                        handlers=[logging.FileHandler(argDict["logfile"]),
                                  logging.StreamHandler()])
    logger = logging.getLogger()

    logger.debug("Verbose logging enabled.")
    logger.debug("Parsed arguments successfully: %s", argDict)
    logger.info("Initializing pi-peer-healthcheck ... ")

    # Create PiPeer objects for each peer
    peerList = []
    for peer in argDict["peerList"]:
        try:
            newPi = PiPeer.PiPeer(peer)
            peerList.append(newPi)
            logger.debug(f"Successfully create PiPeer object for {peer} with IP {newPi.ip_address}.")
            logger.debug(f"PiPeer object details: {newPi.__dict__}")
        except Exception as e:
            logger.warning(f"Error creating PiPeer object for {peer}: {e}")
            logger.warning(f"Peer {peer} will NOT be checked!")
            if argDict["email"]:
                logger.info(f"Sending alert email for failed PiPeer initialization: {peer}")
                try:
                    msg = send_email(argDict["email"], argDict["smtp_server"],
                                        SUBJECT_PREFIX + f"Raspberry Pi Peer {peer} could not be initialized!",
                                        f"Healthcheck for peer {peer} could not be initialized due to: {e}.\n\nPlease investigate the issue.")
                    logger.info(f"Successfully sent alert email to {argDict['email']} regarding peer {peer.hostname}.")
                    logger.debug(f"Sent email content:\n {msg}")
                except Exception as e:
                    logger.error(f"Failed to send alert email for peer {peer}: {e}")
            continue
    
    # Main healthcheck loop, will exit after one iteration if not daemonized
    while True:
        logger.debug("Running healthchecks on peers ... ")
        for peer in peerList:
            logger.info(f"Running healthchecks on peer: {peer.hostname} ({peer.ip_address})")

            # Ensure IP can be resolved
            logger.debug(f"Attempting to resolve IP for peer: {peer.hostname}")
            resolved_ip = peer.resolve_ip()
            if resolved_ip is None:
                logger.error(f"Could not resolve IP for peer: {peer.hostname}")
                reason = "Hostname cannot be resolved"
            else:
                logger.debug(f"Successfully resolved IP for peer {peer.hostname}: {resolved_ip}")
            
            # Ensure peer can be pinged
            logger.debug(f"Pinging peer: {peer.hostname} at IP {peer.ip_address}")
            ping_success = peer.peer_ping(argDict["timeout"])
            if not ping_success:
                logger.error(f"Peer {peer.hostname} is NOT responding to pings!")
                reason = "Host cannot be pinged"
            else:
                logger.debug(f"Peer {peer.hostname} responded successfully to pings.")

            logger.info(f"Peer {peer.hostname} is {peer.status}.")

            # Ensure peer responds to DNS queries if enabled
            if argDict["dnscheck"]:
                logger.debug(f"Testing that peer is responding to DNS queries: {peer.hostname}")
                dns_success = peer.test_dns(argDict["timeout"])
                if not dns_success:
                    logger.error(f"Peer {peer.hostname} is NOT responding to DNS queries!")
                    reason = "Host not responding to DNS queries"
                else:
                    logger.debug(f"Peer {peer.hostname} responded successfully to DNS queries.")

            # Send email if unhealthy
            if peer.status == "unhealthy" and argDict["email"]:
                logger.info(f"Sending alert email for unhealthy peer: {peer.hostname}")
                subject = SUBJECT_PREFIX + f"Raspberry Pi Peer {peer.hostname} is UNHEALTHY!"
                body = f"Healthcheck for peer {peer.hostname} ({peer.ip_address}) failed due to: {reason}.\n\nPlease investigate the issue."
                try:
                    msg = send_email(argDict["email"], argDict["smtp_server"], subject, body)
                    logger.info(f"Successfully sent alert email to {argDict['email']} regarding peer {peer.hostname}.")
                    logger.debug(f"Sent email content:\n {msg}")
                except Exception as e:
                    logger.error(f"Failed to send alert email for peer {peer.hostname}: {e}")
                
            logger.info(f"Healthcheck completed for peer: {peer.hostname}")

        logger.info("Healthchecks completed for all peers.")
        logging.debug("Status for all peers: %s", {peer.hostname: peer.status for peer in peerList})

        if not argDict["daemonize"]:
            break
        else:
            logger.info(f"Sleeping for {argDict['interval']} seconds before next healthcheck cycle ... ")
            import time
            time.sleep(argDict["interval"])

### Main ###
if __name__ == "__main__":
    main()