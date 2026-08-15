const CACHE = 'noura-consumer-shell-v4';
const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-192-maskable.png',
  '/icon-512.png',
  '/apple-touch-icon.png',
  '/favicon.png',
  '/og-image.jpg',
  '/store.html'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k.startsWith('noura-consumer-') && k !== CACHE)
          .map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Never let the consumer worker hijack the vendor/admin/landing apps.
  if (
    url.pathname === '/vendor' || url.pathname.startsWith('/vendor/') ||
    url.pathname === '/admin' || url.pathname.startsWith('/admin/') ||
    url.pathname === '/landing' || url.pathname.startsWith('/landing/')
  ) return;

  // Storefronts are dynamic. Fetch live data; only use the store shell offline.
  if (url.pathname.startsWith('/store/')) {
    event.respondWith(
      fetch(req).catch(() => caches.match('/store.html'))
    );
    return;
  }

  if (req.mode === 'navigate') {
    // Only the consumer root gets the index fallback.
    if (url.pathname !== '/' && url.pathname !== '/index.html') return;
    event.respondWith(
      fetch(req).then(res => res).catch(() => caches.match('/index.html'))
    );
    return;
  }

  const isStatic = /\.(?:css|js|png|jpg|jpeg|webp|svg|ico|woff2?)$/i.test(url.pathname) ||
                   url.pathname.endsWith('/manifest.json');
  if (!isStatic) return;

  event.respondWith(
    caches.match(req).then(cached => {
      const network = fetch(req).then(res => {
        if (res.ok) {
          caches.open(CACHE).then(c => c.put(req, res.clone()));
        }
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
