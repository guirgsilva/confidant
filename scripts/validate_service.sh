#!/bin/bash
sleep 5
if curl -s http://localhost:5000/health > /dev/null; then
    echo "Application is running"
    exit 0
else
    echo "Application is not running"
    exit 1
fi