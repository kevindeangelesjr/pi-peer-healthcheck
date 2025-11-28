#!/bin/bash

### Author: Kevin DeAngeles (kdeangeles@protonmail.com)
### Date: 11/28/2025
### Script Version: 1.0.0
### Description: Deploy script for pi-peer-healthcheck

### Variables
config_file="../pi-peer-healthcheck.conf"
config_deploy_dir="/etc/pi-peer-healthcheck"
config_file_deploy_path="$config_dir/pi-peer-healthcheck.conf"
service_file="../deploy/pi-peer-healthcheck.service"
service_file_deploy_path="/etc/systemd/system/pi-peer-healthcheck.service"
daemon_name="pi-peer-healthcheck.service"
logrotate_file="../logrotate/pi-peer-healthcheck.logrotate"
logrotate_deploy_path="/etc/logrotate.d/pi-peer-healthcheck"

### Functions ###
function print_usage() {
    echo "Usage: deploy.sh [-p peers] [-i interval] [-e email] [-l logfile] [-t timeout] [-s smtpserver]"
    echo "  -p peers        Comma-separated list of peer IP addresses or hostnames to monitor"
    echo "  -i interval     Healthcheck interval in seconds"
    echo "  -e email        Email address for notifications"
    echo "  -l logfile      Path to the log file"
    echo "  -t timeout      Timeout in seconds for each healthcheck"
    echo "  -s smtpserver   SMTP server address for sending emails"
} 

function main(){

    # Don't run as root
    if [ "$EUID" -eq 0 ]; then
        echo "Please do not run as root. Exiting."
        exit 1
    fi

    # Get command line arguments
    while getopts "p:i:e:l:t:s:h" opt; do
    case ${opt} in
        p )
            peers="$OPTARG"
            ;;
        i )
            interval="$OPTARG"
            ;;
        e )
            email="$OPTARG"
            ;;
        l )
            logfile="$OPTARG"
            ;;
        t )
            timeout="$OPTARG"
            ;;
        s )
            smtpserver="$OPTARG"
            ;;
        h )
            print_usage
            exit 0
            ;;
        \? )
            print_usage
            exit 1
            ;;
    esac
    done

    # Ensure all required arguments are provided
    if [ -z "$peers" ] || [ -z "$interval" ] || [ -z "$email" ] || [ -z "$logfile" ] || [ -z "$timeout" ] || [ -z "$smtpserver" ]; then
        echo "Error: Missing required arguments."
        print_usage
        exit 1
    fi

    # Modify config file with given command line arguments
    # Make sure peers are space separated not comma separated
    peers=$(echo "$peers" | tr ',' ' ')
    sed -i "s|^peers = .*|peers = $peers|" "$config_file"
    sed -i "s|^interval = .*|interval = $interval|" "$config_file"
    sed -i "s|^email = .*|email = $email|" "$config_file"
    sed -i "s|^logfile = .*|logfile = $logfile|" "$config_file"
    sed -i "s|^timeout = .*|timeout = $timeout|" "$config_file"
    sed -i "s|^smtpserver = .*|smtpserver = $smtpserver|" "$config_file"

    # Copy config file to /etc/pi-peer-healthcheck/pi-peer-healthcheck.conf
    sudo mkdir -p "$config_deploy_dir"
    sudo cp "$config_file" "$config_file_deploy_path"
    if [ $? -ne 0 ]; then
        echo "Failed to copy config file to $config_file_deploy_path"
        exit 1
    fi

    # Copy service file to /etc/systemd/system/pi-peer-healthcheck.service
    sudo cp "$service_file" "$service_file_deploy_path"
    if [ $? -ne 0 ]; then
        echo "Failed to copy service file to \$service_file_deploy_path"
        exit 1
    fi

    # Start and enable the service
    sudo systemctl daemon-reload
    sudo systemctl start ${daemon_name}
    if [ $? -ne 0 ]; then
        echo "Failed to start ${daemon_name}"
        exit 1
    fi
    sudo systemctl enable ${daemon_name}
    if [ $? -ne 0 ]; then
        echo "Failed to enable ${daemon_name}"
        exit 1
    fi

    # Ensure logrotate is installed
    if ! command -v logrotate &> /dev/null; then
        echo "logrotate could not be found, logrotate config NOT copied."
    fi

    # Copy logrotate configuration
    sudo cp "$logrotate_file" "$logrotate_deploy_path"
    if [ $? -ne 0 ]; then
        echo "Failed to copy logrotate configuration to $logrotate_deploy_path"
        exit 1
    fi
}

### Main ###
# Run main deployment function
main "${@}" 