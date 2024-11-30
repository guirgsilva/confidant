#!/bin/bash
cd /opt/confidant

# Kill any existing application process in a more secure way
pkill -f flask || true

# Ensure that the environment has the FLASK_APP variable set
export FLASK_APP=app.py

# Ensure that the directory has the correct permissions
chown -R ec2-user:ec2-user /opt/confidant

# Configure the log
touch /opt/confidant/flask.log
chown ec2-user:ec2-user /opt/confidant/flask.log

# Start the application
/usr/bin/python3 -m flask run --host=0.0.0.0 --port=80 > /opt/confidant/flask.log 2>&1 &

# Captures the process PID
PID=$!

# Wait a few seconds for the application to start
sleep 5

# Check if the process is still running
if ps -p $PID > /dev/null; then
    echo “Application started successfully with PID: $PID”
    exit 0
else
    echo “Application failed to start. Check logs:”
    cat /opt/confidant/flask.log
    exit 1
fi