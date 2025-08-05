#!/bin/bash

# This script is a recreation of the functionality in bypass-mdm.sh from https://github.com/assafdori/bypass-mdm.
# It attempts to bypass MDM enrollment on macOS in Recovery Mode.
# WARNING: Use at your own risk. This modifies system files and could cause issues.
# Run only in macOS Recovery Mode.
# Backup your data first.
# This is for educational purposes; ensure you have legal permission to bypass MDM.

# Function to check if running in Recovery Mode
is_recovery() {
    if [ "$(sw_vers -productName 2>/dev/null)" != "macOS" ] || [ -d "/System/Installation" ]; then
        return 0
    else
        echo "This script must be run in Recovery Mode."
        exit 1
    fi
}

# Mount the system volume
mount_volume() {
    echo "Mounting Macintosh HD..."
    diskutil mount "Macintosh HD" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to mount Macintosh HD."
        exit 1
    fi
}

# Rename Data volume if needed
rename_data_volume() {
    if [ -d "/Volumes/Macintosh HD - Data" ]; then
        echo "Renaming 'Macintosh HD - Data' to 'Data'..."
        mv "/Volumes/Macintosh HD - Data" "/Volumes/Data"
    fi
}

# Create temporary admin user
create_temp_user() {
    local user="Apple"
    local pass="1234"
    local home="/Users/$user"

    echo "Creating temporary admin user: $user with password: $pass"

    # Mount Data volume if needed
    diskutil mount "Data" >/dev/null 2>&1

    local data_path="/Volumes/Data"

    # Create user directory
    mkdir -p "$data_path$home"

    # Use dscl to create user
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user UserShell /bin/zsh
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user RealName "$user"
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user UniqueID 501
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user PrimaryGroupID 20
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -create /Local/Default/Users/$user NFSHomeDirectory $home
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -passwd /Local/Default/Users/$user $pass

    # Add to admin group
    dscl -f "$data_path/var/db/dslocal/nodes/Default" localonly -append /Local/Default/Groups/admin GroupMembership $user
}

# Block MDM domains in /etc/hosts
block_mdm_domains() {
    local hosts_file="/Volumes/Macintosh HD/etc/hosts"
    echo "Blocking MDM domains..."

    cat <<EOL >> "$hosts_file"
127.0.0.1 deviceenrollment.apple.com
127.0.0.1 mdmenrollment.apple.com
127.0.0.1 iprofiles.apple.com
EOL
}

# Remove MDM profiles and create bypass flags
remove_mdm_profiles() {
    local config_dir="/Volumes/Macintosh HD/var/db/ConfigurationProfiles"

    echo "Removing MDM configuration profiles..."

    rm -rf "$config_dir/Settings"
    touch "$config_dir/.profilesAreInstalled"
    touch "$config_dir/Setup/.AppleSetupDone"
    touch "$config_dir/Setup/.setupDone"

    # Additional flags to bypass
    mkdir -p "$config_dir/Store"
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>last-gk-scan-date</key><date>2025-08-05T00:00:00Z</date></dict></plist>" > "$config_dir/Store/gk.plist"
}

# Main function
main() {
    is_recovery
    mount_volume
    rename_data_volume
    create_temp_user
    block_mdm_domains
    remove_mdm_profiles

    echo "MDM bypass complete. Reboot your Mac."
    echo "After reboot, log in as the temporary user 'Apple' with password '1234'."
    echo "Then, create a new admin account and delete the temporary one."
}

main
