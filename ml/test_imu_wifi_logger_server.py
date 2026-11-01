import csv
import importlib.util
import json
import tempfile
import threading
import unittest
from http.server import HTTPServer
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

spec = importlib.util.spec_from_file_location('logger', Path(__file__).with_name('imu_wifi_logger_server.py'))
logger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(logger)

class SessionTest(unittest.TestCase):
    def test_rotation_preserves_rows_and_updates_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / 'Charlotte.csv'
            output = original.open('w', newline='', encoding='utf-8')
            writer = csv.writer(output)
            writer.writerow(logger.CSV_HEADER)
            output.flush()
            handler = logger.make_handler(writer, output, 'Charlotte', 'small')
            server = HTTPServer(('127.0.0.1', 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base = f'http://127.0.0.1:{server.server_port}'
            def request(path, data=None):
                body = None if data is None else json.dumps(data).encode()
                with urlopen(Request(base + path, data=body), timeout=3) as response:
                    payload = response.read()
                    return json.loads(payload) if payload else None
            sample = dict(millis_ms=50, accel_x=1, accel_y=2, accel_z=3, gyro_x=0, gyro_y=0, gyro_z=0)
            try:
                request('/label/sitting')
                request('/resume', {})
                request('/imu', [sample])
                before = original.read_bytes()
                first = request('/new-session', dict(dog_name='Bochi', size_class='small'))['csv_name']
                status = request('/status')
                self.assertEqual((status['dog_name'], status['rows'], status['paused'], status['label']), ('Bochi', 0, True, 'unlabeled'))
                self.assertEqual(original.read_bytes(), before)
                request('/imu', [sample])
                self.assertEqual(request('/status')['rows'], 0)
                request('/label/walking')
                request('/resume', {})
                request('/imu', [sample])
                with (Path(tmp) / first).open(newline='') as handle:
                    rows = list(csv.DictReader(handle))
                self.assertEqual((rows[0]['dog_name'], rows[0]['label']), ('Bochi', 'walking'))
                second = request('/new-session', dict(dog_name='Bochi', size_class='small'))['csv_name']
                self.assertNotEqual(first, second)
                for invalid in [dict(dog_name='', size_class='small'), dict(dog_name='Bochi', size_class='tiny')]:
                    with self.assertRaises(HTTPError) as error:
                        request('/new-session', invalid)
                    self.assertEqual(error.exception.code, 400)
                self.assertEqual(request('/status')['csv_name'], second)
                safe = request('/new-session', dict(dog_name='../../Bochi', size_class='small'))['csv_name']
                self.assertEqual(Path(safe).name, safe)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
                # Close the current session via the handler's shared closure.
                for cell in handler.do_POST.__closure__:
                    obj = cell.cell_contents
                    if hasattr(obj, 'close') and hasattr(obj, 'write'):
                        obj.close()

if __name__ == '__main__':
    unittest.main()
