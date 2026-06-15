#!/bin/bash
# Check devices connected
adb devices

# Ensure logs directory exists
mkdir -p appium-framework/logs

# Start Appium server in background
appium --port 4723 --log-no-colors-theme > appium-framework/logs/appium-server.log 2>&1 &

# Wait for Appium to start listening on port 4723
echo "Waiting for Appium server to start..."
until curl -s http://127.0.0.1:4723/status > /dev/null; do
  sleep 2
done
echo "Appium server is up!"

# Execute tests
cd appium-framework
npm run test
