/*
 Event Calendar — plain JavaScript implementation
 -----------------------------------------------
 - Mirrors the spirit of the LogoGraph interface used in Logoverse
 - Computes CIDv1 (multibase base32, multihash sha2-256) over a stable JSON-LD
 - No external deps; browser + Node compatible (uses Web Crypto when available)

 Exposed API (examples at bottom):
   - CID.compute(object) -> Promise<string>
   - classes: LogoObject (base), Schedule, Event, EventCalendar
   - Each class implements:
       jsonLD()   -> plain object (stable keys)
       cid()      -> Promise<string> (CIDv1 over jsonLD)
       svg()      -> string (tiny placeholder glyph)
       thumbnail()-> string (data URL placeholder)
   - Registry + Render(path):
       register(obj) -> Promise<string>  // returns CID and stores obj by CID
       render(path) -> string            // very small demo router using 
                                         // query params: ?cid=<cid>&fmt=svg|json
*/

// ------------------------------------------------------------
// Utilities: stable stringify, varint, base32, multihash, CIDv1
// ------------------------------------------------------------
const _textEncoder = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;

function toBytes(str) {
  if (typeof Buffer !== 'undefined') return Buffer.from(str, 'utf8');
  if (_textEncoder) return _textEncoder.encode(str);
  // tiny fallback
  const arr = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) arr[i] = str.charCodeAt(i) & 0xff;
  return arr;
}

function fromBytes(bytes) {
  if (typeof Buffer !== 'undefined') return Buffer.from(bytes).toString('binary');
  let s = '';
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return s;
}

// Stable stringify (JSON with keys sorted recursively)
function stableStringify(obj) {
  return JSON.stringify(obj, function replacer(key, value) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      const out = {};
      for (const k of Object.keys(value).sort()) out[k] = value[k];
      return out;
    }
    return value;
  });
}

// SHA-256 (browser WebCrypto or Node crypto)
async function sha256(bytes) {
  if (typeof crypto !== 'undefined' && crypto.subtle) {
    const hashBuf = await crypto.subtle.digest('SHA-256', bytes);
    return new Uint8Array(hashBuf);
  }
  // Node (>= v16)
  try {
    const { createHash } = await import('node:crypto');
    const h = createHash('sha256');
    h.update(Buffer.from(bytes));
    return new Uint8Array(h.digest());
  } catch (e) {
    throw new Error('No crypto.subtle and node:crypto unavailable');
  }
}

// Uvarint encode
function uvarint(n) {
  const out = [];
  while (n >= 0x80) {
    out.push((n & 0x7f) | 0x80);
    n >>>= 7;
  }
  out.push(n);
  return new Uint8Array(out);
}

