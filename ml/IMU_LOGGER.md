# IMU Wi-Fi collection sessions

Run `python ml/imu_wifi_logger_server.py --dog Bochi --size small` from the repository root.
Open http://127.0.0.1:8765/ on the desktop.

To switch dogs or start another file, enter the dog name, choose its size,
and click **New CSV**. The active dog and CSV filename appear above the form.
Each new CSV gets a unique filename in the current output directory; previous
files are closed and preserved. New sessions start paused with activity
`unlabeled` and counters reset. Select the observed activity, then resume.
A repeated dog name creates a separate file. Filenames sanitize the dog name;
CSV rows retain the entered name.

CSV columns and the ESP32 destination remain unchanged. This only changes the
local collection session; it does not create a dog in Supabase.

Run `python -m unittest discover -s ml -p test_imu_wifi_logger_server.py` to check
file preservation, dog identity, paused samples, unique filenames and invalid input.
