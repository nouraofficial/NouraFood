/**
 * ══════════════════════════════════════════════════════════════
 *  NOURA — SERVICE LAYER  (services.js)
 * ══════════════════════════════════════════════════════════════
 *  Shared by every screen: main app, vendor portal, admin
 *  dashboard, landing page. This is the ONLY file that talks to
 *  local storage or the network — screens never touch either
 *  directly. That's what makes this backend-ready: when the real
 *  API exists, only the bodies of these functions change.
 *
 *  Load order in each HTML file: config, then services, then the
 *  screen-specific UI code — each inlined directly (see index.html)
 *  so the app works standalone with no external file dependencies.
 *
 *  Everything is exposed on window.Services.
 * ══════════════════════════════════════════════════════════════
 */
(function () {
  'use strict';

  const ENV = window.NOURA_ENV || {};

  /* ────────────────────────────────────────────────────────────
   *  TYPES  (JSDoc — no build step, so this is our TypeScript)
   * ──────────────────────────────────────────────────────────── */
  /**
   * @typedef {Object} User
   * @property {string} id
   * @property {string} name
   * @property {string} username
   * @property {string} email
   * @property {string} bio
   * @property {string} country
   * @property {string[]} cuisines
   * @property {string} diet
   * @property {string[]} allergies
   */
  /** @typedef {Object} Preferences
   * @property {string} budget @property {string[]} mealtimes @property {string} goal
   * @property {string[]} favFoods @property {string[]} avoid @property {string} skill */
  /** @typedef {Object} Restaurant
   * @property {string} id @property {string} name @property {string} cuisine
   * @property {string} area @property {string} emoji @property {number} rating
   * @property {number} reviews @property {boolean} verified @property {boolean} open
   * @property {string} priceRange @property {string[]} tags @property {string} phone
   * @property {string} whatsapp @property {string} website @property {string} hours
   * @property {Array<Object>} menu @property {Array<Object>} reviews_data */
  /** @typedef {Object} Recipe
   * @property {string} id @property {string} source ('mealdb'|'edamam')
   * @property {string} name @property {string} thumb @property {string} category
   * @property {string} area @property {Array<{name:string,measure:string}>} ingredients
   * @property {string[]} steps @property {number} [calories] @property {number} [servings] */
  /** @typedef {Object} MealPlanEntry
   * @property {string} slot ('breakfast'|'lunch'|'dinner'|'snack')
   * @property {Recipe} recipe */
  /** @typedef {Object} Notification
   * @property {string} id @property {string} type @property {string} icon
   * @property {string} color @property {string} title @property {string} msg
   * @property {string} time @property {boolean} unread */
  /** @typedef {Object} Settings
   * @property {boolean} darkMode @property {boolean} pushNotifications
   * @property {boolean} emailNotifications */
  /** @typedef {Object} Vendor
   * @property {string} id @property {string} businessName @property {string} ownerName
   * @property {string} email @property {string} status ('pending'|'approved'|'rejected') */
  /** @typedef {Object} Order
   * @property {string} id @property {string} restaurantId @property {string} userId
   * @property {Array<Object>} items @property {number} total @property {string} status */
  /** @typedef {Object} Favourite
   * @property {string} id @property {'recipe'|'restaurant'} type @property {string} refId */
  /** @typedef {Object} AIResponse
   * @property {string} text @property {boolean} ok @property {string} [error] */

  /* ────────────────────────────────────────────────────────────
   *  LOCAL STORAGE HELPERS  (offline cache — not the source of truth)
   * ──────────────────────────────────────────────────────────── */
  function lsGet(key, fallback) {
    try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; }
    catch { return fallback; }
  }
  function lsSet(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch {}
  }
  function lsDel(key) { try { localStorage.removeItem(key); } catch {} }
  function uid() { return 'id_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8); }
  function slugify(str) {
    return (str || '').toLowerCase().trim()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '') || 'vendor';
  }
  function makeUniqueSlug(businessName) {
    const base = slugify(businessName);
    const taken = new Set(lsGet('noura_restaurants', []).map((r) => r.slug).filter(Boolean));
    if (!taken.has(base)) return base;
    let i = 2;
    while (taken.has(`${base}-${i}`)) i++;
    return `${base}-${i}`;
  }

  /* ────────────────────────────────────────────────────────────
   *  API CLIENT  — one place that knows how to reach the backend.
   *  Every service calls apiRequest() first. If BACKEND_READY is
   *  false, or the call fails/times out, callers get a typed
   *  result they can branch on ({ok:false, reason}) instead of a
   *  thrown crash — screens use this to show loading/empty/error
   *  states, never fake data.
   * ──────────────────────────────────────────────────────────── */
  const REQUEST_TIMEOUT_MS = 10000;

  async function apiRequest(path, { method = 'GET', body, headers = {}, timeoutMs = REQUEST_TIMEOUT_MS } = {}) {
    if (!ENV.BACKEND_READY || !ENV.API_BASE_URL) {
      return { ok: false, reason: 'no_backend', data: null };
    }
    try {
      const token = AuthStore.getAccessToken();
      const res = await fetch(ENV.API_BASE_URL + path, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: 'Bearer ' + token } : {}),
          ...headers,
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (res.status === 401) return { ok: false, reason: 'auth', data: null };
      if (!res.ok) return { ok: false, reason: 'server', status: res.status, data: null };
      const data = await res.json().catch(() => null);
      return { ok: true, reason: null, data };
    } catch (err) {
      const reason = err?.name === 'TimeoutError' || err?.name === 'AbortError' ? 'timeout' : 'network';
      return { ok: false, reason, data: null };
    }
  }

  /* ────────────────────────────────────────────────────────────
   *  SUPABASE CLIENT — lazy singleton. Only exists once the
   *  Supabase JS SDK is loaded (via CDN script tag) and a real
   *  project URL/key are set in config.js.
   * ──────────────────────────────────────────────────────────── */
  let _sb = null;
  function getSupabase() {
    if (_sb) return _sb;
    if (!ENV.SUPABASE_URL || !ENV.SUPABASE_ANON_KEY || typeof window.supabase === 'undefined') return null;
    _sb = window.supabase.createClient(ENV.SUPABASE_URL, ENV.SUPABASE_ANON_KEY);
    return _sb;
  }

  /* ────────────────────────────────────────────────────────────
   *  AUTH STORE — token persistence (secure logout, persistent
   *  login, refresh token). Swap localStorage for httpOnly
   *  cookies set by the backend once /auth endpoints exist.
   * ──────────────────────────────────────────────────────────── */
  const AuthStore = {
    getAccessToken: () => lsGet('noura_access_token', null),
    getRefreshToken: () => lsGet('noura_refresh_token', null),
    setTokens: (access, refresh) => { lsSet('noura_access_token', access); if (refresh) lsSet('noura_refresh_token', refresh); },
    clearTokens: () => { lsDel('noura_access_token'); lsDel('noura_refresh_token'); },
    isPersisted: () => !!lsGet('noura_access_token', null) || !!lsGet('noura_local_session', null),
  };

  /* ════════════════════════════════════════════════════════════
   *  AUTH SERVICE
   * ════════════════════════════════════════════════════════════ */
  const authService = {
    /** @returns {Promise<{ok:boolean, user:User|null, reason?:string}>} */
    async login(email, password) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.auth.signInWithPassword({ email, password });
        if (error) return { ok: false, user: null, reason: error.message || 'auth_error' };
        AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
        const { user } = await userProfileService.loadProfile();
        return { ok: true, user };
      }
      const res = await apiRequest('/auth/login', { method: 'POST', body: { email, password } });
      if (res.ok) {
        AuthStore.setTokens(res.data.accessToken, res.data.refreshToken);
        userProfileService._cacheUser(res.data.user);
        return { ok: true, user: res.data.user };
      }
      if (res.reason === 'no_backend') {
        // No backend configured yet — keep the user's real entry, never invent one.
        const existing = userProfileService._getCachedUser();
        const user = existing?.email === email ? existing : { ...userProfileService._blankUser(), email };
        lsSet('noura_local_session', { email, since: Date.now() });
        userProfileService._cacheUser(user);
        return { ok: true, user, reason: 'no_backend' };
      }
      return { ok: false, user: null, reason: res.reason };
    },

    async register({ name, username, email, password }) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.auth.signUp({
          email, password,
          options: { data: { name, username: '@' + username.replace(/^@/, '') } },
        });
        if (error) return { ok: false, user: null, reason: error.message || 'auth_error' };
        if (!data.session) {
          // Email confirmation is required before a session exists.
          return { ok: true, user: { name, username, email }, reason: 'confirm_email' };
        }
        AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
        // Belt-and-suspenders: the DB trigger creates the row, but upsert here
        // in case the trigger hasn't landed yet by the time we read it back.
        await sb.from('profiles').upsert({ id: data.user.id, email, name, username: '@' + username.replace(/^@/, '') });
        const { user } = await userProfileService.loadProfile();
        return { ok: true, user };
      }
      const res = await apiRequest('/auth/register', { method: 'POST', body: { name, username, email, password } });
      if (res.ok) {
        AuthStore.setTokens(res.data.accessToken, res.data.refreshToken);
        userProfileService._cacheUser(res.data.user);
        return { ok: true, user: res.data.user };
      }
      if (res.reason === 'no_backend') {
        const user = { ...userProfileService._blankUser(), name, username: '@' + username.replace(/^@/, ''), email };
        lsSet('noura_local_session', { email, since: Date.now() });
        userProfileService._cacheUser(user);
        return { ok: true, user, reason: 'no_backend' };
      }
      return { ok: false, user: null, reason: res.reason };
    },

    async forgotPassword(email) {
      const sb = getSupabase();
      if (sb) {
        const { error } = await sb.auth.resetPasswordForEmail(email);
        return { ok: !error, reason: error?.message };
      }
      const res = await apiRequest('/auth/forgot-password', { method: 'POST', body: { email } });
      if (res.ok) return { ok: true };
      if (res.reason === 'no_backend') return { ok: true, reason: 'no_backend' }; // UI shows "check your email" either way
      return { ok: false, reason: res.reason };
    },

    /** Continue with Google — redirects the browser; session is picked up
     *  on return via Supabase's own auth state, not a direct return value. */
    async loginWithGoogle() {
      const sb = getSupabase();
      if (sb) {
        const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin } });
        return { ok: !error, reason: error?.message };
      }
      return { ok: false, reason: 'not_configured' };
    },

    async refreshToken() {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.auth.refreshSession();
        if (error) return { ok: false };
        AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
        return { ok: true };
      }
      const refresh = AuthStore.getRefreshToken();
      if (!refresh) return { ok: false };
      const res = await apiRequest('/auth/refresh', { method: 'POST', body: { refreshToken: refresh } });
      if (res.ok) { AuthStore.setTokens(res.data.accessToken, res.data.refreshToken); return { ok: true }; }
      return { ok: false };
    },

    async logout() {
      const sb = getSupabase();
      if (sb) await sb.auth.signOut();
      else if (ENV.BACKEND_READY) await apiRequest('/auth/logout', { method: 'POST' });
      AuthStore.clearTokens();
      lsDel('noura_local_session');
      lsDel('noura_user');
    },

    isLoggedIn: () => AuthStore.isPersisted(),

    /** Call once on app load. Picks up a real Supabase session (e.g.
     *  right after an OAuth redirect back from Google) and mirrors it
     *  into our own AuthStore so isLoggedIn() reflects it correctly. */
    async syncSession() {
      const sb = getSupabase();
      if (!sb) return;
      const { data } = await sb.auth.getSession();
      if (data?.session) AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  USER PROFILE SERVICE
   * ════════════════════════════════════════════════════════════ */
  const userProfileService = {
    _blankUser: () => ({ id: '', name: '', username: '', email: '', bio: '', country: '', cuisines: [], diet: '', allergies: [] }),
    _getCachedUser: () => lsGet('noura_user', null),
    _cacheUser: (u) => lsSet('noura_user', u),

    /** @returns {Promise<{ok:boolean, user:User|null, loading:boolean}>} */
    async loadProfile() {
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        if (!uid) return { ok: false, user: null };
        const { data, error } = await sb.from('profiles').select('*').eq('id', uid).single();
        if (error) return { ok: false, user: this._getCachedUser() };
        const user = {
          id: data.id, name: data.name || '', username: data.username || '', email: data.email || '',
          bio: data.bio || '', country: data.country || '', cuisines: data.cuisines || [],
          diet: data.diet || '', allergies: data.allergies || [], avatarUrl: data.avatar_url || '',
        };
        this._cacheUser(user);
        return { ok: true, user };
      }
      const res = await apiRequest('/user/profile', { method: 'GET' });
      if (res.ok) { this._cacheUser(res.data); return { ok: true, user: res.data }; }
      // No backend yet: fall back to the user's own saved data (never demo data).
      const cached = this._getCachedUser();
      return { ok: !!cached, user: cached || null };
    },

    async updateProfile(patch) {
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        if (!uid) return { ok: false };
        const { error } = await sb.from('profiles').update(patch).eq('id', uid);
        if (error) return { ok: false, reason: error.message };
        const merged = { ...(this._getCachedUser() || this._blankUser()), ...patch };
        this._cacheUser(merged);
        return { ok: true, user: merged };
      }
      const res = await apiRequest('/user/profile', { method: 'PATCH', body: patch });
      if (res.ok) { this._cacheUser(res.data); return { ok: true, user: res.data }; }
      const merged = { ...(this._getCachedUser() || this._blankUser()), ...patch };
      this._cacheUser(merged);
      return { ok: true, user: merged, reason: res.reason };
    },

    async loadPreferences() {
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        if (uid) {
          const { data, error } = await sb.from('user_preferences').select('*').eq('user_id', uid).maybeSingle();
          if (!error) {
            const prefs = data
              ? { budget: data.budget || '', mealtimes: data.mealtimes || [], goal: data.goal || '', favFoods: data.fav_foods || [], avoid: data.avoid || [], skill: data.skill || '' }
              : this._blankPrefs();
            lsSet('noura_prefs', prefs);
            return { ok: true, prefs };
          }
        }
      }
      const res = await apiRequest('/user/preferences', { method: 'GET' });
      if (res.ok) { lsSet('noura_prefs', res.data); return { ok: true, prefs: res.data }; }
      return { ok: true, prefs: lsGet('noura_prefs', this._blankPrefs()) };
    },
    _blankPrefs: () => ({ budget: '', mealtimes: [], goal: '', favFoods: [], avoid: [], skill: '' }),

    async updatePreferences(patch) {
      const merged = { ...lsGet('noura_prefs', this._blankPrefs()), ...patch };
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        if (uid) {
          await sb.from('user_preferences').upsert({
            user_id: uid, budget: merged.budget, mealtimes: merged.mealtimes, goal: merged.goal,
            fav_foods: merged.favFoods, avoid: merged.avoid, skill: merged.skill,
          });
          lsSet('noura_prefs', merged);
          return { ok: true, prefs: merged };
        }
      }
      const res = await apiRequest('/user/preferences', { method: 'PATCH', body: merged });
      lsSet('noura_prefs', merged);
      return { ok: true, prefs: merged, reason: res.ok ? null : res.reason };
    },

    async changePassword(currentPassword, newPassword) {
      const res = await apiRequest('/user/change-password', { method: 'POST', body: { currentPassword, newPassword } });
      if (res.ok) return { ok: true };
      if (res.reason === 'no_backend') return { ok: false, reason: 'no_backend' };
      return { ok: false, reason: res.reason };
    },

    async changeEmail(newEmail, password) {
      const res = await apiRequest('/user/change-email', { method: 'POST', body: { newEmail, password } });
      if (res.ok) { const u = { ...(this._getCachedUser() || {}), email: newEmail }; this._cacheUser(u); return { ok: true, user: u }; }
      if (res.reason === 'no_backend') { const u = { ...(this._getCachedUser() || {}), email: newEmail }; this._cacheUser(u); return { ok: true, user: u, reason: 'no_backend' }; }
      return { ok: false, reason: res.reason };
    },

    async deleteAccount() {
      const res = await apiRequest('/user/account', { method: 'DELETE' });
      await authService.logout();
      lsDel('noura_prefs'); lsDel('noura_saved'); lsDel('noura_fav_restaurants');
      return { ok: res.ok || res.reason === 'no_backend' };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  RESTAURANT SERVICE
   *  Real restaurant records come from the vendor portal (which
   *  writes to the same 'noura_restaurants' store / future
   *  GET/POST /restaurants API). Nothing here is sample data —
   *  an empty list means no vendor has published yet.
   * ════════════════════════════════════════════════════════════ */
  function mapRestaurantRow(row) {
    return {
      id: row.id, slug: row.slug, name: row.name, cuisine: row.cuisine, area: row.area,
      emoji: row.emoji || '🍽️', rating: row.rating, reviews: row.review_count ?? (row.reviews?.length || 0),
      verified: row.verified, open: row.open, priceRange: row.price_range,
      tags: row.tags || [], phone: row.phone, whatsapp: row.whatsapp, website: row.website, hours: row.hours,
      logoUrl: row.logo_url, coverUrl: row.cover_url,
      menu: (row.menu_items || []).map((m) => ({ id: m.id, name: m.name, price: m.price, cat: m.category, desc: m.description, emoji: m.emoji || '🍽️', time: m.prep_time, available: m.available })),
      reviews_data: (row.reviews || []).map((r) => ({ id: r.id, author: r.author, stars: r.stars, text: r.text, date: r.created_at ? new Date(r.created_at).toLocaleDateString() : '', reply: r.reply, replied: r.replied })),
    };
  }

  const restaurantService = {
    async list() {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.from('restaurants').select('*, menu_items(*), reviews(*)').order('created_at', { ascending: false });
        if (!error) { const restaurants = (data || []).map(mapRestaurantRow); lsSet('noura_restaurants', restaurants); return { ok: true, loading: false, restaurants }; }
      }
      const res = await apiRequest('/restaurants', { method: 'GET' });
      if (res.ok) { lsSet('noura_restaurants', res.data); return { ok: true, loading: false, restaurants: res.data }; }
      return { ok: true, loading: false, restaurants: lsGet('noura_restaurants', []) };
    },
    async get(id) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.from('restaurants').select('*, menu_items(*), reviews(*)').eq('id', id).maybeSingle();
        if (!error && data) return { ok: true, restaurant: mapRestaurantRow(data) };
      }
      const res = await apiRequest('/restaurants/' + id, { method: 'GET' });
      if (res.ok) return { ok: true, restaurant: res.data };
      const local = lsGet('noura_restaurants', []).find((r) => r.id === id) || null;
      return { ok: !!local, restaurant: local };
    },
    async getBySlug(slug) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.from('restaurants').select('*, menu_items(*), reviews(*)').eq('slug', slug).maybeSingle();
        if (!error && data) return { ok: true, restaurant: mapRestaurantRow(data) };
      }
      const res = await apiRequest('/restaurants/slug/' + slug, { method: 'GET' });
      if (res.ok) return { ok: true, restaurant: res.data };
      const local = lsGet('noura_restaurants', []).find((r) => r.slug === slug) || null;
      return { ok: !!local, restaurant: local };
    },
    async search(query) {
      const { restaurants } = await this.list();
      const v = (query || '').toLowerCase().trim();
      if (!v) return restaurants;
      return restaurants.filter((r) =>
        r.name?.toLowerCase().includes(v) || r.cuisine?.toLowerCase().includes(v) || (r.tags || []).some((t) => t.toLowerCase().includes(v))
      );
    },
    async filterByCategory(cat) {
      const { restaurants } = await this.list();
      if (cat === 'all') return restaurants;
      return restaurants.filter((r) => r.cuisine === cat || (r.tags || []).includes(cat));
    },
    async submitReview(restaurantId, review) {
      challengesService.incrementReviewsWritten();
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        const { error } = await sb.from('reviews').insert({
          restaurant_id: restaurantId, user_id: uid || null,
          author: review.author, stars: review.stars, text: review.text,
        });
        if (!error) return { ok: true };
      }
      const res = await apiRequest(`/restaurants/${restaurantId}/reviews`, { method: 'POST', body: review });
      if (res.ok) return { ok: true };
      // Local fallback so vendors/testers still see it reflected until backend exists.
      const rests = lsGet('noura_restaurants', []);
      const r = rests.find((x) => x.id === restaurantId);
      if (r) { r.reviews_data = r.reviews_data || []; r.reviews_data.unshift(review); r.reviews = (r.reviews || 0) + 1; lsSet('noura_restaurants', rests); }
      return { ok: true, reason: 'no_backend' };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  RECIPE SERVICE
   *  Wraps the two real, live recipe data providers (TheMealDB
   *  for global dishes, Edamam for African/local dishes). These
   *  are genuine external data sources, not mock data — kept
   *  exactly as before, just moved behind one service boundary.
   * ════════════════════════════════════════════════════════════ */
  const MEAL_BASE = ENV.MEALDB_BASE_URL || 'https://www.themealdb.com/api/json/v1/1';
  const EDAMAM_APP_ID = ENV.EDAMAM_APP_ID;
  const EDAMAM_APP_KEY = ENV.EDAMAM_APP_KEY;
  const EDAMAM_BASE = 'https://api.edamam.com/api/recipes/v2';
  const EDAMAM_READY = !!(EDAMAM_APP_ID && EDAMAM_APP_ID !== 'YOUR_EDAMAM_APP_ID');
  const IS_LOCAL_PROTOCOL = ['file:', 'null:'].includes(location.protocol) || ['localhost', '127.0.0.1'].includes(location.hostname);
  const PROXIES = ENV.DEV_CORS_PROXIES || [];

  const LOCAL_CUISINE_GROUPS = {
    '🇳🇬 Nigerian': ['jollof rice', 'egusi soup', 'pounded yam', 'suya', 'moi moi', 'pepper soup', 'afang soup', 'efo riro', 'ofada rice', 'ogbono soup', 'akara', 'puff puff', 'banga soup', 'tuwo shinkafa', 'chin chin'],
    '🇬🇭 Ghanaian': ['fufu', 'kontomire stew', 'kelewele', 'groundnut soup', 'waakye', 'banku', 'tilapia', 'red red', 'light soup ghana', 'jollof ghana', 'tom brown porridge'],
    '🇰🇪 Kenyan': ['ugali', 'sukuma wiki', 'nyama choma', 'githeri', 'pilau kenya', 'mukimo', 'mandazi', 'chapati kenya', 'matoke', 'wali wa nazi'],
    '🌍 East African': ['injera', 'doro wat', 'kitfo', 'tibs', 'ful medames', 'samosa', 'pilau', 'biryani east africa'],
    '🌍 West African': ['thieboudienne', 'yassa', 'maafe', 'ndole', 'egusi', 'plantain stew', 'palm nut soup', 'groundnut stew'],
    '🌍 South African': ['bobotie', 'bunny chow', 'boerewors', 'pap', 'chakalaka', 'koeksisters', 'braai', 'potjiekos'],
  };

  async function mealDbFetch(path) {
    const directUrl = MEAL_BASE + path;
    if (!IS_LOCAL_PROTOCOL) {
      try { const res = await fetch(directUrl); if (!res.ok) throw new Error('HTTP ' + res.status); return await res.json(); }
      catch { return null; }
    }
    for (const mkProxy of PROXIES) {
      try {
        const res = await fetch(mkProxy(directUrl), { signal: AbortSignal.timeout(9000) });
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return await res.json();
      } catch { /* try next proxy */ }
    }
    return null;
  }

  async function edamamFetch(query, opts = {}) {
    if (!EDAMAM_READY) return null;
    const params = new URLSearchParams({
      type: 'public', q: query, app_id: EDAMAM_APP_ID, app_key: EDAMAM_APP_KEY,
      from: opts.from || 0, to: opts.to || 20, ...(opts.extra || {}),
    });
    try {
      const res = await fetch(EDAMAM_BASE + '?' + params.toString(), { signal: AbortSignal.timeout(10000) });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return await res.json();
    } catch { return null; }
  }

  function normaliseEdamam(hit) {
    const r = hit.recipe;
    return {
      id: hit._links?.self?.href || r.label, idMeal: hit._links?.self?.href || r.label,
      name: r.label, strMeal: r.label, thumb: r.image, strMealThumb: r.image,
      category: r.cuisineType?.[0] || 'Local', strCategory: r.cuisineType?.[0] || 'Local',
      area: (r.cuisineType || []).join(', '), strArea: (r.cuisineType || []).join(', '),
      source: 'edamam', ingredients: r.ingredientLines || [], calories: Math.round(r.calories || 0),
      servings: r.yield || 1, totalTime: r.totalTime || 0, dietLabels: r.dietLabels || [],
      healthLabels: r.healthLabels || [], url: r.url, strSource: r.url,
    };
  }

  const recipeService = {
    isLocalProviderReady: EDAMAM_READY,
    localCuisineGroups: LOCAL_CUISINE_GROUPS,

    mealDb: {
      search: (q) => mealDbFetch('/search.php?s=' + encodeURIComponent(q)),
      byId: (id) => mealDbFetch('/lookup.php?i=' + id),
      random: () => mealDbFetch('/random.php'),
      byCategory: (c) => mealDbFetch('/filter.php?c=' + encodeURIComponent(c)),
      categories: () => mealDbFetch('/categories.php'),
      randoms: async (n) => {
        const results = await Promise.all(Array.from({ length: n }, () => mealDbFetch('/random.php')));
        return results.filter(Boolean).map((r) => r.meals?.[0]).filter(Boolean);
      },
    },

    local: {
      normalise: normaliseEdamam,
      search: (q, from = 0) => edamamFetch(q, { from, to: from + 20 }),
      byGroup: async (label) => {
        if (!EDAMAM_READY) return [];
        const terms = LOCAL_CUISINE_GROUPS[label] || [label];
        const results = await Promise.all(terms.slice(0, 3).map((t) => edamamFetch(t, { to: 8 })));
        return results.filter(Boolean).flatMap((d) => d.hits || []).map(normaliseEdamam);
      },
      byId: async (selfUrl) => {
        if (!EDAMAM_READY || !selfUrl?.startsWith('http')) return null;
        const url = selfUrl + '?type=public&app_id=' + EDAMAM_APP_ID + '&app_key=' + EDAMAM_APP_KEY;
        try {
          const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
          if (!res.ok) throw new Error('HTTP ' + res.status);
          return normaliseEdamam(await res.json());
        } catch { return null; }
      },
    },

    getIngredients(meal) {
      const list = [];
      for (let i = 1; i <= 20; i++) {
        const name = (meal['strIngredient' + i] || '').trim();
        const measure = (meal['strMeasure' + i] || '').trim();
        if (name) list.push({ name, measure });
      }
      return list;
    },
    getSteps(meal) {
      const raw = (meal.strInstructions || '').trim();
      if (!raw) return [];
      let steps = raw.split(/\r?\n/).map((s) => s.replace(/^\s*\d+[.):\-]\s*/, '').trim()).filter((s) => s.length > 15);
      if (steps.length < 2) steps = raw.split(/(?<=[.!?])\s{1,3}(?=[A-Z])/).filter((s) => s.trim().length > 15);
      return steps.slice(0, 15);
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  MEAL PLAN SERVICE
   * ════════════════════════════════════════════════════════════ */
  const mealPlanService = {
    async loadMealPlan() {
      const res = await apiRequest('/meal-plan', { method: 'GET' });
      if (res.ok) return { ok: true, plan: res.data };
      // No backend yet: build today's plan from live recipe data (not fake meals).
      const meals = await recipeService.mealDb.randoms(4);
      if (!meals.length) return { ok: false, plan: [] };
      const slots = ['breakfast', 'lunch', 'dinner', 'snack'];
      const plan = meals.map((m, i) => ({ slot: slots[i], recipe: m }));
      return { ok: true, plan, reason: 'no_backend' };
    },
    async savePlan(plan) {
      const res = await apiRequest('/meal-plan', { method: 'POST', body: plan });
      return { ok: res.ok || true, reason: res.ok ? null : res.reason };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  NOTIFICATION SERVICE  — no seed/demo notifications. An empty
   *  inbox is a real, valid state until the backend sends one.
   * ════════════════════════════════════════════════════════════ */
  const notificationService = {
    async _uid() {
      const sb = getSupabase(); if (!sb) return null;
      const { data } = await sb.auth.getSession();
      return data?.session?.user?.id || null;
    },
    async list() {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        const { data, error } = await sb.from('notifications').select('*').eq('user_id', uid).order('created_at', { ascending: false });
        if (!error) {
          const notifications = (data || []).map((n) => ({ id: n.id, type: n.type, icon: n.icon, color: n.color, title: n.title, msg: n.message, time: n.created_at ? new Date(n.created_at).toLocaleString() : '', unread: n.unread }));
          lsSet('noura_notifications', notifications);
          return { ok: true, notifications };
        }
      }
      const res = await apiRequest('/notifications', { method: 'GET' });
      if (res.ok) { lsSet('noura_notifications', res.data); return { ok: true, notifications: res.data }; }
      return { ok: true, notifications: lsGet('noura_notifications', []) };
    },
    async markRead(id) {
      const sb = getSupabase();
      if (sb) await sb.from('notifications').update({ unread: false }).eq('id', id);
      else await apiRequest(`/notifications/${id}/read`, { method: 'POST' });
      const ns = lsGet('noura_notifications', []);
      const n = ns.find((x) => x.id === id);
      if (n) { n.unread = false; lsSet('noura_notifications', ns); }
    },
    async markAllRead() {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) await sb.from('notifications').update({ unread: false }).eq('user_id', uid);
      else await apiRequest('/notifications/read-all', { method: 'POST' });
      lsSet('noura_notifications', lsGet('noura_notifications', []).map((n) => ({ ...n, unread: false })));
    },
    async hasUnread() { const { notifications } = await this.list(); return notifications.some((n) => n.unread); },
  };

  /* ════════════════════════════════════════════════════════════
   *  FAVOURITES SERVICE  (saved recipes + favourite restaurants)
   * ════════════════════════════════════════════════════════════ */
  const favouritesService = {
    async _uid() {
      const sb = getSupabase(); if (!sb) return null;
      const { data } = await sb.auth.getSession();
      return data?.session?.user?.id || null;
    },
    async listRecipes() {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        const { data, error } = await sb.from('favourite_recipes').select('*').eq('user_id', uid);
        if (!error) {
          const recipes = (data || []).map((r) => ({ id: r.recipe_id, source: r.source, name: r.name, thumb: r.thumb, category: r.category, area: r.area }));
          lsSet('noura_saved', recipes); return recipes;
        }
      }
      const res = await apiRequest('/favorites?type=recipe', { method: 'GET' });
      if (res.ok) { lsSet('noura_saved', res.data); return res.data; }
      return lsGet('noura_saved', []);
    },
    async toggleRecipe(recipe) {
      const saved = await this.listRecipes();
      const idx = saved.findIndex((r) => r.id === recipe.id);
      const willSave = idx < 0;
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        if (willSave) await sb.from('favourite_recipes').insert({ user_id: uid, recipe_id: recipe.id, source: recipe.source, name: recipe.name, thumb: recipe.thumb, category: recipe.category, area: recipe.area });
        else await sb.from('favourite_recipes').delete().eq('user_id', uid).eq('recipe_id', recipe.id);
        if (willSave) saved.push(recipe); else saved.splice(idx, 1);
        lsSet('noura_saved', saved);
        return { ok: true, saved: willSave };
      }
      if (willSave) saved.push(recipe); else saved.splice(idx, 1);
      lsSet('noura_saved', saved);
      const res = await apiRequest('/favorites', { method: willSave ? 'POST' : 'DELETE', body: { type: 'recipe', refId: recipe.id } });
      return { ok: true, saved: willSave, reason: res.ok ? null : res.reason };
    },
    async removeRecipe(id) {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) await sb.from('favourite_recipes').delete().eq('user_id', uid).eq('recipe_id', id);
      lsSet('noura_saved', lsGet('noura_saved', []).filter((r) => r.id !== id));
      if (!sb) await apiRequest('/favorites', { method: 'DELETE', body: { type: 'recipe', refId: id } });
    },
    async listRestaurantIds() {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        const { data, error } = await sb.from('favourite_restaurants').select('restaurant_id').eq('user_id', uid);
        if (!error) { const ids = (data || []).map((r) => r.restaurant_id); lsSet('noura_fav_restaurants', ids); return ids; }
      }
      const res = await apiRequest('/favorites?type=restaurant', { method: 'GET' });
      if (res.ok) { lsSet('noura_fav_restaurants', res.data); return res.data; }
      return lsGet('noura_fav_restaurants', []);
    },
    async toggleRestaurant(id) {
      const favs = await this.listRestaurantIds();
      const idx = favs.indexOf(id);
      const willSave = idx < 0;
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        if (willSave) await sb.from('favourite_restaurants').insert({ user_id: uid, restaurant_id: id });
        else await sb.from('favourite_restaurants').delete().eq('user_id', uid).eq('restaurant_id', id);
        if (willSave) favs.push(id); else favs.splice(idx, 1);
        lsSet('noura_fav_restaurants', favs);
        return { ok: true, saved: willSave };
      }
      if (willSave) favs.push(id); else favs.splice(idx, 1);
      lsSet('noura_fav_restaurants', favs);
      const res = await apiRequest('/favorites', { method: willSave ? 'POST' : 'DELETE', body: { type: 'restaurant', refId: id } });
      return { ok: true, saved: willSave, reason: res.ok ? null : res.reason };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  SETTINGS SERVICE
   * ════════════════════════════════════════════════════════════ */
  const settingsService = {
    _defaults: () => ({ darkMode: true, pushNotifications: true, emailNotifications: true }),
    async _uid() {
      const sb = getSupabase(); if (!sb) return null;
      const { data } = await sb.auth.getSession();
      return data?.session?.user?.id || null;
    },
    async load() {
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        const { data, error } = await sb.from('user_settings').select('*').eq('user_id', uid).maybeSingle();
        if (!error) {
          const settings = data
            ? { darkMode: data.dark_mode, pushNotifications: data.push_notifications, emailNotifications: data.email_notifications }
            : this._defaults();
          lsSet('noura_settings', settings);
          return settings;
        }
      }
      const res = await apiRequest('/user/settings', { method: 'GET' });
      if (res.ok) { lsSet('noura_settings', res.data); return res.data; }
      return lsGet('noura_settings', this._defaults());
    },
    async update(patch) {
      const merged = { ...lsGet('noura_settings', this._defaults()), ...patch };
      const sb = getSupabase(); const uid = await this._uid();
      if (sb && uid) {
        await sb.from('user_settings').upsert({
          user_id: uid, dark_mode: merged.darkMode, push_notifications: merged.pushNotifications, email_notifications: merged.emailNotifications,
        });
        lsSet('noura_settings', merged);
        return { ok: true, settings: merged };
      }
      lsSet('noura_settings', merged);
      const res = await apiRequest('/user/settings', { method: 'PATCH', body: merged });
      return { ok: true, settings: merged, reason: res.ok ? null : res.reason };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR AUTH + PROFILE SERVICE
   * ════════════════════════════════════════════════════════════ */
  function mapVendorRow(row) {
    return {
      id: row.auth_user_id, dbId: row.id, businessName: row.business_name, ownerName: row.owner_name,
      email: row.email, category: row.category, initial: (row.business_name || '?').charAt(0).toUpperCase(),
      phone: row.phone, whatsapp: row.whatsapp, website: row.website, instagram: row.instagram, facebook: row.facebook,
      desc: row.description, country: row.country, state: row.state, city: row.city, address: row.address,
      emoji: row.emoji || '🍽️', priceRange: row.price_range, hours: row.hours, slug: row.slug,
      status: row.status, setupDone: row.setup_done, restaurantId: row.restaurant_id,
    };
  }

  const vendorService = {
    _get: () => lsGet('noura_vendor', null),
    _set: (v) => lsSet('noura_vendor', v),

    isLoggedIn() { return !!this._get(); },
    getVendor() { return this._get(); },

    async login(email, password) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.auth.signInWithPassword({ email, password });
        if (error) return { ok: false, reason: error.message || 'auth_error' };
        AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
        const { data: row, error: vErr } = await sb.from('vendors').select('*').eq('auth_user_id', data.user.id).maybeSingle();
        if (vErr || !row) return { ok: false, reason: 'not_a_vendor' };
        const vendor = mapVendorRow(row);
        this._set(vendor);
        return { ok: true, vendor };
      }
      const res = await apiRequest('/vendor/auth/login', { method: 'POST', body: { email, password } });
      if (res.ok) { AuthStore.setTokens(res.data.accessToken, res.data.refreshToken); this._set(res.data.vendor); return { ok: true, vendor: res.data.vendor }; }
      if (res.reason === 'no_backend') {
        const existing = this._get();
        if (existing && existing.email === email) return { ok: true, vendor: existing, reason: 'no_backend' };
        return { ok: false, reason: 'not_found' }; // never fabricate a vendor account
      }
      return { ok: false, reason: res.reason };
    },

    async register({ businessName, ownerName, email, password, category }) {
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.auth.signUp({ email, password, options: { data: { business_name: businessName, owner_name: ownerName } } });
        if (error) return { ok: false, reason: error.message || 'auth_error' };
        const slug = makeUniqueSlug(businessName);
        const vendorRow = {
          auth_user_id: data.user.id, business_name: businessName, owner_name: ownerName,
          email, category, slug, status: 'pending', setup_done: false,
        };
        if (data.session) {
          AuthStore.setTokens(data.session.access_token, data.session.refresh_token);
          const { data: inserted, error: insErr } = await sb.from('vendors').insert(vendorRow).select().single();
          if (insErr) return { ok: false, reason: insErr.message };
          const vendor = mapVendorRow(inserted);
          this._set(vendor);
          return { ok: true, vendor };
        }
        // Email confirmation required — the vendors row gets created on first login instead.
        return { ok: true, vendor: { businessName, ownerName, email, category, slug }, reason: 'confirm_email' };
      }
      const res = await apiRequest('/vendor/auth/register', { method: 'POST', body: { businessName, ownerName, email, password, category } });
      if (res.ok) { AuthStore.setTokens(res.data.accessToken, res.data.refreshToken); this._set(res.data.vendor); return { ok: true, vendor: res.data.vendor }; }
      const vendor = {
        id: uid(), businessName, ownerName, email, category,
        initial: (businessName || '?').charAt(0).toUpperCase(),
        slug: makeUniqueSlug(businessName),
        setupDone: false, status: 'pending', restaurantId: null,
      };
      this._set(vendor);
      return { ok: true, vendor, reason: 'no_backend' };
    },

    async forgotPassword(email) {
      const sb = getSupabase();
      if (sb) { const { error } = await sb.auth.resetPasswordForEmail(email); return { ok: !error, reason: error?.message }; }
      const res = await apiRequest('/vendor/auth/forgot-password', { method: 'POST', body: { email } });
      return { ok: res.ok || res.reason === 'no_backend' };
    },

    async logout() {
      const sb = getSupabase();
      if (sb) await sb.auth.signOut();
      else if (ENV.BACKEND_READY) await apiRequest('/vendor/auth/logout', { method: 'POST' });
      AuthStore.clearTokens();
    },

    async updateProfile(patch) {
      const sb = getSupabase();
      if (sb) {
        const { data: sess } = await sb.auth.getSession();
        const uid = sess?.session?.user?.id;
        if (!uid) return { ok: false };
        const dbPatch = {
          business_name: patch.businessName, owner_name: patch.ownerName, category: patch.category,
          phone: patch.phone, whatsapp: patch.whatsapp, website: patch.website, instagram: patch.instagram, facebook: patch.facebook,
          description: patch.desc, country: patch.country, state: patch.state, city: patch.city, address: patch.address,
          emoji: patch.emoji, price_range: patch.priceRange, hours: patch.hours, setup_done: patch.setupDone,
        };
        Object.keys(dbPatch).forEach((k) => dbPatch[k] === undefined && delete dbPatch[k]);
        const { data: updated, error } = await sb.from('vendors').update(dbPatch).eq('auth_user_id', uid).select().single();
        if (error) return { ok: false, reason: error.message };
        const vendor = mapVendorRow(updated);
        this._set(vendor);
        await vendorMenuService.publishToDirectory();
        return { ok: true, vendor };
      }
      const merged = { ...(this._get() || {}), ...patch };
      const res = await apiRequest('/vendor/profile', { method: 'PATCH', body: merged });
      this._set(merged);
      await vendorMenuService.publishToDirectory(); // keep the public listing in sync
      return { ok: true, vendor: merged, reason: res.ok ? null : res.reason };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR MENU SERVICE — also the bridge that publishes the
   *  vendor's profile + menu into the public restaurant directory
   *  (the same store restaurantService reads on the consumer app).
   * ════════════════════════════════════════════════════════════ */
  const vendorMenuService = {
    _key: () => 'noura_vendor_menu',

    /** Creates the restaurants row for this vendor if it doesn't exist yet,
     *  and keeps vendor.restaurantId in sync both locally and in the DB. */
    async _ensureRestaurant() {
      const sb = getSupabase(); if (!sb) return null;
      const v = vendorService.getVendor(); if (!v) return null;
      if (v.restaurantId) return v.restaurantId;
      const slug = v.slug || makeUniqueSlug(v.businessName);
      const { data, error } = await sb.from('restaurants').insert({
        vendor_id: v.dbId, slug, name: v.businessName, cuisine: v.category || '',
        area: v.city ? `${v.city}, ${v.state || ''}`.trim() : '', emoji: v.emoji || '🍽️',
        verified: v.status === 'approved', open: true, price_range: v.priceRange || '',
        tags: [v.category].filter(Boolean), phone: v.phone || '', whatsapp: v.whatsapp || '',
        website: v.website || '', hours: v.hours || '',
      }).select().single();
      if (error) return null;
      v.restaurantId = data.id; v.slug = data.slug; vendorService._set(v);
      await sb.from('vendors').update({ restaurant_id: data.id }).eq('auth_user_id', v.id);
      return data.id;
    },

    async list() {
      const sb = getSupabase(); const v = vendorService.getVendor();
      if (sb && v?.restaurantId) {
        const { data, error } = await sb.from('menu_items').select('*').eq('restaurant_id', v.restaurantId).order('created_at');
        if (!error) {
          const menu = (data || []).map((m) => ({ id: m.id, name: m.name, price: m.price, cat: m.category, desc: m.description, emoji: m.emoji, time: m.prep_time, available: m.available }));
          lsSet(this._key(), menu); return menu;
        }
      }
      const res = await apiRequest('/vendor/menu', { method: 'GET' });
      if (res.ok) { lsSet(this._key(), res.data); return res.data; }
      return lsGet(this._key(), []);
    },

    async save(item, idx = -1) {
      const sb = getSupabase();
      if (sb) {
        const restaurantId = await this._ensureRestaurant();
        if (restaurantId) {
          const dbItem = { restaurant_id: restaurantId, name: item.name, price: item.price, category: item.cat, description: item.desc, emoji: item.emoji, prep_time: item.time, available: item.available };
          if (idx >= 0) {
            const menu = await this.list();
            if (menu[idx]?.id) await sb.from('menu_items').update(dbItem).eq('id', menu[idx].id);
          } else {
            await sb.from('menu_items').insert(dbItem);
          }
          const menu = await this.list();
          return { ok: true, menu };
        }
      }
      const menu = await this.list();
      if (idx >= 0) menu[idx] = item; else menu.push(item);
      lsSet(this._key(), menu);
      await apiRequest('/vendor/menu', { method: 'POST', body: item });
      await this.publishToDirectory();
      return { ok: true, menu };
    },

    async remove(idx) {
      const sb = getSupabase();
      if (sb) {
        const menu = await this.list();
        if (menu[idx]?.id) { await sb.from('menu_items').delete().eq('id', menu[idx].id); return { ok: true, menu: await this.list() }; }
      }
      const menu = await this.list();
      menu.splice(idx, 1);
      lsSet(this._key(), menu);
      await this.publishToDirectory();
      return { ok: true, menu };
    },

    async toggleAvailable(idx) {
      const sb = getSupabase();
      if (sb) {
        const menu = await this.list();
        const item = menu[idx];
        if (item?.id) { await sb.from('menu_items').update({ available: !item.available }).eq('id', item.id); return { ok: true, menu: await this.list() }; }
      }
      const menu = await this.list();
      if (menu[idx]) menu[idx].available = !menu[idx].available;
      lsSet(this._key(), menu);
      await this.publishToDirectory();
      return { ok: true, menu };
    },

    /** Syncs the restaurant-level fields (name, contact info, etc.) to the
     *  public directory. With Supabase this is the restaurants row itself
     *  (menu items are managed as their own rows, not re-pushed here). */
    async publishToDirectory() {
      const v = vendorService.getVendor();
      if (!v || !v.setupDone) return;
      const sb = getSupabase();
      if (sb) {
        const restaurantId = await this._ensureRestaurant();
        if (restaurantId) {
          await sb.from('restaurants').update({
            name: v.businessName, cuisine: v.category || '', area: v.city ? `${v.city}, ${v.state || ''}`.trim() : '',
            emoji: v.emoji || '🍽️', verified: v.status === 'approved', price_range: v.priceRange || '',
            tags: [v.category].filter(Boolean), phone: v.phone || '', whatsapp: v.whatsapp || '',
            website: v.website || '', hours: v.hours || '',
          }).eq('id', restaurantId);
        }
        return;
      }
      // Local fallback — same shared-directory trick as before.
      const menu = await this.list();
      const restaurants = lsGet('noura_restaurants', []);
      const existingIdx = restaurants.findIndex((r) => r.id === v.restaurantId);
      const record = {
        id: v.restaurantId || uid(), slug: v.slug || makeUniqueSlug(v.businessName),
        name: v.businessName, cuisine: v.category || '', area: v.city ? `${v.city}, ${v.state || ''}`.trim() : '',
        emoji: v.emoji || '🍽️', rating: existingIdx >= 0 ? restaurants[existingIdx].rating : null,
        reviews: existingIdx >= 0 ? restaurants[existingIdx].reviews : 0,
        verified: v.status === 'approved', open: true, priceRange: v.priceRange || '',
        tags: [v.category].filter(Boolean), phone: v.phone || '', whatsapp: v.whatsapp || '',
        website: v.website || '', hours: v.hours || '', desc: v.desc || '',
        instagram: v.instagram || '', facebook: v.facebook || '', email: v.email || '',
        menu: menu.filter((m) => m.available !== false),
        reviews_data: existingIdx >= 0 ? restaurants[existingIdx].reviews_data || [] : [],
      };
      if (existingIdx >= 0) restaurants[existingIdx] = { ...restaurants[existingIdx], ...record };
      else restaurants.push(record);
      lsSet('noura_restaurants', restaurants);
      if (!v.restaurantId) { v.restaurantId = record.id; vendorService._set(v); }
      if (!v.slug) { v.slug = record.slug; vendorService._set(v); }
      await apiRequest('/restaurants', { method: 'POST', body: record }); // no-ops until backend exists
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR ORDER SERVICE — empty until a real order comes in.
   * ════════════════════════════════════════════════════════════ */
  const vendorOrderService = {
    async list() {
      const res = await apiRequest('/vendor/orders', { method: 'GET' });
      if (res.ok) { lsSet('noura_vendor_orders', res.data); return res.data; }
      return lsGet('noura_vendor_orders', []);
    },
    async updateStatus(orderId, status) {
      const orders = await this.list();
      const o = orders.find((x) => x.id === orderId);
      if (o) o.status = status;
      lsSet('noura_vendor_orders', orders);
      await apiRequest(`/vendor/orders/${orderId}`, { method: 'PATCH', body: { status } });
      return { ok: true, orders };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR PROMOTIONS SERVICE
   * ════════════════════════════════════════════════════════════ */
  const vendorPromoService = {
    async list() {
      const sb = getSupabase(); const v = vendorService.getVendor();
      if (sb && v?.restaurantId) {
        const { data, error } = await sb.from('promotions').select('*').eq('restaurant_id', v.restaurantId).order('created_at', { ascending: false });
        if (!error) {
          const promos = (data || []).map((p) => ({ id: p.id, type: p.type, val: p.value, desc: p.description, exp: p.expires_on }));
          lsSet('noura_vendor_promos', promos);
          return promos;
        }
      }
      const res = await apiRequest('/vendor/promotions', { method: 'GET' });
      if (res.ok) { lsSet('noura_vendor_promos', res.data); return res.data; }
      return lsGet('noura_vendor_promos', []);
    },
    async create(promo) {
      const sb = getSupabase();
      const restaurantId = sb ? await vendorMenuService._ensureRestaurant() : null;
      if (sb && restaurantId) {
        const { error } = await sb.from('promotions').insert({
          restaurant_id: restaurantId, type: promo.type, value: promo.val, description: promo.desc, expires_on: promo.exp || null,
        });
        if (!error) return { ok: true, promos: await this.list() };
      }
      const promos = await this.list(); promos.push({ id: uid(), ...promo });
      lsSet('noura_vendor_promos', promos);
      await apiRequest('/vendor/promotions', { method: 'POST', body: promo });
      return { ok: true, promos };
    },
    async remove(idx) {
      const sb = getSupabase();
      const promos = await this.list();
      const target = promos[idx];
      if (sb && target?.id) {
        await sb.from('promotions').delete().eq('id', target.id);
        return { ok: true, promos: await this.list() };
      }
      promos.splice(idx, 1);
      lsSet('noura_vendor_promos', promos);
      return { ok: true, promos };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR REVIEWS SERVICE — reads the real reviews already
   *  attached to this vendor's published restaurant record.
   * ════════════════════════════════════════════════════════════ */
  const vendorReviewService = {
    async list() {
      const v = vendorService.getVendor(); if (!v?.restaurantId) return [];
      const sb = getSupabase();
      if (sb) {
        const { data, error } = await sb.from('reviews').select('*').eq('restaurant_id', v.restaurantId).order('created_at', { ascending: false });
        if (!error) return (data || []).map((r) => ({ id: r.id, author: r.author, stars: r.stars, text: r.text, date: r.created_at ? new Date(r.created_at).toLocaleDateString() : '', reply: r.reply, replied: r.replied }));
      }
      const r = lsGet('noura_restaurants', []).find((x) => x.id === v.restaurantId);
      return r?.reviews_data || [];
    },
    async reply(reviewIndex, replyText) {
      const v = vendorService.getVendor(); if (!v?.restaurantId) return { ok: false };
      const sb = getSupabase();
      if (sb) {
        const reviews = await this.list();
        const review = reviews[reviewIndex];
        if (review?.id) { await sb.from('reviews').update({ reply: replyText, replied: true }).eq('id', review.id); return { ok: true }; }
      }
      const restaurants = lsGet('noura_restaurants', []);
      const r = restaurants.find((x) => x.id === v.restaurantId);
      if (r?.reviews_data?.[reviewIndex]) { r.reviews_data[reviewIndex].replied = true; r.reviews_data[reviewIndex].reply = replyText; }
      lsSet('noura_restaurants', restaurants);
      await apiRequest(`/vendor/reviews/${reviewIndex}/reply`, { method: 'POST', body: { reply: replyText } });
      return { ok: true };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  VENDOR ANALYTICS SERVICE — real, locally-derivable numbers
   *  only (menu size, review average, order counts). Profile
   *  views / impressions genuinely require backend tracking, so
   *  those stay at 0 with a "connect backend to track this" note
   *  instead of a random placeholder number.
   * ════════════════════════════════════════════════════════════ */
  const vendorAnalyticsService = {
    async summary() {
      const res = await apiRequest('/vendor/analytics/summary', { method: 'GET' });
      if (res.ok) return { ...res.data, live: true };
      const menu = await vendorMenuService.list();
      const orders = await vendorOrderService.list();
      const reviews = await vendorReviewService.list();
      const avgRating = reviews.length ? (reviews.reduce((a, r) => a + r.stars, 0) / reviews.length).toFixed(1) : null;
      return {
        live: false, views: null, favourites: null, // requires backend tracking — not fabricated
        menuItems: menu.length, totalOrders: orders.length,
        pendingOrders: orders.filter((o) => !['Completed', 'Cancelled'].includes(o.status)).length,
        avgRating, reviewCount: reviews.length,
      };
    },
    /** Weekly order volume / revenue growth need real historical order
     *  timestamps from a backend — return null (not fake trend lines)
     *  until that data source exists. */
    async trends() {
      const res = await apiRequest('/vendor/analytics/trends', { method: 'GET' });
      if (res.ok) return { ...res.data, live: true };
      return { live: false, weekly: null, popularItems: null, growth: null };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  MEDIA SERVICE — real photo uploads via Supabase Storage.
   *  Falls back to an honest "needs backend" response when no
   *  Supabase project is linked, instead of pretending to upload.
   * ════════════════════════════════════════════════════════════ */
  const mediaService = {
    canUpload: () => !!getSupabase(),
    async uploadMealPhoto(file, caption) {
      const sb = getSupabase();
      if (!sb) return { ok: false, reason: 'no_backend' };
      const { data: sess } = await sb.auth.getSession();
      const uid = sess?.session?.user?.id;
      if (!uid) return { ok: false, reason: 'not_logged_in' };
      const path = `${uid}/${Date.now()}_${file.name.replace(/[^a-zA-Z0-9._-]/g, '')}`;
      const { error: upErr } = await sb.storage.from('meal-photos').upload(path, file);
      if (upErr) return { ok: false, reason: upErr.message };
      const { data: pub } = sb.storage.from('meal-photos').getPublicUrl(path);
      const { error: insErr } = await sb.from('meal_photos').insert({ user_id: uid, photo_url: pub.publicUrl, caption: caption || '' });
      if (insErr) return { ok: false, reason: insErr.message };
      return { ok: true, url: pub.publicUrl };
    },
    async myPhotoCount() {
      const sb = getSupabase();
      if (!sb) return 0;
      const { data: sess } = await sb.auth.getSession();
      const uid = sess?.session?.user?.id;
      if (!uid) return 0;
      const { count } = await sb.from('meal_photos').select('id', { count: 'exact', head: true }).eq('user_id', uid);
      return count || 0;
    },

    /** Vendor logo/cover upload — real Storage, saved straight onto
     *  the restaurant record so it shows up on the storefront immediately. */
    async uploadVendorPhoto(file, kind) {
      const sb = getSupabase();
      if (!sb) return { ok: false, reason: 'no_backend' };
      const { data: sess } = await sb.auth.getSession();
      const uid = sess?.session?.user?.id;
      if (!uid) return { ok: false, reason: 'not_logged_in' };
      const restaurantId = await vendorMenuService._ensureRestaurant();
      if (!restaurantId) return { ok: false, reason: 'no_restaurant_yet' };
      const path = `${uid}/${kind}_${Date.now()}_${file.name.replace(/[^a-zA-Z0-9._-]/g, '')}`;
      const { error: upErr } = await sb.storage.from('vendor-photos').upload(path, file, { upsert: true });
      if (upErr) return { ok: false, reason: upErr.message };
      const { data: pub } = sb.storage.from('vendor-photos').getPublicUrl(path);
      const column = kind === 'logo' ? 'logo_url' : 'cover_url';
      const { error: updErr } = await sb.from('restaurants').update({ [column]: pub.publicUrl }).eq('id', restaurantId);
      if (updErr) return { ok: false, reason: updErr.message };
      return { ok: true, url: pub.publicUrl };
    },

    /** Consumer profile photo — same bucket (already public-read,
     *  authenticated-write), just a different path prefix. */
    async uploadProfilePhoto(file) {
      const sb = getSupabase();
      if (!sb) return { ok: false, reason: 'no_backend' };
      const { data: sess } = await sb.auth.getSession();
      const uid = sess?.session?.user?.id;
      if (!uid) return { ok: false, reason: 'not_logged_in' };
      const path = `profile/${uid}/${Date.now()}_${file.name.replace(/[^a-zA-Z0-9._-]/g, '')}`;
      const { error: upErr } = await sb.storage.from('vendor-photos').upload(path, file, { upsert: true });
      if (upErr) return { ok: false, reason: upErr.message };
      const { data: pub } = sb.storage.from('vendor-photos').getPublicUrl(path);
      const { error: updErr } = await sb.from('profiles').update({ avatar_url: pub.publicUrl }).eq('id', uid);
      if (updErr) return { ok: false, reason: updErr.message };
      return { ok: true, url: pub.publicUrl };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  WAITLIST SERVICE  (landing page)
   * ════════════════════════════════════════════════════════════ */
  const waitlistService = {
    async getCount() {
      const res = await apiRequest('/waitlist/count', { method: 'GET' });
      if (res.ok) return res.data.count;
      return lsGet('noura_wl_count', 0);
    },
    async join({ name, email, country, feature }) {
      const res = await apiRequest('/waitlist', { method: 'POST', body: { name, email, country, feature } });
      if (!res.ok && res.reason !== 'no_backend') return { ok: false, reason: res.reason };
      // Local fallback so the counter still feels alive before a backend exists.
      const entries = lsGet('noura_waitlist', []);
      entries.push({ name, email, country, feature, joined: new Date().toISOString() });
      lsSet('noura_waitlist', entries);
      const count = (await this.getCount()) + 1;
      lsSet('noura_wl_count', count);
      return { ok: true, count, reason: res.ok ? null : 'no_backend' };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  ADVERTISING SERVICE
   *  Real CRUD from Admin, real serving logic on the consumer/
   *  vendor apps. Status is computed from dates + a pause flag,
   *  never hardcoded. Placements: home_banner, feed_card,
   *  search_results, restaurant_page, popup, slide_in.
   * ════════════════════════════════════════════════════════════ */
  const adsService = {
    _key: 'noura_ads',
    _computeStatus(ad) {
      if (ad.paused) return 'Paused';
      const today = new Date().toISOString().slice(0, 10);
      if (ad.startDate && today < ad.startDate) return 'Scheduled';
      if (ad.endDate && today > ad.endDate) return 'Expired';
      return 'Running';
    },
    async list() {
      const res = await apiRequest('/admin/ads', { method: 'GET' });
      const raw = res.ok ? res.data : lsGet(this._key, []);
      if (res.ok) lsSet(this._key, raw);
      return raw.map((ad) => ({ ...ad, status: this._computeStatus(ad) }));
    },
    async create(ad) {
      const ads = lsGet(this._key, []);
      const entry = { id: uid(), impressions: 0, clicks: 0, paused: false, createdAt: new Date().toISOString(), ...ad };
      ads.push(entry);
      lsSet(this._key, ads);
      await apiRequest('/admin/ads', { method: 'POST', body: entry });
      return { ok: true, ad: entry };
    },
    async update(id, patch) {
      const ads = lsGet(this._key, []);
      const ad = ads.find((a) => a.id === id);
      if (ad) Object.assign(ad, patch);
      lsSet(this._key, ads);
      await apiRequest(`/admin/ads/${id}`, { method: 'PATCH', body: patch });
      return { ok: true };
    },
    async remove(id) {
      lsSet(this._key, lsGet(this._key, []).filter((a) => a.id !== id));
      await apiRequest(`/admin/ads/${id}`, { method: 'DELETE' });
      return { ok: true };
    },
    async togglePause(id) {
      const ads = lsGet(this._key, []);
      const ad = ads.find((a) => a.id === id);
      if (ad) ad.paused = !ad.paused;
      lsSet(this._key, ads);
      return { ok: true, paused: ad?.paused };
    },
    /** What the consumer/vendor app actually calls to serve an ad. */
    async getActiveForPlacement(placement, viewerType = 'user') {
      const all = await this.list();
      return all.filter((ad) =>
        ad.status === 'Running' &&
        ad.placement === placement &&
        (ad.audience === 'everyone' || ad.audience === viewerType + 's' || ad.audience === viewerType)
      );
    },
    async recordImpression(id) {
      const ads = lsGet(this._key, []);
      const ad = ads.find((a) => a.id === id);
      if (ad) ad.impressions = (ad.impressions || 0) + 1;
      lsSet(this._key, ads);
    },
    async recordClick(id) {
      const ads = lsGet(this._key, []);
      const ad = ads.find((a) => a.id === id);
      if (ad) ad.clicks = (ad.clicks || 0) + 1;
      lsSet(this._key, ads);
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  CHALLENGES SERVICE
   *  Real, locally-tracked progress against actual user actions
   *  (reviews written, restaurants explored, streak days, meals
   *  opened). Community-wide leaderboards need a backend to
   *  compare across users — labeled honestly where relevant.
   * ════════════════════════════════════════════════════════════ */
  const challengesAdminService = {
    async _call(action, payload) {
      const res = await fetch(`${ENV.SUPABASE_URL}/functions/v1/admin-challenges`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-key': ENV.ADMIN_API_KEY },
        body: JSON.stringify({ action, payload }),
      }).catch(() => null);
      if (!res) return { ok: false, error: 'network' };
      return res.json();
    },
    list() { return this._call('list'); },
    create(challenge) { return this._call('create', challenge); },
    remove(id) { return this._call('delete', { id }); },
    toggle(id, active) { return this._call('toggle', { id, active }); },
  };

  const CHALLENGE_DEFS = [
    { id: 'cook-weekend',  icon: '🍳', title: 'Cook This Weekend',     desc: 'Open and view 1 recipe this week.',            metric: 'mealsOpened',       target: 1 },
    { id: 'rate-5',        icon: '⭐', title: 'Rate 5 Restaurants',     desc: 'Leave 5 real restaurant reviews.',             metric: 'reviewsWritten',    target: 5 },
    { id: 'campus-hunt',   icon: '🗺️', title: 'Campus Food Hunt',       desc: 'Explore 3 different restaurants on Noura.',    metric: 'restaurantsViewed', target: 3 },
    { id: 'healthy-week',  icon: '🥗', title: 'Healthy Week',           desc: 'Keep a 7-day login streak.',                   metric: 'streakDays',        target: 7 },
    { id: 'street-food',   icon: '🌮', title: 'Street Food Challenge',  desc: 'Open 3 different recipes.',                    metric: 'mealsOpened',       target: 3 },
    { id: 'upload-meal',   icon: '📸', title: 'Upload Your Best Meal',  desc: 'Share a real photo of a meal you made or ordered.', metric: 'manual', target: 1 },
  ];
  const BADGE_LABELS = { 'cook-weekend':'🍳 Home Cook', 'rate-5':'⭐ Top Reviewer', 'campus-hunt':'🗺️ Explorer', 'healthy-week':'🥗 Healthy Streak', 'street-food':'🌮 Street Food Fan', 'upload-meal':'📸 Foodie Photographer' };

  const challengesService = {
    async list() {
      const sb = getSupabase();
      if (sb) {
        const today = new Date().toISOString().slice(0, 10);
        const { data, error } = await sb.from('challenges').select('*')
          .eq('active', true).lte('start_date', today)
          .or(`end_date.is.null,end_date.gte.${today}`);
        if (!error && data && data.length) {
          return data.map((c) => ({ id: c.id, icon: c.icon || '🏆', title: c.title, desc: c.description || '', metric: c.metric, target: c.target }));
        }
      }
      return CHALLENGE_DEFS;
    },
    _joined() { return lsGet('noura_challenges_joined', []); },
    _badges() { return lsGet('noura_badges', []); },
    isJoined(id) { return this._joined().includes(id); },
    join(id) {
      const joined = this._joined();
      if (!joined.includes(id)) { joined.push(id); lsSet('noura_challenges_joined', joined); }
    },
    leave(id) { lsSet('noura_challenges_joined', this._joined().filter((x) => x !== id)); },
    incrementReviewsWritten() { lsSet('noura_reviews_written', (lsGet('noura_reviews_written', 0)) + 1); },
    recordRestaurantViewed(id) {
      const seen = new Set(lsGet('noura_restaurants_viewed', []));
      seen.add(id); lsSet('noura_restaurants_viewed', [...seen]);
    },
    markManualDone(id) {
      const manual = lsGet('noura_challenges_manual', []);
      if (!manual.includes(id)) { manual.push(id); lsSet('noura_challenges_manual', manual); }
    },
    getProgress(def, streakDaysFn) {
      let current = 0;
      if (def.metric === 'mealsOpened')       current = lsGet('nMealsOpened', 0);
      else if (def.metric === 'reviewsWritten')    current = lsGet('noura_reviews_written', 0);
      else if (def.metric === 'restaurantsViewed') current = lsGet('noura_restaurants_viewed', []).length;
      else if (def.metric === 'streakDays')        current = streakDaysFn ? streakDaysFn() : 0;
      else if (def.metric === 'manual')            current = lsGet('noura_challenges_manual', []).includes(def.id) ? 1 : 0;
      const done = current >= def.target;
      if (done && !this._badges().includes(def.id)) {
        const badges = this._badges(); badges.push(def.id); lsSet('noura_badges', badges);
      }
      return { current: Math.min(current, def.target), target: def.target, done };
    },
    getMyBadges() { return this._badges().map((id) => BADGE_LABELS[id]).filter(Boolean); },
  };

  /* ════════════════════════════════════════════════════════════
   *  AUDIT LOG SERVICE  — records every real admin action taken
   *  on this device. Platform-wide audit trails (across every
   *  admin, every device) need a backend to centralize; this is
   *  the honest local-first version of that.
   * ════════════════════════════════════════════════════════════ */
  const auditLogService = {
    log(action, details) {
      const entries = lsGet('noura_audit_log', []);
      entries.unshift({ action, details, admin: 'admin@noura.app', time: new Date().toISOString() });
      lsSet('noura_audit_log', entries.slice(0, 500));
    },
    list() { return lsGet('noura_audit_log', []); },
    clear() { lsSet('noura_audit_log', []); },
  };

  /* ════════════════════════════════════════════════════════════
   *  PLATFORM SERVICE — maintenance mode + feature toggles.
   *  Local-first, but genuinely wired: the consumer app actually
   *  checks this flag on load and shows a maintenance screen.
   * ════════════════════════════════════════════════════════════ */
  const platformService = {
    isMaintenanceMode() { return lsGet('noura_maintenance_mode', false); },
    setMaintenanceMode(on) { lsSet('noura_maintenance_mode', !!on); },
    getFeatureFlags() { return lsGet('noura_feature_flags', { aiChat: true, restaurantDiscovery: true, mealPlanner: true, waitlist: true }); },
    setFeatureFlag(key, val) { const f = this.getFeatureFlags(); f[key] = val; lsSet('noura_feature_flags', f); },
  };

  const adminActionsService = {
    async _call(action, payload) {
      if (!ENV.SUPABASE_URL) return { ok: false, error: 'no_backend' };
      const res = await fetch(`${ENV.SUPABASE_URL}/functions/v1/admin-actions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-key': ENV.ADMIN_API_KEY },
        body: JSON.stringify({ action, payload }),
      }).catch(() => null);
      if (!res) return { ok: false, error: 'network' };
      return res.json();
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  ADMIN SERVICE
   *  Users and reports genuinely need a backend (each person's
   *  data lives in their own browser locally) — those start
   *  empty. Vendors and reviews are derived from the one real
   *  shared store both apps already write to: noura_restaurants.
   * ════════════════════════════════════════════════════════════ */
  const adminService = {
    async login(email, password) {
      const res = await apiRequest('/admin/auth/login', { method: 'POST', body: { email, password } });
      if (res.ok) { AuthStore.setTokens(res.data.accessToken, res.data.refreshToken); return { ok: true, demo: false }; }
      return { ok: true, demo: true }; // local demo mode — no backend connected yet
    },

    async listUsers() {
      const real = await adminActionsService._call('listUsers');
      if (real.ok) return real.data;
      const res = await apiRequest('/admin/users', { method: 'GET' });
      if (res.ok) return res.data;
      return []; // no cross-device user directory exists without a backend
    },
    async setUserStatus(id, status) {
      const real = await adminActionsService._call('setUserStatus', { userId: id, status });
      if (real.ok) return { ok: true };
      const res = await apiRequest(`/admin/users/${id}/status`, { method: 'PATCH', body: { status } });
      return { ok: res.ok || res.reason === 'no_backend' };
    },

    async listVendors() {
      const res = await apiRequest('/admin/vendors', { method: 'GET' });
      if (res.ok) return res.data;
      // Local fallback: every published restaurant IS a vendor listing.
      const { restaurants } = await restaurantService.list();
      return restaurants.map((r) => ({
        id: r.id, businessName: r.name, owner: r.owner || '—', category: r.cuisine || '—',
        menuItems: (r.menu || []).length, rating: r.rating || 0,
        status: r.suspended ? 'suspended' : r.verified ? 'approved' : 'pending',
      }));
    },
    async setVendorStatus(id, status) {
      const real = await adminActionsService._call('setVendorStatus', { restaurantId: id, status });
      const restaurants = lsGet('noura_restaurants', []);
      const r = restaurants.find((x) => x.id === id);
      if (r) { r.verified = status === 'approved'; r.suspended = status === 'suspended'; lsSet('noura_restaurants', restaurants); }
      return { ok: real.ok, reason: real.ok ? null : real.error };
    },
    async featureVendor(id) {
      const real = await adminActionsService._call('featureVendor', { restaurantId: id });
      return { ok: real.ok, reason: real.ok ? null : real.error };
    },

    /** Real menu items aggregated across every published restaurant. */
    async listAllMeals() {
      const { restaurants } = await restaurantService.list();
      return restaurants.flatMap((r) => (r.menu || []).map((m, i) => ({ ...m, restaurant: r.name, restaurantId: r.id, index: i })));
    },
    async removeMeal(restaurantId, itemId) {
      const real = await adminActionsService._call('removeMeal', { itemId });
      if (real.ok) return { ok: true };
      const restaurants = lsGet('noura_restaurants', []);
      const r = restaurants.find((x) => x.id === restaurantId);
      if (r?.menu) { const idx = r.menu.findIndex((m) => m.id === itemId); if (idx >= 0) r.menu.splice(idx, 1); }
      lsSet('noura_restaurants', restaurants);
      return { ok: true, reason: real.error };
    },

    async listReports() {
      const res = await apiRequest('/admin/reports', { method: 'GET' });
      if (res.ok) return res.data;
      return []; // no fabricated abuse reports
    },
    async resolveReport(id) {
      const real = await adminActionsService._call('resolveReport', { reportId: id });
      return { ok: real.ok, reason: real.ok ? null : real.error };
    },

    /** Real reviews aggregated across every published restaurant. */
    async listAllReviews() {
      const res = await apiRequest('/admin/reviews', { method: 'GET' });
      if (res.ok) return res.data;
      const { restaurants } = await restaurantService.list();
      return restaurants.flatMap((r) => (r.reviews_data || []).map((rv, i) => ({ ...rv, restaurant: r.name, restaurantId: r.id, index: i })));
    },
    async removeReview(restaurantId, reviewId) {
      const real = await adminActionsService._call('removeReview', { reviewId });
      if (real.ok) return { ok: true };
      const restaurants = lsGet('noura_restaurants', []);
      const r = restaurants.find((x) => x.id === restaurantId);
      if (r?.reviews_data) { const idx = r.reviews_data.findIndex((rv) => rv.id === reviewId); if (idx >= 0) { r.reviews_data.splice(idx, 1); r.reviews = r.reviews_data.length; } }
      lsSet('noura_restaurants', restaurants);
      return { ok: true, reason: real.error };
    },
    async removeRestaurant(id) {
      const real = await adminActionsService._call('removeRestaurant', { restaurantId: id });
      lsSet('noura_restaurants', lsGet('noura_restaurants', []).filter((r) => r.id !== id));
      return { ok: real.ok, reason: real.ok ? null : real.error };
    },

    async listNotifications() {
      const res = await apiRequest('/admin/notifications', { method: 'GET' });
      if (res.ok) return res.data;
      return lsGet('noura_admin_notifs', []);
    },
    /** audience: {type:'everyone'|'vendors'|'users'|'country'|'cuisine', value?} */
    async broadcastNotification({ title, message, audience }) {
      const audienceLabel = audience.type === 'everyone' ? 'Everyone'
        : audience.type === 'vendors' ? 'Vendors only'
        : audience.type === 'users' ? 'Users only'
        : audience.type === 'country' ? `Users in ${audience.value}`
        : audience.type === 'cuisine' ? `Fans of ${audience.value}`
        : 'Everyone';
      const real = await adminActionsService._call('createBroadcast', { title, message, audienceType: audience.type, audienceValue: audience.value });
      // Local sent-log is just for the admin's own "Sent Notifications" view — not the delivery mechanism.
      const entry = { id: real.data?.id || uid(), title, message, audience, audienceLabel, date: 'Just now', createdAt: new Date().toISOString() };
      const sent = lsGet('noura_admin_notifs', []); sent.unshift(entry); lsSet('noura_admin_notifs', sent);
      return { ok: real.ok, reason: real.ok ? null : real.error, audienceLabel };
    },

    /** Called by the consumer app on load — delivers any broadcasts
     *  targeted at this user into their real notification inbox. */
    async pullBroadcastsForUser(user, prefs) {
      const sb = getSupabase();
      const uidVal = user?.id;
      if (!sb) return;
      const { data: broadcasts, error } = await sb.from('broadcasts').select('*').order('created_at', { ascending: false }).limit(50);
      if (error || !broadcasts?.length) return;
      const seen = new Set(lsGet('noura_broadcasts_seen_user', []));
      const matches = broadcasts.filter((b) => !seen.has(b.id) && (
        b.audience_type === 'everyone' || b.audience_type === 'users' ||
        (b.audience_type === 'country' && user?.country === b.audience_value) ||
        (b.audience_type === 'cuisine' && (prefs?.favFoods || []).includes(b.audience_value))
      ));
      if (!matches.length) { lsSet('noura_broadcasts_seen_user', [...seen, ...broadcasts.map((b) => b.id)]); return; }
      if (uidVal) {
        await sb.from('notifications').insert(matches.map((b) => ({
          user_id: uidVal, type: 'announcement', icon: '📢', color: '#E8943A22', title: b.title, message: b.message, unread: true,
        })));
      }
      lsSet('noura_broadcasts_seen_user', [...seen, ...broadcasts.map((b) => b.id)]);
    },
    /** Same idea, for the vendor portal — vendors get real notification
     *  rows too, keyed by their own auth uid (same notifications table). */
    async pullBroadcastsForVendor() {
      const sb = getSupabase();
      if (!sb) return;
      const { data: sess } = await sb.auth.getSession();
      const vendorUid = sess?.session?.user?.id;
      const { data: broadcasts, error } = await sb.from('broadcasts').select('*').order('created_at', { ascending: false }).limit(50);
      if (error || !broadcasts?.length) return;
      const seen = new Set(lsGet('noura_broadcasts_seen_vendor', []));
      const matches = broadcasts.filter((b) => !seen.has(b.id) && (b.audience_type === 'everyone' || b.audience_type === 'vendors'));
      if (matches.length && vendorUid) {
        await sb.from('notifications').insert(matches.map((b) => ({
          user_id: vendorUid, type: 'announcement', icon: '📢', color: '#E8943A22', title: b.title, message: b.message, unread: true,
        })));
      }
      lsSet('noura_broadcasts_seen_vendor', [...seen, ...broadcasts.map((b) => b.id)]);
    },

    /** Platform-wide analytics need a backend to aggregate across
     *  users/devices. Locally we can only report what actually
     *  exists in the shared restaurant directory on this device. */
    async summary() {
      const res = await apiRequest('/admin/analytics/summary', { method: 'GET' });
      if (res.ok) return { ...res.data, live: true };
      const vendors = await this.listVendors();
      const reviews = await this.listAllReviews();
      return {
        live: false, totalUsers: null, dau: null, // needs backend
        totalVendors: vendors.length, approvedVendors: vendors.filter((v) => v.status === 'approved').length,
        totalReviews: reviews.length,
      };
    },
    async trends() {
      const res = await apiRequest('/admin/analytics/trends', { method: 'GET' });
      if (res.ok) return { ...res.data, live: true };
      return { live: false, dau: null, searchTerms: null, geo: null, aiUsage: null };
    },
  };

  /* ════════════════════════════════════════════════════════════
   *  AI SERVICE  (Noura AI chat + ingredient-based recipe finder)
   * ════════════════════════════════════════════════════════════ */
  const GEMINI_SYSTEM = `You are Noura AI, an expert food companion for the Noura app — an African and global food discovery platform. You are a genuine food expert, not a generic chatbot. You can:
- Recommend meals and dishes based on mood, budget, or occasion
- Generate full recipes from ingredients or a dish name
- Modify recipes for diets (vegan, spicy, low-carb, gluten-free, halal, etc.)
- Suggest specific restaurants FROM THE "REAL NOURA VENDORS" LIST below when relevant — never invent a restaurant that isn't in that list
- Explain nutrition facts and answer cooking/technique questions
- Suggest groceries or ingredient substitutions
- Help someone decide what to eat when they're unsure
Be concise (max 4-6 lines unless a full recipe is requested), warm, and practical. Use emojis naturally. Bold key items with **text**. Currency: ₦ for Nigeria. If asked about restaurants and none are in the list below, say Noura doesn't have vendors in that area yet rather than inventing one.`;

  async function buildLocalContext() {
    try {
      const { restaurants } = await restaurantService.list();
      if (!restaurants.length) return '';
      const sample = restaurants.slice(0, 15).map(r => `${r.name} (${r.cuisine || 'food'}, ${r.area || 'location unknown'}, ${r.open ? 'open' : 'closed'})`).join('; ');
      return `\n\nREAL NOURA VENDORS (only reference these by name, never invent others): ${sample}`;
    } catch { return ''; }
  }

  const aiService = {
    _history: [],
    isConfigured: () => !!(ENV.GEMINI_API_KEY && ENV.GEMINI_API_KEY !== 'YOUR_GEMINI_KEY_HERE'),
    /** True once a Supabase project is linked — chat then routes through
     *  the gemini-chat Edge Function so the Gemini key never reaches the
     *  browser, instead of calling Google directly with a client-side key. */
    hasSecureProxy: () => !!(ENV.SUPABASE_URL && ENV.SUPABASE_ANON_KEY),

    /** @returns {Promise<AIResponse>} */
    async chat(message) {
      if (!this.isConfigured() && !this.hasSecureProxy()) {
        return { ok: false, error: 'not_configured', text: '🔑 AI chat isn\'t connected yet — add a Gemini key in config.js.' };
      }
      this._history.push({ role: 'user', parts: [{ text: message }] });
      const localContext = await buildLocalContext();
      const startedAt = Date.now();

      try {
        let reply;
        if (this.hasSecureProxy()) {
          // Secure path: Gemini key lives only in Supabase secrets.
          // Send the user's real session token (if logged in) so the
          // function can apply per-account rate limits; anon key otherwise.
          const sb = getSupabase();
          let authToken = ENV.SUPABASE_ANON_KEY;
          if (sb) { const { data: sess } = await sb.auth.getSession(); if (sess?.session?.access_token) authToken = sess.session.access_token; }

          const res = await fetch(`${ENV.SUPABASE_URL}/functions/v1/gemini-chat`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${authToken}` },
            body: JSON.stringify({ history: this._history.slice(-20), systemPrompt: GEMINI_SYSTEM + localContext }),
            signal: AbortSignal.timeout(12000),
          });
          const data = await res.json().catch(() => null);
          if (res.status === 429 && data?.text) {
            // Rate limited — this is an expected, user-facing state, not a network failure.
            this._history.pop();
            return { ok: false, error: 'rate_limited', text: data.text };
          }
          if (!res.ok || !data?.ok) throw new Error(data?.error || 'HTTP ' + res.status);
          reply = data.text;
        } else {
          // Fallback: direct call, only used if no Supabase project is linked yet.
          const url = `https://generativelanguage.googleapis.com/v1beta/models/${ENV.GEMINI_MODEL || 'gemini-flash-latest'}:generateContent?key=${ENV.GEMINI_API_KEY}`;
          const body = { system_instruction: { parts: [{ text: GEMINI_SYSTEM + localContext }] }, contents: this._history.slice(-20), generationConfig: { temperature: 0.85, maxOutputTokens: 1400 } };
          const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: AbortSignal.timeout(12000) });
          if (!res.ok) throw new Error('HTTP ' + res.status);
          const data = await res.json();
          reply = data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sorry, try again!';
        }
        this._history.push({ role: 'model', parts: [{ text: reply }] });
        this._recordStat(true, Date.now() - startedAt);
        return { ok: true, text: reply };
      } catch (err) {
        this._history.pop();
        this._recordStat(false, Date.now() - startedAt, String(err?.message || err));
        return { ok: false, error: 'network', text: '😔 Connection issue — check your internet and try again.' };
      }
    },

    /** Local per-device usage stats — see adminAnalytics note on why these
     *  aren't platform-wide without a backend to aggregate them. */
    _recordStat(success, ms, errorMsg) {
      const stats = lsGet('noura_ai_stats', { requests: [] });
      stats.requests.push({ success, ms, error: errorMsg || null, at: new Date().toISOString() });
      stats.requests = stats.requests.slice(-200);
      lsSet('noura_ai_stats', stats);
    },
    getStats() {
      const stats = lsGet('noura_ai_stats', { requests: [] });
      const today = new Date().toDateString();
      const todayReqs = stats.requests.filter((r) => new Date(r.at).toDateString() === today);
      const okReqs = stats.requests.filter((r) => r.success && r.ms);
      const avgMs = okReqs.length ? Math.round(okReqs.reduce((a, r) => a + r.ms, 0) / okReqs.length) : null;
      const errors = stats.requests.filter((r) => !r.success).slice(-10).reverse();
      return { today: todayReqs.length, total: stats.requests.length, avgMs, errors };
    },
    async checkHealth() {
      if (!this.isConfigured()) return { ok: false, status: 'not_configured' };
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${ENV.GEMINI_MODEL || 'gemini-flash-latest'}?key=${ENV.GEMINI_API_KEY}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
        return { ok: res.ok, status: res.ok ? 'healthy' : 'error' };
      } catch { return { ok: false, status: 'unreachable' }; }
    },

    /** Finds a real recipe matching the first listed ingredient (via recipeService). */
    async recipeFromIngredients(ingredientsText) {
      const first = (ingredientsText || '').trim().split(/[,\s]+/)[0];
      if (!first) return { ok: false, recipe: null };
      const data = await recipeService.mealDb.search(first);
      const meal = data?.meals?.[0] || null;
      return { ok: !!meal, recipe: meal };
    },

    resetHistory() { this._history = []; },
  };

  /* ════════════════════════════════════════════════════════════
   *  PUBLIC EXPORT
   * ════════════════════════════════════════════════════════════ */
  window.Services = {
    env: ENV,
    auth: authService,
    profile: userProfileService,
    restaurants: restaurantService,
    recipes: recipeService,
    mealPlan: mealPlanService,
    notifications: notificationService,
    favourites: favouritesService,
    settings: settingsService,
    ai: aiService,
    vendor: vendorService,
    vendorMenu: vendorMenuService,
    vendorOrders: vendorOrderService,
    vendorPromos: vendorPromoService,
    vendorReviews: vendorReviewService,
    vendorAnalytics: vendorAnalyticsService,
    admin: adminService,
    ads: adsService,
    challenges: challengesService,
    challengesAdmin: challengesAdminService,
    media: mediaService,
    auditLog: auditLogService,
    platform: platformService,
    waitlist: waitlistService,
    // small shared utils screens are allowed to use directly
    utils: { lsGet, lsSet, lsDel, uid },
  };
})();
