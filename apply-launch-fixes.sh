#!/usr/bin/env bash
set -euo pipefail
BRANCH="launch/critical-fixes"
git checkout -b "${BRANCH}"

# backup originals
for f in vercel.json sw.js index.html vendor.html store.html; do
  [ -f "$f" ] && cp -n "$f" "$f.bak" || true
done

# (1) minimal edit to vercel.json
python3 - <<'PY'
from pathlib import Path
p = Path('vercel.json')
if p.exists():
  s = p.read_text()
  s = s.replace('"/store.html?v=$slug"', '"/store/:slug"')
  p.write_text(s)
  print("vercel.json updated")
else:
  print("vercel.json not found, skipping")
PY

# (2) update sw.js APP_SHELL
python3 - <<'PY'
from pathlib import Path
p = Path('sw.js')
if p.exists():
  s = p.read_text()
  s = s.replace("const APP_SHELL = ['index.html', 'manifest.json', 'favicon.png', 'icons/icon-192.png'];",
                "const APP_SHELL = ['index.html', 'store.html', 'vendor.html', 'manifest.json', 'favicon.png', 'icons/icon-192.png'];")
  p.write_text(s)
  print("sw.js updated")
else:
  print("sw.js not found, skipping")
PY

# helper to insert snippet before </body>
insert_before_body() {
  file="$1"; marker="$2"; snippet="$3"
  [ -f "$file" ] || { echo "$file not found, skipping"; return; }
  if grep -Fq "$marker" "$file"; then
    echo "Marker present in $file, skipping"
    return
  fi
  awk -v sn="$snippet" '{
    lines[NR]=$0
  } END {
    lb=-1
    for(i=NR;i>=1;i--) if(tolower(lines[i]) ~ /<\/body>/) { lb=i; break }
    if(lb==-1){ print "NO_BODY_TAG"; exit 1 }
    for(i=1;i<lb;i++) print lines[i]
    print sn
    for(i=lb;i<=NR;i++) print lines[i]
  }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  echo "Inserted snippet into $file"
}

INDEX_SNIPPET=$(cat <<'JS'
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/sw.js').then(function () {
      console.log('Service worker registered: /sw.js');
    }).catch(function (err) { console.warn('SW register failed:', err); });
  });
}
</script>
JS
)

VENDOR_SNIPPET=$(cat <<'JS'
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/sw-vendor.js').then(function () {
      console.log('Vendor service worker registered: /sw-vendor.js');
    }).catch(function (err) { console.warn('Vendor SW register failed:', err); });
  });
}
</script>
JS
)

STORE_SNIPPET=$(cat <<'JS'
<script>
(function(){
  function getStoreSlug(){
    try{
      const path = location.pathname || '';
      const m = path.match(/^\/store\/([^\/]+)/);
      if(m && m[1]) return decodeURIComponent(m[1]);
      const p = new URLSearchParams(location.search);
      if(p.has('v')) return p.get('v');
    }catch(e){}
    return null;
  }
  const STORE_SLUG = getStoreSlug();
  const STORE_URL = STORE_SLUG ? (location.origin + '/store/' + encodeURIComponent(STORE_SLUG)) : location.href;
  try{ const s = document.getElementById('share-link'); if(s){ s.textContent = STORE_URL; s.dataset.url = STORE_URL; } }catch(e){}
  window.NOURA_STORE = window.NOURA_STORE || {}; window.NOURA_STORE.slug = STORE_SLUG; window.NOURA_STORE.url = STORE_URL;
  window.copyStoreLink = function(){ if(navigator.clipboard) navigator.clipboard.writeText(STORE_URL).catch(()=>{}); };
  function applyImgFallback(root){ (root||document).querySelectorAll('img').forEach((img)=>{ if(!img._nouraFallbackAttached){ img._nouraFallbackAttached = true; img.onerror = function(){ img.onerror=null; img.src='/icons/icon-192.png'; }; } }); }
  applyImgFallback();
  const gallery = document.getElementById('gallery-content');
  function ensureGalleryEmptyState(){ if(!gallery) return; const hasPhoto = gallery.querySelector('img, [data-photo]'); if(!hasPhoto && gallery.textContent.trim().length===0) gallery.innerHTML = '<div class="empty">No photos uploaded yet.</div>'; }
  if(gallery){ const mo = new MutationObserver(()=>{ applyImgFallback(gallery); ensureGalleryEmptyState(); }); mo.observe(gallery, { childList:true, subtree:true, characterData:true }); setTimeout(ensureGalleryEmptyState,1100); }
  const homeMenuPreview = document.getElementById('home-menu-preview');
  if(homeMenuPreview){ setTimeout(()=>{ if(homeMenuPreview.children.length===0) homeMenuPreview.innerHTML = '<div class="empty">No menu items yet.</div>'; },1100); }
})();
</script>
JS
)

insert_before_body index.html "Service worker registered: /sw.js" "$INDEX_SNIPPET"
insert_before_body vendor.html "Vendor service worker registered: /sw-vendor.js" "$VENDOR_SNIPPET"
insert_before_body store.html "NOURA_STORE" "$STORE_SNIPPET"

git add -A
echo "Staged changes. Inspect with: git --no-pager diff --staged"
read -p "Commit staged changes now? [y/N] " yn
if [[ "${yn:-N}" =~ ^[Yy]$ ]]; then
  git commit -m "chore: launch fixes — canonical store URL, SW registration, gallery empty state"
  echo "Committed. Now run: git push -u origin ${BRANCH}"
else
  echo "Aborted commit. Branch ${BRANCH} contains staged changes."
fi
