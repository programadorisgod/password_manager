#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (use sudo)"
  exit
fi

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/password_manager

# Copy application files
echo "Copying application files..."
cp -r password_manager data lib /opt/password_manager/

# Set correct permissions
echo "Setting permissions..."
chmod +x /opt/password_manager/password_manager
chown -R $SUDO_USER:$SUDO_USER /opt/password_manager

# Create desktop entry
echo "Creating desktop entry..."
cat > /usr/share/applications/password-manager.desktop << EOL
[Desktop Entry]
Name=Password Manager
Comment=Secure Password Manager
Exec=/opt/password_manager/password_manager
Terminal=false
Type=Application
Categories=Utility;
EOL

chmod 644 /usr/share/applications/password-manager.desktop

# Create data directory for the current user
echo "Creating data directory..."
mkdir -p /home/$SUDO_USER/.local/share/password_manager
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.local/share/password_manager

echo "Installation complete! You can now run Password Manager from your applications menu." 