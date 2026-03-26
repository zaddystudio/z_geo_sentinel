📡 Z-Geo Status (v1.0)
The Ultimate Tactical GPS Command Center

Cooked by: Zaddy Digital Solutions (https://wa.me/+2347060633216)

📋 Mission Brief
Z-Geo Status is a ruggedized, field-ready mobile dashboard designed for real-time location tracking, site reporting, and navigational awareness. Unlike standard map apps, Z-Geo Status prioritizes raw data density, offering a "Bento Grid" layout that puts Map, Speed, Weather, and Sensor data in a single, glanceable interface. 

Built for field commanders, logistics officers, and site inspectors who need to generate Proof-of-Presence reports instantly.

🛠️ Key Tactical Features
1. 🖥️ The "Bento" Command Grid
The UI is locked into a high-contrast, dark-mode grid for maximum readability in low-light and bright-sun conditions:

Live Tactical Map (Primary Tile): Full integration with OpenStreetMap. Features a "Tactical User-Agent" to prevent server blocking and an auto-centering pilot that keeps the user locked in the crosshairs.

Digital Speedometer: High-visibility KM/H readout for vehicle monitoring.

Environment Monitor: Real-time Weather status (Current Temp + 1-Hour Forecast).

HUD Mode: A "Mirror Flip" button that reverses the entire screen, allowing the phone to be placed on a dashboard to project a Heads-Up Display onto the windshield.

2. 🔦 Hardware Integration
Tactical Torch: A dedicated, high-response button in the primary grid to toggle the rear flashlight instantly.

Z-Snap (Proof of Presence): A specialized Screenshot Engine. Tapping "SNAP" triggers a heavy Tactical Vibration, captures the entire dashboard (including coordinates and timestamp), and saves it directly to the Gallery. Replaces the standard camera to prevent hardware conflicts.

3. 🛰️ The "Smart Pulse" GPS Engine
Warm-Start Protocol: The app eliminates the "Cold Start" delay. It instantly loads the [LAST ACQ.] position from internal memory, allowing the user to see their last known site immediately while the satellites warm up in the background.

Master Pulse Sync: Once a satellite lock is achieved (Accuracy < 10m), the app "snaps" to live data, updating the Map, Address, and Coordinates simultaneously to prevent data drift.

Live Data Stream: A "Matrix-style" footer that remains permanently visible:

📡 LOCKED (±5m) | LAT: 6.5244 | LNG: 3.3792 | ADDR: 23, Ireti Owoseni...

4. 🧠 Strategic Memory (Last-Action-Wins)
The app features intelligent storage for Key Locations (Home & Office):

Auto-Save: Long-press the Home/Office strip to instantly lock your current GPS position as the base.

Manual Override: Use the Menu to type a landmark (e.g., "Mushin Market"). The app geocodes the name and updates the coordinates.

Logic: The system strictly follows "Last-Action-Wins." Whether you type it or pin it, the latest action overwrites the memory.

Nuke Option: A "Clear All Memory" function to wipe all saved data and logs for a fresh start.

5. 📝 Commander's Report (Share)
Generates a professional text-based status report for WhatsApp or Email, formatted with the Zaddy Digital Solutions signature. Format:

Plaintext

Z GEO STATUS REPORT
-------------------
📍 ADDR: Afenifere Sawmill, Lagos, Lagos
📍 LOC: 6.51410, 3.33352
⛰️ ELEV: 32m
🚀 SPEED: 3 km/h
🧭 HEAD: S (167°)
📅 TIME: 2026-01-23 10:43:14
🔗 MAP: http://googleusercontent.com/maps.google.com/...
Proudly Cooked by: Zaddy Digital Solutions
⚙️ Technical Stack
Framework: Flutter (Dart)

Mapping: flutter_map + latlong2 (OpenStreetMap Tile Server)

Sensors: geolocator, flutter_compass, battery_plus

Hardware Control: torch_light, screenshot, gal (Gallery Saving)

Storage: shared_preferences (Persistent State)

Geocoding: geocoding (Reverse lookup for Streets/Landmarks)

🚀 Installation & Usage
Install: Deploy the APK from the /release folder.

Permissions: Grant Location (Always/While in Use) and Storage permissions on first launch.

Operation:

Wait: Allow 10-20 seconds for the footer to turn Green (📡 LOCKED).

Torch: Tap the Flashlight icon for visibility.

Snap: Tap "SNAP" in the instrument row to save a report.

Share: Use the 3-Dot Menu -> "Tactical Share" to broadcast your status.

🔒 License & Credits
Copyright © 2026 Zaddy Digital Solutions. All rights reserved. This software is a proprietary internal tool for site management and logistics tracking.

Contact: WhatsApp(https://wa.me/+2347060633216) | Email: hi@zaddyhost.top
