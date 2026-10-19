// Ferry's service worker: the page opens from its cache when the computer can't be reached (asleep, Tailscale off), so
// the page can say so instead of Safari's error, and it shows the Web Push notifications (bin/ferry push_all).
const CACHE = "ferry-25"
const SHELL = ["./", "manifest.webmanifest", "icon-180.png", "icon-192.png", "icon.svg"]
const WAIT = 4000   // ms the network gets before the cached page is shown

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()))
})
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
                .then(() => self.clients.claim()))
})

// The page and its icons: the network first (a new version shows at once), the cache when it doesn't answer in time.
// The API is never cached: its answers are the box's state.
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url)
  const scope = new URL(self.registration.scope)
  if (e.request.method !== "GET" || url.origin !== scope.origin || url.pathname.startsWith(scope.pathname + "api/")) return
  const key = e.request.mode === "navigate" ? "./" : e.request
  e.respondWith((async () => {
    const net = fetch(e.request).then(r => {
      if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(key, copy)) }
      return r
    })
    const late = new Promise(resolve => setTimeout(resolve, WAIT))
    const first = await Promise.race([net.catch(() => null), late])
    if (first) return first
    return (await caches.match(key)) || net
  })())
})

self.addEventListener("push", e => {
  let d = {}
  try { d = e.data.json() } catch (err) { d = { title: "Ferry", body: e.data ? e.data.text() : "" } }
  // iOS ends a subscription whose push doesn't show a notification: always show one
  e.waitUntil(Promise.all([
    self.registration.showNotification(d.title || "Ferry", { body: d.body || "", icon: "icon-192.png", tag: "ferry",
                                                             renotify: true }),
    self.clients.matchAll({ type: "window" }).then(list => list.forEach(c => c.postMessage("refresh"))),
  ]))
})

// A tap opens the page (it shows every computer, so it doesn't matter which one the notification is about)
self.addEventListener("notificationclick", e => {
  e.notification.close()
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(list => {
    for (const c of list) if ("focus" in c) { c.postMessage("refresh"); return c.focus() }
    return self.clients.openWindow(self.registration.scope)
  }))
})
