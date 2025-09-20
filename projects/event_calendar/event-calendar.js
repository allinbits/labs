/*
  <event-calendar> — Web Component
  --------------------------------
  Expects the short, schema-ish JSON format we used above (plain JSON, not strict JSON-LD):

  Event (minimal):
  {
    "@type": "Event",
    "name": "Office Hours — Week 2",
    "description": "",
    "eventStatus": "EventScheduled", // plain string okay
    "startDate": "2025-10-08T10:00:00Z",
    "endDate":   "2025-10-08T11:00:00Z",
    "location": "…" | {…},
    "organizer": {…},
    "schedule": { "@id": "…" } // optional link to schedule object
  }

  Data inputs supported (pick one):
  1) <event-calendar src="/events.json"></event-calendar>
     - fetches JSON from URL (array of Event, single Event, or Calendar-like wrapper: { events: Event[] } or { hasPart: Event[] })
  2) <event-calendar> <script type="application/json">…</script> </event-calendar>
     - inline JSON, same accepted shapes as (1)
  3) programmatic: document.querySelector('event-calendar').data = … // same shapes

  Optional resolver for @id entries (CIDs, etc.):
  - Set: el.resolver = async (id) => EventObject | null
  - If present, the component will attempt to resolve any {"@id": "…"} items in hasPart/events.

  Attributes:
  - view="list" | "month"    (default: list)
  - timezone="America/Chicago" (default: browser local)

  NOTE: Zero deps. Modern browsers.
*/

