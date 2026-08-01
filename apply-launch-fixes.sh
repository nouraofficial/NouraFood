#!/usr/bin/env bash
set -euo pipefail

BRANCH="launch/critical-fixes"

echo "Creating branch ${BRANCH} (or switching to it if exists)..."
if git show-ref --quiet refs/heads/"${BRANCH}"; then
  git checkout "${BRANCH}"
else
  git checkout -b "${BRANCH}"
fi

# backup originals
echo "Backing up original files (if present)..."
for f in vercel.json sw.js index.html vendor.html store.html services.js; do
  if [ -f "$f" ]; then
    cp -n "$f" "$f.bak" || true
    echo " - backed up $f -> $f.bak"
  fi
done

# (1) minimal edit to vercel.json
echo "Patching vercel.json (host rewrite -> /store/:slug)..."
python3 - <<'PY'
from pathlib import Path
p = Path('vercel.json')
if p.exists():
    s = p.read_text()
    old = '"/store.html?v=$slug"'
    new = '"/store/:slug"'
    if old in s:
        s = s.replace(old, new)
        p.write_text(s)
        print("vercel.json updated")
    elif '"/store/:slug"' in s:
        print("vercel.json already uses /store/:slug, skipping")
    else:
        print("vercel.json did not contain expected pattern; no change made")
else:
    print("vercel.json not found, skipping")
PY

# (2) update sw.js APP_SHELL
echo "Updating sw.js APP_SHELL to include store.html and vendor.html..."
python3 - <<'PY'
from pathlib import Path
p = Path('sw.js')
if p.exists():
    s = p.read_text()
    # try a direct replace first
    old_exact = "const APP_SHELL = ['index.html', 'manifest.json', 'favicon.png', 'icons/icon-192.png'];"
    new_exact = "const APP_SHELL = ['index.html', 'store.html', 'vendor.html', 'manifest.json', 'favicon.png', 'icons/icon-192.png'];"
    if old_exact in s:
        s = s.replace(old_exact, new_exact)
        p.write_text(s)
        print("sw.js updated (exact match)")
    else:
        # try a regex-ish loose replace if spacing differs
        if "const APP_SHELL" in s and "icons/icon-192.png" in s and "store.html" not in s:
            import re
            s2 = re.sub(r"const\s+APP_SHELL\s*=\s*\[.*?icons/icon-192\.png.*?\];", new_exact, s, flags=re.S)
            if s2 != s:
                p.write_text(s2)
                print("sw.js updated (loose match)")
            else:
                print("Could not replace APP_SHELL in sw.js; manual edit may be required")
        else:
            print("sw.js already contains store.html/vendor.html or APP_SHELL missing; skipping")
else:
    print("sw.js not found, skipping")
PY

# helper to insert snippet before the closing </body> (idempotent via marker)
insert_before_body() {
  file="$1"; marker="$2"; snippet="$3"
  if [ ! -f "$file" ]; then
    echo " - $file not found, skipping"
    return
  fi
  if grep -Fq "$marker" "$file"; then
    echo " - marker '$marker' already present in $file, skipping insertion"
    return
  fi
  # Insert snippet just before the last </body> (case-insensitive)
  awk -v sn="$snippet" '{
    lines[NR]=$0
  } END {
    lb=-1
    for(i=NR;i>=1;i--) {
      line = lines[i]
      l = tolower(line)
      if (l ~ /<\/body>/) { lb=i; break }
    }
    if(lb==-1){
      print "NO_BODY_TAG"
      exit 1
    }
    for(i=1;i<lb;i++) print lines[i]
    print sn
    for(i=lb;i<=NR;i++) print lines[i]
  }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  echo " - inserted snippet into $file"
}

# prepare snippets
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

echo "Injecting service worker registration into index.html..."
insert_before_body index.html "Service worker registered: /sw.js" "$INDEX_SNIPPET"

echo "Injecting service worker registration into vendor.html..."
insert_before_body vendor.html "Vendor service worker registered: /sw-vendor.js" "$VENDOR_SNIPPET"

echo "Injecting store slug/share/empty-state snippet into store.html..."
insert_before_body store.html "NOURA_STORE" "$STORE_SNIPPET"

