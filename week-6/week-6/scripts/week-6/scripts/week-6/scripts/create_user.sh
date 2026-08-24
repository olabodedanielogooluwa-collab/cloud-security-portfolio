#!/bin/bash
# create_user.sh
# Prompts for a username, creates the account with a home directory
# and bash shell, sets a password, and confirms creation.

read -p "Enter new username: " username

sudo useradd -m -s /bin/bash "$username"

if [ $? -eq 0 ]; then
  echo "User account created. Set a password:"
  sudo passwd "$username"
  echo "Confirming account details:"
  id "$username"
else
  echo "Failed to create user $username."
  exit 1
fi
