// Service worker minimal : permet d'installer l'app sur le téléphone.
// Stratégie « réseau d'abord » : on a toujours la dernière version de l'app,
// la copie en cache ne sert que si le téléphone est hors ligne.
const CACHE = "heures-v3";
const FICHIERS = ["./", "index.html", "punch.html", "config.js", "manifest.json", "manifest-punch.json", "icone.svg", "icone-192.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FICHIERS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((cles) => Promise.all(cles.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  // On ne touche qu'aux fichiers de l'app elle-même (jamais aux appels Supabase)
  if (e.request.method !== "GET" || url.origin !== self.location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then((rep) => {
        const copie = rep.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copie));
        return rep;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match("index.html")))
  );
});
