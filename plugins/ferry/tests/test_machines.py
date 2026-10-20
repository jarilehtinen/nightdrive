"""Which of the owner's other machines api/machines lists. Run from plugins/ferry:

    python3 -m unittest tests/test_machines.py
"""
import importlib.machinery
import os
import unittest

ferry = importlib.machinery.SourceFileLoader(
    "ferry", os.path.join(os.path.dirname(__file__), "..", "bin", "ferry")).load_module()


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


class Found(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.running = {"pc": True, "mini": True}   # whether Ferry answers there
        self.asked = []

        def probe(host):
            self.asked.append(host)
            return {"url": f"https://{host}/ferry/", "name": host.upper()} if self.running.get(host) else None
        self.found = ferry.Found(probe=probe, clock=self.clock)

    def names(self, online):
        return [m["name"] for m in self.found.get(online)]

    def test_a_machine_that_comes_online_is_listed_at_once(self):   # a phone sees a computer wake within seconds
        self.assertEqual(self.names(["mini"]), ["MINI"])
        self.clock.now += 5
        self.assertEqual(self.names(["mini", "pc"]), ["MINI", "PC"])

    def test_a_machine_that_goes_offline_leaves_at_once(self):
        self.names(["mini", "pc"])
        self.clock.now += 5
        self.assertEqual(self.names(["mini"]), ["MINI"])

    def test_one_found_is_asked_again_only_after_a_minute(self):
        self.names(["pc"])
        self.clock.now += 30
        self.names(["pc"])
        self.assertEqual(self.asked, ["pc"])
        self.clock.now += 31
        self.names(["pc"])
        self.assertEqual(self.asked, ["pc", "pc"])

    def test_one_without_ferry_is_asked_again_after_10_seconds(self):   # online before its Ferry started
        self.running["pc"] = False
        self.assertEqual(self.names(["pc"]), [])
        self.clock.now += 5
        self.names(["pc"])
        self.assertEqual(self.asked, ["pc"])
        self.running["pc"] = True
        self.clock.now += 6
        self.assertEqual(self.names(["pc"]), ["PC"])

    def test_asked_says_whether_this_call_asked_anyone(self):   # known_machines is written only then
        self.names(["pc"])
        self.assertEqual(self.found.asked, ["pc"])
        self.clock.now += 5
        self.names(["pc"])
        self.assertEqual(self.found.asked, [])

    def test_one_that_was_offline_is_asked_when_it_returns(self):
        self.names(["pc"])
        self.clock.now += 5
        self.names([])
        self.clock.now += 5
        self.names(["pc"])
        self.assertEqual(self.asked, ["pc", "pc"])


if __name__ == "__main__":
    unittest.main()
