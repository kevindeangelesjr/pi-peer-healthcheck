#!/usr/env bash
 
# Deploy script for pi-peer-healthcheck

# Get command line arguments
while getopts "s" opt; do
  case ${opt} in
    s )
      echo "Starting deployment..."
      ;;
    \? )
      echo "Usage: deploy.sh [-s]"
      exit 1
      ;;
  esac
done

# 