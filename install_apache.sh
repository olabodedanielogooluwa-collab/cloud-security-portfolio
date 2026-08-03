#!/bin/bash
echo "Installing Apache web server..."
sudo apt-get update -y
sudo apt-get install apache2 -y
sudo service apache2 start
echo "apache installed and running."

