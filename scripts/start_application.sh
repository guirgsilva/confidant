#!/bin/bash
cd /opt/confidant

# Kill any existing application process
pkill -f “python3 app.py” || true

# Ensure that the directory has the correct permissions
chown -R ec2-user:ec2-user /opt/confidant

# Start the application with correct permissions
python3 -m flask run --host=0.0.0.0 --port=80 > /opt/confidant/flask.log 2>&1 &

# Wait a few seconds for the application to start
sleep 5

# Check if the process is running
ps aux | grep “python3” | grep “flask”