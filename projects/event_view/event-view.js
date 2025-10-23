class EventView extends HTMLElement {
    constructor() {
        super();
        this._root = null;
        this._model = null;
        this._ldScript = null;
        this._jsonEditor = null;
    }

    static get observedAttributes() { return ['data-json-editor']; }

    attributeChangedCallback(name, oldVal, newVal) {
        if (name === 'data-json-editor' && this.isConnected) {
            if (newVal !== null) this._createJsonEditor();
            else this._removeJsonEditor();
        }
    }

    connectedCallback() {
        if (this._root) return;
        this._buildRoot();
        // find existing embedded script if present
        this._ldScript = this.querySelector('script[type="application/ld+json"]') || null;
        if (this._ldScript && this._ldScript.textContent.trim()) {
            const parsed = this._safeParse(this._ldScript.textContent);
            this._model = parsed || this._defaultEvent();
        } else {
            this._model = this._defaultEvent();
        }
        this._render();
        if (this.hasAttribute('data-json-editor')) this._createJsonEditor();
    }

    disconnectedCallback() {
        this._removeJsonEditor();
    }

    // Public API
    setEvent(ev) {
        this._model = ev || this._defaultEvent();
        this._syncLD();
        this._render();
    }

    getEvent() {
        return this._model;
    }

    exportJSON() {
        return JSON.parse(this._stableStringify(this._model));
    }

    importJSON(json) {
        this.setEvent(json);
    }

    // Internal
    _buildRoot() {
        this._root = document.createElement('div');
        this._root.className = 'ev-root';
        Object.assign(this._root.style, {
            fontFamily: 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial',
            color: '#111',
            background: '#fff',
            border: '1px solid #e6e6e6',
            borderRadius: '8px',
            padding: '12px',
            boxSizing: 'border-box'
        });
        this.appendChild(this._root);
    }

    _render() {
        if (!this._root) return;
        this._root.innerHTML = ''; // clear
        // header
        const h = document.createElement('div');
        h.style.display = 'flex';
        h.style.justifyContent = 'space-between';
        h.style.alignItems = 'center';
        const title = document.createElement('h3');
        title.textContent = this._model.name || 'Event';
        title.style.margin = '0';
        title.style.fontSize = '16px';
        const meta = document.createElement('div');
        meta.style.fontSize = '12px';
        meta.style.color = '#666';
        meta.textContent = `${this._model.startDate || ''}${this._model.endDate ? ' — ' + this._model.endDate : ''}`;
        h.appendChild(title);
        h.appendChild(meta);
        this._root.appendChild(h);

        // description
        if (this._model.description) {
            const desc = document.createElement('p');
            desc.textContent = this._model.description;
            desc.style.marginTop = '8px';
            desc.style.marginBottom = '8px';
            desc.style.lineHeight = '1.4';
            this._root.appendChild(desc);
        }

        // location block
        if (this._model.location) {
            const loc = document.createElement('div');
            loc.style.fontSize = '13px';
            loc.style.color = '#333';
            loc.style.marginBottom = '8px';
            const locName = this._model.location.name || '';
            const addr = (this._model.location.address && (this._model.location.address.streetAddress || this._model.location.address.addressLocality))
                ? `${this._model.location.address.streetAddress || ''}${this._model.location.address.addressLocality ? ', ' + this._model.location.address.addressLocality : ''}`.trim()
                : '';
            loc.innerHTML = `<strong>Location:</strong> ${this._escape(locName)}${addr ? ' — ' + this._escape(addr) : ''}`;
            this._root.appendChild(loc);
        }

        // organizer / performers / offers summary
        const infoList = document.createElement('div');
        infoList.style.display = 'flex';
        infoList.style.flexWrap = 'wrap';
        infoList.style.gap = '12px';
        infoList.style.fontSize = '13px';
        infoList.style.color = '#444';

        if (this._model.organizer && this._model.organizer.name) {
            const o = document.createElement('div');
            o.innerHTML = `<strong>Organizer:</strong> ${this._escape(this._model.organizer.name)}`;
            infoList.appendChild(o);
        }
        if (this._model.performer) {
            const perf = Array.isArray(this._model.performer) ? this._model.performer : [this._model.performer];
            if (perf.length) {
                const p = document.createElement('div');
                p.innerHTML = `<strong>Performers:</strong> ${this._escape(perf.map(x => x.name || x).join(', '))}`;
                infoList.appendChild(p);
            }
        }
        if (this._model.offers && this._model.offers.price) {
            const off = document.createElement('div');
            off.innerHTML = `<strong>Price:</strong> ${this._escape(String(this._model.offers.price))} ${this._escape(this._model.offers.priceCurrency || '')}`;
            infoList.appendChild(off);
        }
        if (infoList.childElementCount) this._root.appendChild(infoList);

        // JSON-LD script element (embedded)
        if (!this._ldScript) {
            this._ldScript = document.createElement('script');
            this._ldScript.type = 'application/ld+json';
            this.appendChild(this._ldScript);
        }
        this._syncLD();
    }

    _syncLD() {
        try {
            const pretty = !this.hasAttribute('data-compact');
            this._ldScript.textContent = pretty ? this._stableStringify(this._model, 2) : JSON.stringify(this._model);
        } catch (e) {
            // ignore
        }
        // keep editor in sync if present
        if (this._jsonEditor && this._jsonEditor.textarea) {
            const txt = this._stableStringify(this._model, 2);
            if (this._jsonEditor.textarea.value !== txt) this._jsonEditor.textarea.value = txt;
        }
    }

    _createJsonEditor() {
        if (this._jsonEditor) return;
        const container = document.createElement('div');
        container.style.marginTop = '10px';
        const ta = document.createElement('textarea');
        Object.assign(ta.style, {
            width: '100%', minHeight: '160px', boxSizing: 'border-box',
            fontFamily: 'monospace', fontSize: '13px', padding: '8px', borderRadius: '6px', border: '1px solid #ccc'
        });
        ta.spellcheck = false;
        ta.value = this._stableStringify(this._model, 2);
        const btns = document.createElement('div');
        btns.style.display = 'flex';
        btns.style.gap = '8px';
        btns.style.marginTop = '6px';
        const apply = document.createElement('button');
        apply.type = 'button';
        apply.textContent = 'Apply JSON';
        Object.assign(apply.style, {padding: '6px 10px', cursor: 'pointer'});
        const close = document.createElement('button');
        close.type = 'button';
        close.textContent = 'Close';
        Object.assign(close.style, {padding: '6px 10px', cursor: 'pointer'});
        btns.appendChild(apply);
        btns.appendChild(close);
        container.appendChild(ta);
        container.appendChild(btns);
        this._root.appendChild(container);

        apply.addEventListener('click', () => {
            const txt = ta.value;
            const parsed = this._safeParse(txt);
            if (parsed) {
                this._model = parsed;
                this._render();
            } else {
                ta.style.borderColor = '#c0392b';
            }
        });
        close.addEventListener('click', () => {
            this._removeJsonEditor();
        });

        this._jsonEditor = {container, textarea: ta};
    }

    _removeJsonEditor() {
        if (!this._jsonEditor) return;
        try { this._jsonEditor.container.remove(); } catch {}
        this._jsonEditor = null;
    }

    _safeParse(txt) {
        try { return JSON.parse(txt); } catch { return null; }
    }

    _stableStringify(obj, space = 2) {
        const seen = new WeakSet();
        const sortObj = (o) => {
            if (o === null || typeof o !== 'object') return o;
            if (seen.has(o)) return undefined;
            seen.add(o);
            if (Array.isArray(o)) return o.map(sortObj);
            const out = {};
            for (const k of Object.keys(o).sort()) out[k] = sortObj(o[k]);
            return out;
        };
        return JSON.stringify(sortObj(obj), null, space);
    }

    _escape(s) {
        if (s == null) return '';
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    _defaultEvent() {
        // A reasonably complete sample Event in JSON-LD (schema.org)
        return {
            "@context": "https://schema.org",
            "@type": "Event",
            "name": "Open Data & Community Meetup",
            "startDate": new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(), // one week from now
            "endDate": new Date(Date.now() + 7 * 24 * 3600 * 1000 + 3 * 3600 * 1000).toISOString(), // +3h
            "eventStatus": "https://schema.org/EventScheduled",
            "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
            "description": "A friendly meetup for people interested in open data, tooling, and community projects.",
            "location": {
                "@type": "Place",
                "name": "Community Hall",
                "address": {
                    "@type": "PostalAddress",
                    "streetAddress": "123 Main St",
                    "addressLocality": "Anytown",
                    "addressRegion": "CA",
                    "postalCode": "90210",
                    "addressCountry": "US"
                }
            },
            "image": [
                "https://example.org/images/event-banner.jpg"
            ],
            "organizer": {
                "@type": "Organization",
                "name": "Open Community",
                "url": "https://example.org"
            },
            "performer": [
                {"@type": "Person", "name": "Alex Doe"},
                {"@type": "Person", "name": "Jamie Roe"}
            ],
            "offers": {
                "@type": "Offer",
                "url": "https://example.org/tickets/123",
                "price": "0",
                "priceCurrency": "USD",
                "availability": "https://schema.org/InStock"
            },
            "sameAs": "https://example.org/events/open-meetup-2025",
            "identifier": {
                "@type": "PropertyValue",
                "propertyID": "eventId",
                "value": "od-meetup-2025-001"
            }
        };
    }
}

customElements.define('event-view', EventView);
export { EventView };
