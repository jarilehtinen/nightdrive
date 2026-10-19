"""Ferry's devices, the picked target and what each phone's page lists. Run from plugins/ferry:

    python3 -m unittest tests/test_devices.py
"""
import importlib.machinery
import json
import os
import tempfile
import unittest

ferry = importlib.machinery.SourceFileLoader(
    "ferry", os.path.join(os.path.dirname(__file__), "..", "bin", "ferry")).load_module()


def peer(name, os_, online=True, uid=1):
    return {"DNSName": f"{name}.tail0.ts.net.", "OS": os_, "Online": online, "UserID": uid, "HostName": name}


STATUS = {"Self": {"UserID": 1, "DNSName": "nightdrive.tail0.ts.net."},
          "Peer": {"a": peer("nightdrive-pc", "linux"), "b": peer("studio", "linux", online=False),
                   "c": peer("iphone", "iOS"), "d": peer("ipad", "iOS", online=False),
                   "e": peer("server", "linux"), "f": peer("someone-elses", "iOS", uid=2)}}


class Devices(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state, ferry.STATE = ferry.STATE, self.tmp.name
        with open(os.path.join(self.tmp.name, "machines.json"), "w") as f:
            json.dump([{"id": "nightdrive-pc", "name": "Nightdrive PC", "url": "https://pc/ferry/", "idle": 0},
                       {"id": "studio", "name": "Studio", "url": "https://studio/ferry/", "idle": 900},
                       {"id": "gone", "name": "Gone", "url": "https://gone/ferry/"}], f)

    def tearDown(self):
        ferry.STATE = self.state
        self.tmp.cleanup()

    def test_lists_ferry_computers_then_the_owners_phones(self):
        d = ferry.devices(STATUS)
        self.assertEqual([(x["id"], x["kind"], x["online"]) for x in d], [
            ("nightdrive-pc", "computer", True), ("studio", "computer", False),
            ("ipad", "tablet", False), ("iphone", "phone", True)])
        self.assertTrue(d[0]["inUse"])
        self.assertEqual(d[0]["name"], "Nightdrive PC")

    def test_target_defaults_to_a_phone_online(self):
        self.assertEqual(ferry.target(ferry.devices(STATUS))["id"], "iphone")

    def test_target_is_the_one_picked(self):
        ferry.set_target("studio")
        self.assertEqual(ferry.target(ferry.devices(STATUS))["id"], "studio")

    def test_a_picked_device_that_went_falls_back(self):
        ferry.set_target("gone")
        self.assertEqual(ferry.target(ferry.devices(STATUS))["id"], "iphone")

    def test_no_devices_no_target(self):
        self.assertIsNone(ferry.target([]))

    def test_sent_shows_for_a_few_seconds(self):
        ferry.refresh_bar = lambda: None
        ferry.mark_sent("x.pdf", "iphone")
        self.assertEqual(ferry.last_sent()["to"], "iphone")


class ForDevice(unittest.TestCase):
    def test_a_phone_sees_what_is_for_it_or_for_any(self):
        self.assertTrue(ferry.for_device({"to": "phone", "for": "iphone"}, "iphone"))
        self.assertFalse(ferry.for_device({"to": "phone", "for": "ipad"}, "iphone"))
        self.assertTrue(ferry.for_device({"to": "phone"}, "iphone"))           # sent before "for" existed
        self.assertTrue(ferry.for_device({"to": "computer", "from": "ipad"}, "iphone"))

    def test_push_only_to_that_phone(self):
        subs = [{"endpoint": "https://p/1", "device": "iphone"}, {"endpoint": "https://p/2", "device": "ipad"}]
        self.assertEqual([s["device"] for s in ferry.recipients(subs, False, "ipad")], ["ipad"])
        self.assertEqual(len(ferry.recipients(subs, False)), 2)


if __name__ == "__main__":
    unittest.main()
