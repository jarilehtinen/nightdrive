"""Ferry's notification payload and who gets a notification. Run from plugins/ferry:

    python3 -m unittest tests/test_push.py

(On a machine without python3-cryptography: uv run --with cryptography python3 -m unittest tests/test_push.py.)
"""
import importlib.machinery
import json
import os
import unittest

ferry = importlib.machinery.SourceFileLoader(
    "ferry", os.path.join(os.path.dirname(__file__), "..", "bin", "ferry")).load_module()


def sub(device, direct=False, endpoint=None):
    s = {"endpoint": endpoint or f"https://push.example/{device}-{direct}", "keys": {"p256dh": "k", "auth": "a"},
         "device": device, "time": 0}
    if direct:
        s["direct"] = True
    return s


class Payload(unittest.TestCase):
    def test_keeps_short_text(self):
        p = ferry.payload("Nightdrive", "801566", item={"id": "a1", "kind": "text", "text": "801566"})
        self.assertEqual(json.loads(p), {"title": "Nightdrive", "body": "801566", "machine": "", "id": "a1",
                                         "kind": "text", "text": "801566"})

    def test_drops_text_that_does_not_fit(self):
        text = "ä" * 1500   # 3000 bytes
        p = ferry.payload("Nightdrive", text[:180], item={"id": "a1", "kind": "text", "text": text})
        self.assertLessEqual(len(p), ferry.PUSH_PAYLOAD)
        d = json.loads(p)
        self.assertNotIn("text", d)
        self.assertEqual(d["body"], "ä" * 180)
        self.assertEqual(d["kind"], "text")

    def test_never_cuts_utf8(self):   # Review Focus 2
        text = "😀" * 900   # 3600 bytes
        p = ferry.payload("😀" * 300, "😀" * 300, item={"id": "a1", "kind": "text", "text": text})
        self.assertLessEqual(len(p), ferry.PUSH_PAYLOAD)
        d = json.loads(p.decode("utf-8"))   # valid UTF-8 and valid JSON
        self.assertNotIn("text", d)

    def test_text_that_just_fits_is_kept_whole(self):
        base = len(ferry.payload("N", "x", item={"id": "a1", "kind": "text", "text": ""}))
        text = "x" * (ferry.PUSH_PAYLOAD - base)
        d = json.loads(ferry.payload("N", "x", item={"id": "a1", "kind": "text", "text": text}))
        self.assertEqual(d["text"], text)

    def test_for_files(self):
        d = json.loads(ferry.payload("N", "x.pdf", item={"id": "f1", "kind": "file", "name": "x.pdf"}))
        self.assertEqual((d["id"], d["kind"]), ("f1", "file"))
        self.assertNotIn("text", d)

    def test_ends_with_a_huge_machine(self):   # api/relay-push takes machine from the request
        p = ferry.payload("N", "x", "https://m/" + "a" * 2700)
        self.assertLessEqual(len(p), ferry.PUSH_PAYLOAD)
        json.loads(p)

    def test_without_item(self):   # api/test-push, api/relay-push
        self.assertEqual(json.loads(ferry.payload("N", "Notifications work", "https://m/ferry/")),
                         {"title": "N", "body": "Notifications work", "machine": "https://m/ferry/"})


class Targets(unittest.TestCase):
    def test_relayed_skips_direct_and_the_same_phones_pwa(self):   # Review Focus 3
        pwa, app = sub("iphone"), sub("iphone", direct=True)
        self.assertEqual(ferry.targets([pwa, app], relayed=True), [])
        self.assertEqual(ferry.targets([pwa, app], relayed=False), [app])

    def test_other_devices_pwa_kept(self):
        pwa, app = sub("ipad"), sub("iphone", direct=True)
        self.assertEqual(ferry.targets([pwa, app], relayed=False), [pwa, app])
        self.assertEqual(ferry.targets([pwa, app], relayed=True), [pwa])

    def test_fallback_device_not_replaced(self):   # "your phone" could be anyone's
        pwa, app = sub("your phone"), sub("your phone", direct=True)
        self.assertEqual(ferry.targets([pwa, app], relayed=False), [pwa, app])

    def test_pwa_alone_unchanged(self):
        pwa = sub("iphone")
        self.assertEqual(ferry.targets([pwa], relayed=False), [pwa])
        self.assertEqual(ferry.targets([pwa], relayed=True), [pwa])


class Subscription(unittest.TestCase):
    def test_stores_direct(self):
        e = ferry.subscription({"endpoint": "https://ferry.feature.fi/push/x", "keys": {"p256dh": "k", "auth": "a"},
                                "direct": True}, "iphone")
        self.assertTrue(e["direct"])
        self.assertEqual(e["device"], "iphone")

    def test_without_direct(self):
        e = ferry.subscription({"endpoint": "https://web.push.apple.com/x", "keys": {"p256dh": "k", "auth": "a"}}, "iphone")
        self.assertNotIn("direct", e)

    def test_rejects_non_subscriptions(self):
        self.assertIsNone(ferry.subscription({"endpoint": "http://x/", "keys": {"p256dh": "k", "auth": "a"}}, "d"))
        self.assertIsNone(ferry.subscription({"endpoint": "https://x/", "keys": {"p256dh": "k"}}, "d"))
        self.assertIsNone(ferry.subscription([], "d"))


if __name__ == "__main__":
    unittest.main()
