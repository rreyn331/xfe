#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run this script with sudo: sudo ./setup-network-shares.sh"
    exit 1
fi

echo "================================================================"
echo "🚀 AUTOFS NETWORK (ANTI-FREEZE) & CD-ROM COMPLETE SETUP 🚀"
echo "================================================================"

# 1. Install required packages
echo "📦 Step 1: Checking required software (autofs, cifs-utils, smbclient)..."
apt-get update > /dev/null
apt-get install -y autofs cifs-utils smbclient > /dev/null

# 2. Get IP Addresses First
echo ""
echo "🖥️  Step 2: Server Identification"
read -p "Enter your Server IP addresses separated by a space (e.g., 192.168.0.138 192.168.0.149): " ips

# SELF-CLEANING: Erase old files before we start
rm -f /etc/creds_* /etc/creds.smb
> /etc/auto.shares 

# 3. Loop through each IP to get specific credentials and scan
echo ""
echo "🔐 Step 3: Credentials and Scanning"
for ip in $ips; do
    safe_ip=$(echo "$ip" | tr '.' '_')
    cred_file="/etc/creds_${safe_ip}"

    echo "------------------------------------------------"
    echo "👉 For Server: $ip"
    read -p "   Enter Username: " smbuser
    read -s -p "   Enter Password: " smbpass
    echo ""

    echo "username=$smbuser" > "$cred_file"
    echo "password=$smbpass" >> "$cred_file"
    chmod 600 "$cred_file"
    echo "   ✅ Saved credentials securely to $cred_file"

    echo "   🔎 Scanning $ip for folders..."
    shares=$(smbclient -gL "$ip" -U "$smbuser%$smbpass" 2>/dev/null | grep Disk | awk -F'|' '{print $2}')
    
    for share in $shares; do
        # THE FIX: Notice the ",soft" added to the options below!
        echo "${safe_ip}_${share} -fstype=cifs,credentials=${cred_file},iocharset=utf8,soft ://${ip}/${share}" >> /etc/auto.shares
        echo "      -> Found and added: ${safe_ip}_${share}"
    done
done
echo "------------------------------------------------"

# 4. Configure CD-ROM local automount
echo ""
echo "💿 Step 4: Configuring CD-ROM Automount..."
> /etc/auto.local
echo "cdrom -fstype=iso9660,udf,ro,nosuid,nodev :/dev/sr0" > /etc/auto.local
echo "✅ CD-ROM configured to mount dynamically!"

# 5. Configure auto.master
echo ""
echo "📝 Step 5: Configuring Autofs Master file..."
MOUNT_NETWORK="/media/network"
MOUNT_LOCAL="/media/local"

mkdir -p "$MOUNT_NETWORK"
mkdir -p "$MOUNT_LOCAL"

sed -i '\|'"$MOUNT_NETWORK"'|d' /etc/auto.master
sed -i '\|'"$MOUNT_LOCAL"'|d' /etc/auto.master

echo "$MOUNT_NETWORK /etc/auto.shares --timeout=60 --ghost" >> /etc/auto.master
echo "$MOUNT_LOCAL /etc/auto.local --timeout=5 --ghost" >> /etc/auto.master

# 6. Restart Autofs
echo ""
echo "🔄 Step 6: Restarting Autofs service..."
systemctl restart autofs

sleep 2

echo ""
echo "================================================================"
echo "🎉 SETUP COMPLETE! Everything is ready for Xfe."
echo "================================================================"
