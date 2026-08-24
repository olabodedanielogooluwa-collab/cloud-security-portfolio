#!/bin/bash
# install_apache.sh
# Installs Apache and starts it, then verifies it's actually serving
# requests rather than trusting the install command's own success message.
#
# Note: uses `service` instead of `systemctl` — this was written for
# Google Cloud Shell, where containers don't run systemd.

echo "Installing Apache..."
sudo apt-get update
sudo apt-get install -y apache2

echo "Starting Apache..."
sudo service apache2 start

echo "Verifying Apache is actually serving requests..."
if curl -s http://localhost | grep -qi "apache"; then
  echo "Apache is up and serving requests."
else
  echo "Apache does not appear to be responding. Check 'sudo service apache2 status'."
  exit 1
fi
