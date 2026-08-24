#!/bin/bash
# update_system.sh
# Updates and upgrades system packages.

echo "Updating package index..."
sudo apt-get update

echo "Upgrading installed packages..."
sudo apt-get upgrade -y

echo "System update complete."
