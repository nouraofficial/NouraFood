const CACHE = 'noura-consumer-v1';
const APP_SHELL = ['./','./index.html','./manifest.json','./icon-192.png','./icon-192-maskable.png','./icon-512.png','./apple-touch-icon.png','./favicon.png','./og-image.jpg'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;
  // App shell: cache-first, but always attempt a network refresh for navigation.
  if (req.mode === 'navigate') {
    event.respondWith(fetch(req).then(res => { const copy=res.clone(); caches.open(CACHE).then(c=>c.put('./index.html',copy)); return res; }).catch(() => caches.match('./index.html')));
    return;
  }
  // Only cache known static assets. Dynamic same-origin API/data requests stay network-only.
  const isStatic = /\.(?:css|js|png|jpg|jpeg|webp|svg|ico|woff2?)$/i.test(url.pathname) || url.pathname.endsWith('/manifest.json');
  if (!isStatic) { event.respondWith(fetch(req)); return; }
  event.respondWith(caches.match(req).then(cached => {
    const network = fetch(req).then(res => { if(res.ok) caches.open(CACHE).then(c=>c.put(req,res.clone())); return res; }).catch(()=>cached);
    return cached || network;
  }));
});
