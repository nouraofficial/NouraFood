const CACHE = 'noura-vendor-shell-v4';
const ASSETS = [
  '/vendor',
  '/vendor.html',
  '/manifest-vendor.json',
  '/icon-192.png',
  '/icon-192-maskable.png',
  '/icon-512.png',
  '/favicon.png',
  '/apple-touch-icon.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k.startsWith('noura-vendor-') && k !== CACHE)
          .map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;

  // Vendor data/auth/API responses must stay live. Do not cache them.
  if (
    url.pathname.startsWith('/store/') ||
    url.pathname.startsWith('/rest/') ||
    url.pathname.startsWith('/api/')
  ) return;

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(() => caches.match('/vendor.html'))
    );
    return;
  }

  const isStatic = /\.(?:css|js|png|jpg|jpeg|webp|svg|ico|woff2?)$/i.test(url.pathname) ||
                   url.pathname.endsWith('/manifest-vendor.json');
  if (!isStatic) return;

  event.respondWith(
    caches.match(req).then(cached => {
      const network = fetch(req).then(res => {
        if (res.ok) caches.open(CACHE).then(c => c.put(req, res.clone()));
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
