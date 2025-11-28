#!/bin/bash

### Author: Kevin DeAngeles (kdeangeles@protonmail.com)
### Date: 11/28/2025
### Script Version: 1.0.0
### Description: Deploy script for pi-peer-healthcheck

### Variables
script_dir=$(dirname "$0")
config_file="../config/pi-peer-healthcheck.conf"
config_deploy_dir="/etc/pi-peer-healthcheck"
config_file_deploy_path="${config_deploy_dir}/pi-peer-healthcheck.conf"
script_file="../pi-peer-healthcheck.py"
script_deploy_path="/usr/local/bin/pi-peer-healthcheck.py"
service_file="../systemd/pphd.service"
service_file_deploy_path="/etc/systemd/system/pphd.service"
daemon_name="pphd.service"
logrotate_file="../logrotate/pi-peer-healthcheck"
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

    cd "$script_dir" || { echo "Failed to change directory to $script_dir"; exit 1; }

    # Modify config file with given command line arguments
    echo "Configuring pi-peer-healthcheck.conf with provided parameters ..."
    sed -i "s|^PEERS=.*|PEERS=$peers|" "$config_file"
    sed -i "s|^INTERVAL=.*|INTERVAL=$interval|" "$config_file"
    sed -i "s|^EMAIL=.*|EMAIL=$email|" "$config_file"
    sed -i "s|^LOGFILE=.*|LOGFILE=$logfile|" "$config_file"
    sed -i "s|^TIMEOUT=.*|TIMEOUT=$timeout|" "$config_file"
    sed -i "s|^SMTP_SERVER=.*|SMTP_SERVER=$smtpserver|" "$config_file"

    # Copy config file to /etc/pi-peer-healthcheck/pi-peer-healthcheck.conf
    echo "Deploying pi-peer-healthcheck config file ... "
    sudo mkdir -p "$config_deploy_dir"
    sudo cp "$config_file" "$config_file_deploy_path"
    if [ $? -ne 0 ]; then
        echo "Failed to copy config file to $config_file_deploy_path"
        exit 1
    fi
    echo "Config file deployed successfully to $config_file_deploy_path"

    # Copy the main script to /usr/local/bin/pi-peer-healthcheck.py
    echo "Deploying pi-peer-healthcheck script ... "
    sudo cp "$script_file" "$script_deploy_path"
    if [ $? -ne 0 ]; then
        echo "Failed to copy script file to $script_deploy_path"
        exit 1
    fi
    sudo chmod +x "$script_deploy_path"
    echo "Script file deployed successfully to $script_deploy_path"

    # Copy service file to /etc/systemd/system/pi-peer-healthcheck.service
    echo "Deploying pi-peer-healthcheck systemd service ... "
    sudo cp "${service_file}" "${service_file_deploy_path}"
    if [ $? -ne 0 ]; then
        echo "Failed to copy service file to ${service_file_deploy_path}"
        exit 1
    fi
    echo "Service file deployed successfully to $service_file_deploy_path"

    # Start and enable the service
    echo "Starting and enabling ${daemon_name} service ... "
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
    echo "Service ${daemon_name} started and enabled successfully."

    # Set logrotate logfile name
    echo "Configuring logrotate for pi-peer-healthcheck ... "
    sed -i "s|/var/log/pi-peer-healthcheck.log|$logfile|" "$logrotate_file"

    # Ensure logrotate is installed
    echo "Deploying logrotate configuration for pi-peer-healthcheck ... "
    if ! command -v logrotate &> /dev/null; then
        echo "logrotate could not be found, logrotate config NOT copied."
    else
        # Copy logrotate configuration
        sudo cp "$logrotate_file" "$logrotate_deploy_path"
        if [ $? -ne 0 ]; then
            echo "Failed to copy logrotate configuration to $logrotate_deploy_path"
        fi
        echo "Logrotate configuration deployed successfully to $logrotate_deploy_path"
    fi
}

### Main ###
# Run main deployment function
main "${@}" 