// RFC4648 base32 (lowercase) without padding, multibase prefix 'b'
const _b32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
function base32encode(bytes) {
  let bits = 0, value = 0, output = '';
  for (let i = 0; i < bytes.length; i++) {
    value = (value << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      output += _b32Alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += _b32Alphabet[(value << (5 - bits)) & 31];
  return 'b' + output; // multibase prefix for base32-lower
}

// Multihash (sha2-256 code 0x12, length 32 bytes)
function multihashSha256(digest) {
  const code = uvarint(0x12);
  const len = uvarint(digest.length);
  const out = new Uint8Array(code.length + len.length + digest.length);
  out.set(code, 0);
  out.set(len, code.length);
  out.set(digest, code.length + len.length);
  return out;
}

// CIDv1 = 0x01 | <codec-varint> | <multihash>
// Default codec here: dag-json (0x0129). Alternatives: raw (0x55), dag-cbor (0x71)
const CODEC = {
  'dag-json': 0x0129,
  'raw': 0x55,
  'dag-cbor': 0x71,
};

function encodeCIDv1(multihashBytes, codecName = 'dag-json') {
  const version = uvarint(1);
  const codec = uvarint(CODEC[codecName] ?? CODEC['dag-json']);
  const out = new Uint8Array(version.length + codec.length + multihashBytes.length);
  out.set(version, 0);
  out.set(codec, version.length);
  out.set(multihashBytes, version.length + codec.length);
  return base32encode(out);
}

// CID helper facade
const CID = {
  async compute(object, codec = 'dag-json') {
    const json = stableStringify(object);
    const bytes = toBytes(json);
    const dig = await sha256(bytes);
    const mh = multihashSha256(dig);
    return encodeCIDv1(mh, codec);
  },
};

// ------------------------------------------------------------
// LogoGraph-like base + domain objects (Schedule, Event, Calendar)
// ------------------------------------------------------------
class LogoObject {
  /**
   * @returns {Object} JSON-LD object. Subclasses should override.
   */
  jsonLD() { return { '@context': 'https://schema.org' }; }

  /**
   * @returns {Promise<string>} CIDv1 (base32) over stable JSON-LD
   */
  async cid() { return CID.compute(this.jsonLD()); }

  /** minimal inline glyph */
  svg() {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect x="8" y="12" width="48" height="44" rx="6" ry="6" fill="none" stroke="currentColor"/>
      <line x1="8" y1="24" x2="56" y2="24" stroke="currentColor"/>
      <circle cx="20" cy="36" r="3" fill="currentColor"/>
      <circle cx="32" cy="36" r="3" fill="currentColor"/>
      <circle cx="44" cy="36" r="3" fill="currentColor"/>
    </svg>`;
  }

  thumbnail() {
    // Tiny data URL placeholder (1x1 transparent PNG)
    return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAukB9Vt0bK8AAAAASUVORK5CYII=';
  }
}

class Schedule extends LogoObject {
  constructor({ name, description, byDay, startTime, duration, timeZone, calendarCid }) {
    super();
    this.name = name || 'Default Schedule';
    this.description = description || '';
    this.byDay = byDay || ['Wednesday']; // e.g., ['Wednesday']
    this.startTime = startTime || '10:00:00Z';
    this.duration = duration || 'PT1H';
    this.timeZone = timeZone || 'UTC';
    this.calendarCid = calendarCid || null; // backlink to parent calendar (optional)
  }

  jsonLD() {
    const obj = {
      '@context': 'https://schema.org',
      '@type': 'Schedule',
      name: this.name,
      description: this.description,
      byDay: this.byDay,
      startTime: this.startTime,
      duration: this.duration,
      timeZone: this.timeZone,
    };
    if (this.calendarCid) obj.calendar = { '@id': this.calendarCid };
    return obj;
  }
}

class Event extends LogoObject {
  constructor({ name, description, startDate, endDate, status, location, organizer, scheduleCid }) {
    super();
    this.name = name || 'Office Hours';
    this.description = description || '';
    this.startDate = startDate; // ISO 8601
    this.endDate = endDate;     // ISO 8601
    this.status = status || 'EventScheduled'; // or EventProposed, EventCancelled
    this.location = location || null; // string or Place JSON-LD
    this.organizer = organizer || null; // Person/Org JSON-LD
    this.scheduleCid = scheduleCid || null; // backlink to schedule
  }

  jsonLD() {
    const obj = {
      '@context': 'https://schema.org',
      '@type': 'Event',
      name: this.name,
      description: this.description,
      eventStatus: this.status,
      startDate: this.startDate,
      endDate: this.endDate,
    };
    if (this.location) obj.location = this.location;
    if (this.organizer) obj.organizer = this.organizer;
    if (this.scheduleCid) obj.schedule = { '@id': this.scheduleCid };
    return obj;
  }
}

class EventCalendar extends LogoObject {
  constructor({ name, description, schedule, events }) {
    super();
    this.name = name || 'Event Calendar';
    this.description = description || '';
    this.schedule = schedule || null; // Schedule instance
    this.events = Array.isArray(events) ? events : []; // Event[]
  }

  jsonLD() {
    return {
      '@context': 'https://schema.org',
      '@type': 'CreativeWork',
      additionalType: 'https://schema.org/Calendar',
      name: this.name,
      description: this.description,
      hasPart: this.events.map(e => ({ '@id': e._cid || 'pending' })),
      workExample: this.schedule ? ({ '@id': this.schedule._cid || 'pending' }) : undefined,
    };
  }
}

// ------------------------------------------------------------
// Mini registry & Render helper (path as a probe)
// ------------------------------------------------------------
const Registry = new Map(); // cid -> instance

async function register(obj) {
  const cid = await obj.cid();
  obj._cid = cid; // cache for references
  Registry.set(cid, obj);
  return cid;
}

function _parseQuery(qs) {
  const out = {};
  if (!qs) return out;
  const s = qs.startsWith('?') ? qs.substring(1) : qs;
  for (const kv of s.split('&')) {
    if (!kv) continue;
    const [k, v] = kv.split('=');
    out[decodeURIComponent(k)] = decodeURIComponent(v || '');
  }
  return out;
}

function Render(path = '') {
  // Accepts "/r?cid=...&fmt=svg|json"
  const qIndex = path.indexOf('?');
  const query = _parseQuery(qIndex >= 0 ? path.slice(qIndex) : '');
  const cid = query.cid;
  const fmt = (query.fmt || 'json').toLowerCase();
  if (!cid) return 'missing cid';
  const obj = Registry.get(cid);
  if (!obj) return `unknown cid: ${cid}`;
  if (fmt === 'svg') return obj.svg();
  if (fmt === 'thumbnail') return obj.thumbnail();
  return JSON.stringify(obj.jsonLD(), null, 2);
}

// ------------------------------------------------------------
// Example: build schedule -> calendar -> events, link via CIDs
// ------------------------------------------------------------
async function demo() {
  const schedule = new Schedule({
    name: 'AibLabs Office Hours',
    description: 'Open discussion. Weekly.',
    byDay: ['Wednesday'],
    startTime: '10:00:00Z',
    duration: 'PT1H',
    timeZone: 'UTC',
  });

  // compute & register schedule first to attach its CID into events/cal
  const scheduleCid = await register(schedule);

  const event1 = new Event({
    name: 'Office Hours — Week 1',
    startDate: '2025-10-01T10:00:00Z',
    endDate: '2025-10-01T11:00:00Z',
    status: 'EventProposed',
    scheduleCid,
  });
  const event2 = new Event({
    name: 'Office Hours — Week 2',
    startDate: '2025-10-08T10:00:00Z',
    endDate: '2025-10-08T11:00:00Z',
    status: 'EventScheduled',
    scheduleCid,
  });

  const [event1Cid, event2Cid] = await Promise.all([register(event1), register(event2)]);

  const calendar = new EventCalendar({
    name: 'AibLabs Calendar',
    description: 'CID-addressed calendar (LogoGraph-style).',
    schedule,
    events: [event1, event2],
  });
  const calendarCid = await register(calendar);

  // back-link schedule to calendar (optional), then re-register to refresh cid if desired
  schedule.calendarCid = calendarCid;
  // Note: back-linking changes the schedule CID; in append-only systems you would
  // publish a new version. For demo simplicity we re-register (overwrite) here.
  const scheduleCidV2 = await register(schedule);

  return { scheduleCid: scheduleCidV2, event1Cid, event2Cid, calendarCid };
}

// If running directly (Node), run demo
/*
(async () => {
  const ids = await demo();
  console.log('CIDs:', ids);
  console.log('\nRender calendar json:\n', Render(`?cid=${ids.calendarCid}&fmt=json`));
  console.log('\nRender calendar svg:\n', Render(`?cid=${ids.calendarCid}&fmt=svg`));
})();
*/

// Export for usage in browser or Node bundlers
export {
  CID,
  LogoObject,
  Schedule,
  Event,
  EventCalendar,
  register,
  Render,
  demo,
};
