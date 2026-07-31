#!/bin/bash
echo "Installing Apache web server..."
sudo apt-get update -y
sudo apt-get install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2
echo "Apache installed and running."
sudo systemctl status apache2 --no-pager