# (3) Append services.js overrides for vendor persistence & getBySlug (idempotent)
echo "Patching services.js: add vendor publish/getBySlug overrides (appends idempotently)..."
python3 - <<'PY'
from pathlib import Path
p = Path('services.js')
if not p.exists():
    print("services.js not found, skipping services patch")
else:
    s = p.read_text()
    marker = "/* NOURA-LAUNCH-FIXES: SERVICES OVERRIDES */"
    if marker in s:
        print("Services overrides already present, skipping append")
    else:
        snippet = r"""

/* NOURA-LAUNCH-FIXES: SERVICES OVERRIDES
   - Adds vendorService.publishToDirectory() that POSTs to /vendors
   - Adds restaurantService.getBySlug() that GETs /vendors/slug/{slug}
   This override is appended at file end and is idempotent.
*/
(function(){
  // Avoid errors if apiRequest is not available
  if (typeof apiRequest !== 'function') { console.warn('apiRequest not found — services overrides skipped'); return; }

  // vendorService.publishToDirectory override
  try {
    if (typeof vendorService !== 'undefined') {
      vendorService.publishToDirectory = vendorService.publishToDirectory || (async function(){
        var local = this._get ? this._get() : null;
        if (!local) return { ok:false, reason:'No local vendor' };
        var payload = {
          name: local.businessName || local.name || '',
          username: local.username || local.slug || (local.businessName ? slugify(local.businessName) : ''),
          description: local.description || local.bio || '',
          category: local.category || '',
          phone: local.phone || '',
          whatsapp: local.whatsapp || local.whatsappNumber || '',
          website: local.website || '',
          address: local.address || '',
          hours: local.hours || null,
          priceRange: local.priceRange || null,
          delivery: !!local.delivery,
          pickup: !!local.pickup,
          logoUrl: local.logoUrl || null,
          coverUrl: local.coverUrl || null,
          menu: local.menu || []
        };
        try {
          var res = await apiRequest('/vendors', { method: 'POST', body: payload });
          if (res && (res.ok || res.vendor)) {
            var v = res.vendor || res;
            this._set && this._set(v);
            return { ok:true, vendor: v };
          } else {
            return { ok:false, reason: (res && res.reason) ? res.reason : 'Publish failed' };
          }
        } catch (err) {
          console.error('publishToDirectory error', err);
          return { ok:false, reason: (err && err.message) ? err.message : String(err) };
        }
      });
    } else {
      console.warn('vendorService not defined — publish override skipped');
    }
  } catch(e){ console.error('publish override error', e); }

  // restaurantService.getBySlug override
  try {
    if (typeof restaurantService !== 'undefined') {
      restaurantService.getBySlug = restaurantService.getBySlug || (async function(slug){
        if (!slug) return { ok:false, reason:'Missing slug' };
        try {
          var res = await apiRequest('/vendors/slug/' + encodeURIComponent(slug));
          if (res && (res.vendor || res.ok)) {
            var vendor = res.vendor || res;
            return { ok:true, vendor: vendor };
          } else if (res && res.status === 404) {
            return { ok:false, code:404, reason:'Not found' };
          } else {
            return { ok:false, reason: (res && res.reason) ? res.reason : 'Failed to load vendor' };
          }
        } catch (err) {
          console.error('getBySlug error', err);
          return { ok:false, reason: (err && err.message) ? err.message : String(err) };
        }
      });
    } else {
      console.warn('restaurantService not defined — getBySlug override skipped');
    }
  } catch(e){ console.error('getBySlug override error', e); }

  console.log('Noura launch-fixes: services overrides applied');
})();
"""
        p.write_text(s + snippet)
        print("Appended services overrides to services.js")
PY

echo "Staging changes..."
git add -A

echo
echo "=== git diff (staged) ==="
git --no-pager diff --staged || true
echo

read -p "Commit staged changes now? [y/N] " yn
yn=${yn:-N}
if [[ "${yn}" =~ ^[Yy]$ ]]; then
  git commit -m "chore: launch fixes — canonical store URL, SW registration, gallery empty state, services overrides"
  echo "Committed. To push run: git push -u origin ${BRANCH}"
else
  echo "Aborted commit. Branch ${BRANCH} contains staged changes (you can inspect and commit later)."
fi

echo "Done."