class EventCalendarElement extends HTMLElement {
    static get observedAttributes() { return ['src', 'view', 'timezone']; }

    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        this._data = null; // normalized: { events: Event[] }
        this._resolver = null; // optional async function (id) => Event|null
        this._renderRoot();
    }

    // ---------------------- Public API ----------------------
    get data() { return this._dataRaw; }
    set data(value) {
        this._dataRaw = value;
        this._normalizeAndRender(value);
    }

    get resolver() { return this._resolver; }
    set resolver(fn) { this._resolver = typeof fn === 'function' ? fn : null; }

    // ------------------ Lifecycle & Attributes --------------
    connectedCallback() {
        this._upgradeProperty('data');
        this._upgradeProperty('resolver');
        this._applyInitial();
    }

    attributeChangedCallback(name, oldVal, newVal) {
        if (oldVal === newVal) return;
        if (name === 'src' && newVal) {
            this._fetchAndRender(newVal);
        } else if (name === 'view' || name === 'timezone') {
            this._render();
        }
    }

    // ---------------------- Internals -----------------------
    _upgradeProperty(prop) {
        if (Object.prototype.hasOwnProperty.call(this, prop)) {
            const value = this[prop];
            delete this[prop];
            this[prop] = value;
        }
    }

    _applyInitial() {
        const script = this.querySelector('script[type="application/json"]');
        if (script && !this.hasAttribute('src')) {
            try { this.data = JSON.parse(script.textContent || 'null'); }
            catch (e) { this._setStatus(`Invalid JSON: ${e.message}`); }
            return;
        }
        const src = this.getAttribute('src');
        if (src) this._fetchAndRender(src);
    }

    async _fetchAndRender(url) {
        this._setStatus('Loading…');
        try {
            const res = await fetch(url, { cache: 'no-store' });
            if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
            const data = await res.json();
            this.data = data;
        } catch (e) {
            this._setStatus(`Failed to load: ${e.message}`);
        }
    }

    async _normalizeAndRender(raw) {
        // Accept: single Event, array of Events, or wrapper {events|hasPart}
        let events = [];

        const isEvent = (o) => o && typeof o === 'object' && (o['@type'] === 'Event' || (o.startDate && o.endDate && o.name));

        if (Array.isArray(raw)) {
            events = raw.filter(isEvent);
        } else if (isEvent(raw)) {
            events = [raw];
        } else if (raw && typeof raw === 'object') {
            if (Array.isArray(raw.events)) events = raw.events.filter(isEvent);
            else if (Array.isArray(raw.hasPart)) events = raw.hasPart.filter(isEvent);
        }

        // resolve any {"@id": "…"} entries inside hasPart/events if resolver present
        if (this._resolver && raw && typeof raw === 'object' && Array.isArray(raw.hasPart)) {
            const unresolved = raw.hasPart.filter(x => x && typeof x === 'object' && '@id' in x && !isEvent(x));
            if (unresolved.length) {
                const resolved = await Promise.all(unresolved.map(x => this._safeResolve(x['@id'])));
                events = events.concat(resolved.filter(Boolean));
            }
        }

        // sort by startDate
        events.sort((a, b) => new Date(a.startDate) - new Date(b.startDate));

        this._data = { events };
        this._render();
    }

    async _safeResolve(id) {
        try { return await this._resolver(id); }
        catch { return null; }
    }

    _renderRoot() {
        const style = document.createElement('style');
        style.textContent = `
      :host { display: block; font: 14px/1.5 ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, sans-serif; color: #e7e7ea; }
      .card { background: #141416; border: 1px solid #232327; border-radius: 14px; padding: 16px; }
      .muted { color: #b0b1b7; }
      .row { display: grid; grid-template-columns: 1fr auto; gap: 8px; align-items: center; }
      .event { display: grid; grid-template-columns: 140px 1fr; gap: 12px; padding: 10px 0; border-bottom: 1px dashed #2b2c31; }
      .event:last-child { border-bottom: 0; }
      .date { color: #b0b1b7; }
      .name { font-weight: 600; }
      .pill { font-size: 12px; padding: 2px 8px; border: 1px solid #2b2c31; border-radius: 999px; background: #191a1d; color: #c9cad0; }
      .tiny { font-size: 12px; color: #9a9ba1; }
      .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
      select { background: #1a1b1e; color: #e7e7ea; border: 1px solid #232327; border-radius: 10px; padding: 6px 8px; }
    `;

        this._container = document.createElement('div');
        this._container.className = 'card';

        this.shadowRoot.append(style, this._container);
    }

    _render() {
        const view = (this.getAttribute('view') || 'list').toLowerCase();
        if (!this._data) return this._setStatus('No data');

        if (view === 'month') {
            this._container.innerHTML = this._renderMonth(this._data.events);
        } else {
            this._container.innerHTML = this._renderList(this._data.events);
        }
    }

    _renderList(events) {
        if (!events || !events.length) return '<div class="muted">No events</div>';

        const tz = this.getAttribute('timezone') || undefined; // let Intl default to local if undefined
        const fmtDate = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeZone: tz });
        const fmtTime = new Intl.DateTimeFormat(undefined, { timeStyle: 'short', timeZone: tz });

        const rows = events.map(ev => {
            const start = new Date(ev.startDate);
            const end = new Date(ev.endDate);
            const status = ev.eventStatus || 'EventScheduled';
            const loc = (typeof ev.location === 'string') ? ev.location : (ev.location && ev.location.name) || '';

            return `
        <div class="event">
          <div class="date">
            <div>${fmtDate.format(start)}</div>
            <div class="tiny">${fmtTime.format(start)} – ${fmtTime.format(end)}</div>
          </div>
          <div>
            <div class="row">
              <div class="name">${escapeHTML(ev.name || 'Untitled')}</div>
              <div class="pill">${escapeHTML(status)}</div>
            </div>
            ${ev.description ? `<div class="tiny">${escapeHTML(ev.description)}</div>` : ''}
            ${loc ? `<div class="tiny">📍 ${escapeHTML(loc)}</div>` : ''}
          </div>
        </div>`;
        }).join('');

        return `
      <div class="header">
        <div class="muted">${events.length} event${events.length!==1?'s':''}</div>
        <label class="tiny">view:
          <select onchange="this.getRootNode().host.setAttribute('view', this.value)">
            <option value="list" selected>list</option>
            <option value="month">month</option>
          </select>
        </label>
      </div>
      ${rows}`;
    }

    _renderMonth(events) {
        // Simple month grid of current month showing dots for events; clicking shows list below
        if (!events || !events.length) return '<div class="muted">No events</div>';

        const tz = this.getAttribute('timezone') || undefined;
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth();
        const first = new Date(year, month, 1);
        const startDay = new Date(first);
        startDay.setDate(first.getDate() - ((first.getDay() + 6) % 7)); // Monday start
        const days = [];
        for (let i = 0; i < 42; i++) { // 6 weeks
            const d = new Date(startDay);
            d.setDate(startDay.getDate() + i);
            days.push(d);
        }

        const eventsByDay = new Map();
        for (const ev of events) {
            const d = new Date(ev.startDate);
            const key = d.toISOString().slice(0,10);
            if (!eventsByDay.has(key)) eventsByDay.set(key, []);
            eventsByDay.get(key).push(ev);
        }

        const grid = days.map(d => {
            const key = d.toISOString().slice(0,10);
            const inMonth = d.getMonth() === month;
            const evs = eventsByDay.get(key) || [];
            const dots = evs.map(()=>'<span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#7aa2ff;margin-right:3px"></span>').join('');
            return `<div style="padding:8px;border:1px solid #232327;background:${inMonth?'#141416':'#0f0f11'}">
        <div class="tiny" style="opacity:${inMonth?1:0.5}">${d.getDate()}</div>
        <div>${dots}</div>
      </div>`;
        }).join('');

        const list = this._renderList(events);

        return `
      <div class="header">
        <div class="muted">${now.toLocaleString(undefined, { month: 'long' })} ${year}</div>
        <label class="tiny">view:
          <select onchange="this.getRootNode().host.setAttribute('view', this.value)">
            <option value="list">list</option>
            <option value="month" selected>month</option>
          </select>
        </label>
      </div>
      <div style="display:grid;grid-template-columns:repeat(7,1fr);gap:6px;margin-bottom:12px">${grid}</div>
      ${list}`;
    }

    _setStatus(msg) {
        this._container.innerHTML = `<div class="muted">${escapeHTML(msg)}</div>`;
    }
}

function escapeHTML(s) {
    return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));
}

customElements.define('event-calendar', EventCalendarElement);

export { EventCalendarElement };