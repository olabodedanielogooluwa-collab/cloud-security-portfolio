#!/bin/bash
read -p "Enter new username: " username
sudo useradd -m -s /bin/bash "$username"
sudo passwd "$username"
echo "User $username created successfully."
id "$username"
