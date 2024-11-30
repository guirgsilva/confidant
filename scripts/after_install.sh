#!/bin/bash
cd /opt/confidant

# Check if the requirements.txt file exists
if [ ! -f requirements.txt ]; then
    echo "requirements.txt not found. Creating basic requirements..."
    echo "flask" > requirements.txt
fi

# Installs the dependencies
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# Checks installation status
if [ $? -eq 0 ]; then
    echo "Dependencies installed successfully"
    exit 0
else
    echo "Failed to install dependencies"
    exit 1
fi