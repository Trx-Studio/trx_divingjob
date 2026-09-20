/* trx_divingjob - dive tablet, dive HUD and contract summary (vanilla, no build step).
   The tablet frame, sizes and components mirror trx_taxijob / trx_busjob / trx_garbagejob so the jobs feel like one product. */
(() => {
    'use strict';

    const RES = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : 'trx_divingjob';

    const $ = (id) => document.getElementById(id);
    const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.round(Number(n) || 0).toLocaleString('en-US');
    const int = (n) => Math.round(Number(n) || 0).toLocaleString('en-US');
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const initials = (name) => String(name || '?').split(/\s+/).map((s) => s[0] || '').join('').slice(0, 2).toUpperCase();
    const mmss = (sec) => {
        sec = Math.max(0, Math.floor(Number(sec) || 0));
        return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
    };

    const store = {
        get(key) { try { return window.localStorage.getItem('trx_divingjob:' + key); } catch (e) { return null; } },
        set(key, val) { try { window.localStorage.setItem('trx_divingjob:' + key, val); } catch (e) { /* storage unavailable */ } },
    };

    function duration(sec) {
        sec = Math.max(0, Math.round(sec || 0));
        const m = Math.floor(sec / 60);
        return m >= 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m}m ${String(sec % 60).padStart(2, '0')}s`;
    }

    function ago(unix, now) {
        const d = Math.max(0, (now || Date.now() / 1000) - unix);
        if (d < 60) return 'just now';
        if (d < 3600) return Math.floor(d / 60) + 'm ago';
        if (d < 86400) return Math.floor(d / 3600) + 'h ago';
        return Math.floor(d / 86400) + 'd ago';
    }

    /* ------------------------------------------------------------ icons */
    const ic = (body, extra = '') => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" ${extra}>${body}</svg>`;
    const ICON = {
        contracts: ic('<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><path d="M12 1.5v4M12 18.5v4M1.5 12h4M18.5 12h4"/>'),
        shop: ic('<path d="M5 8h14l-1.2 12.2a1 1 0 0 1-1 .8H7.2a1 1 0 0 1-1-.8L5 8z"/><path d="M9 10V6.5a3 3 0 0 1 6 0V10"/>'),
        boat: ic('<path d="M3 15h18l-2.6 4.2a2 2 0 0 1-1.7.8H7.3a2 2 0 0 1-1.7-.8L3 15z"/><path d="M6 15V10h9l3 5"/><path d="M9 10V6h3"/>'),
        board: ic('<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0V4z"/><path d="M17 6h3v1.5A3.5 3.5 0 0 1 17 11M7 6H4v1.5A3.5 3.5 0 0 0 7 11"/>'),
        diver: ic('<path d="M3.5 9.5a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2v2.5a3 3 0 0 1-3 3h-1.8l-1.7-2h-4l-1.7 2H6.5a3 3 0 0 1-3-3V9.5z"/><path d="M20.5 10h1v6a3 3 0 0 1-3 3h-2"/>'),
        rewards: ic('<rect x="3.5" y="9" width="17" height="4" rx="1"/><path d="M5 13v7h14v-7M12 9v11"/><path d="M12 9c-1.5-3-5-4-5-1.5S10 9 12 9zM12 9c1.5-3 5-4 5-1.5S14 9 12 9z"/>'),
        close: ic('<path d="M6 6l12 12M18 6L6 18"/>'),
        lock: ic('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
        check: ic('<path d="M5 12.5l4.5 4.5L19 7"/>', 'stroke-width="3"'),
        info: ic('<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>'),
        play: ic('<path d="M7 5l12 7-12 7V5z" fill="currentColor"/>'),
        pin: ic('<path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0 1 13 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>'),
        tank: ic('<rect x="8" y="6" width="8" height="15" rx="4"/><path d="M12 6V3M10 3h4"/>'),
        site: ic('<path d="M2 16c2 0 2-1.5 4-1.5s2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5"/><path d="M2 20c2 0 2-1.5 4-1.5s2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5"/><path d="M12 12V3l5 3-5 3"/>'),
        air: ic('<path d="M3 8h11a3 3 0 1 0-3-3M3 16h15a3 3 0 1 1-3 3M3 12h7"/>'),
        tablet: ic('<rect x="4" y="2.5" width="16" height="19" rx="2.5"/><path d="M10 18.5h4"/>'),
        coin: ic('<circle cx="12" cy="12" r="8.5"/><path d="M14.8 9.2c-.6-.9-1.6-1.4-2.8-1.4-1.6 0-2.8.9-2.8 2.1 0 2.9 5.8 1.3 5.8 4.2 0 1.2-1.2 2.1-2.9 2.1-1.2 0-2.3-.5-2.9-1.4M12 6v1.8M12 16.2V18"/>'),
        return: ic('<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>'),
        box: ic('<path d="M3 7.5L12 3l9 4.5v9L12 21l-9-4.5v-9z"/><path d="M3 7.5l9 4.5 9-4.5M12 12v9"/>'),
    };
    document.querySelector('[data-action="close"]').innerHTML = ICON.close;

    /* ------------------------------------------------------------ art (drawn, no image host needed)
       The tank art is the same drawing as the ox_inventory item images in images/. */
    let uid = 0;

    // metal / paint shading across a cylinder: dark rim, base, bright specular, base, dark rim
    const cylGrad = (id, c) => `<linearGradient id="${id}" x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stop-color="${c.rim}"/><stop offset=".12" stop-color="${c.base}"/>
        <stop offset=".3" stop-color="${c.hi}"/><stop offset=".38" stop-color="${c.spec}"/>
        <stop offset=".46" stop-color="${c.hi}"/><stop offset=".72" stop-color="${c.base}"/>
        <stop offset="1" stop-color="${c.rim}"/></linearGradient>`;

    const chrome = (id) => cylGrad(id, { rim: '#4a525c', base: '#9aa3ad', hi: '#dfe4e9', spec: '#ffffff' });
    const rubber = (id) => cylGrad(id, { rim: '#050607', base: '#15181c', hi: '#2b3037', spec: '#3b424b' });

    const shadow = (cx, y, rx) => `<ellipse cx="${cx}" cy="${y}" rx="${rx}" ry="${rx * 0.16}" fill="url(#${'sh'})"/>`;

    // a K-valve with a black handwheel on the right and a DIN/yoke outlet on the left
    function valve(p, cx, top, flip = 1) {
        return `
        <rect x="${cx - 7}" y="${top - 10}" width="14" height="12" rx="2" fill="url(#${p}chr)"/>
        <rect x="${cx - 11}" y="${top - 26}" width="22" height="17" rx="3" fill="url(#${p}chr)"/>
        <rect x="${cx - 11}" y="${top - 26}" width="22" height="3" rx="1.5" fill="#fff" opacity=".35"/>
        <rect x="${flip > 0 ? cx - 26 : cx + 10}" y="${top - 23}" width="16" height="11" rx="2" fill="url(#${p}chr)"/>
        <circle cx="${cx - 24 * flip}" cy="${top - 17.5}" r="3.2" fill="#2a2f35"/>
        <rect x="${flip > 0 ? cx + 10 : cx - 16}" y="${top - 21}" width="6" height="7" fill="url(#${p}chr)"/>
        <ellipse cx="${cx + 21 * flip}" cy="${top - 17.5}" rx="5" ry="11" fill="url(#${p}rub)"/>
        <ellipse cx="${cx + 21 * flip}" cy="${top - 17.5}" rx="5" ry="11" fill="none" stroke="#000" stroke-opacity=".5"/>
        ${[-7, -3.5, 0, 3.5, 7].map((d) => `<line x1="${cx + 17 * flip}" x2="${cx + 25 * flip}" y1="${top - 17.5 + d}" y2="${top - 17.5 + d}" stroke="#000" stroke-opacity=".45" stroke-width=".8"/>`).join('')}
        <circle cx="${cx}" cy="${top - 30}" r="3" fill="url(#${p}chr)"/>`;
    }

    // one cylinder: body, dome, stamping, sticker bands, boot
    function cylinder(p, o) {
        const { x, w, top, bottom, paint } = o;
        const cx = x + w / 2, dome = w * 0.42;
        const body = `M${x},${top + dome} C${x},${top + 4} ${x + w * 0.18},${top} ${cx},${top} C${x + w * 0.82},${top} ${x + w},${top + 4} ${x + w},${top + dome} L${x + w},${bottom - 6} Q${x + w},${bottom} ${x + w - 6},${bottom} L${x + 6},${bottom} Q${x},${bottom} ${x},${bottom - 6} Z`;
        const clip = `${p}clip${o.key}`;
        let s = `<clipPath id="${clip}"><path d="${body}"/></clipPath>`;
        s += `<path d="${body}" fill="url(#${p}paint${o.key})"/>`;
        s += `<g clip-path="url(#${clip})">`;
        // shoulder: bare metal on painted tanks, with stamped lines
        if (o.shoulder) s += `<rect x="${x}" y="${top - 2}" width="${w}" height="${dome + 6}" fill="url(#${p}shoulder${o.key})"/>`;
        s += `<g opacity=".35" stroke="#000" stroke-width=".7">
            <line x1="${cx - w * 0.28}" x2="${cx + w * 0.18}" y1="${top + dome - 4}" y2="${top + dome - 4}"/>
            <line x1="${cx - w * 0.28}" x2="${cx + w * 0.08}" y1="${top + dome + 0}" y2="${top + dome + 0}"/></g>`;
        // bands and stickers
        (o.bands || []).forEach((b) => { s += `<rect x="${x}" y="${b.y}" width="${w}" height="${b.h}" fill="url(#${p}band${o.key}${b.y})"/>`; });
        if (o.label) {
            s += `<rect x="${x}" y="${o.label.y}" width="${w}" height="${o.label.h}" fill="url(#${p}label${o.key})"/>`;
            s += `<text x="${cx - w * 0.06}" y="${o.label.y + o.label.h * 0.66}" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="${o.label.size}" fill="${o.label.ink}" letter-spacing="1" opacity=".9">${o.label.text}</text>`;
        }
        if (o.vip) s += `<rect x="${cx + w * 0.12}" y="${o.vip}" width="${w * 0.2}" height="9" rx="1.5" fill="${o.vipColor || '#2e9b58'}"/><rect x="${cx + w * 0.12}" y="${o.vip}" width="${w * 0.2}" height="3" rx="1" fill="#fff" opacity=".45"/>`;
        // boot
        s += `<rect x="${x - 1}" y="${bottom - o.boot}" width="${w + 2}" height="${o.boot + 2}" fill="url(#${p}rub)"/>`;
        s += `<g fill="#000" opacity=".6">${[0.22, 0.5, 0.78].map((f) => `<rect x="${x + w * f - 3}" y="${bottom - o.boot * 0.62}" width="6" height="${o.boot * 0.3}" rx="1.5"/>`).join('')}</g>`;
        s += `<rect x="${x}" y="${bottom - o.boot}" width="${w}" height="1.5" fill="#fff" opacity=".12"/>`;
        // vertical specular + bottom occlusion
        s += `<rect x="${x + w * 0.28}" y="${top + 6}" width="${w * 0.05}" height="${bottom - top - o.boot - 12}" fill="#fff" opacity=".22"/>`;
        // the dome turns away from the light; the body darkens just above the boot
        s += `<rect x="${x}" y="${top - 2}" width="${w}" height="${dome + 8}" fill="url(#dome)"/>`;
        s += `<rect x="${x}" y="${bottom - o.boot - 14}" width="${w}" height="14" fill="url(#occl)"/>`;
        s += '</g>';
        s += valve(p, cx, top + 2, o.flip || 1);
        return s;
    }

    function defsFor(p, o) {
        let d = chrome(`${p}chr`) + rubber(`${p}rub`);
        d += cylGrad(`${p}paint${o.key}`, o.paint);
        if (o.shoulder) d += `<linearGradient id="${p}shoulder${o.key}" x1="0" x2="0" y1="0" y2="1"><stop offset=".75" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>`;
        (o.bands || []).forEach((b) => { d += cylGrad(`${p}band${o.key}${b.y}`, b.c); });
        if (o.label) d += cylGrad(`${p}label${o.key}`, o.label.c);
        return d;
    }

    const PAINT = {
        alu:    { rim: '#6b737c', base: '#b9c0c7', hi: '#e6eaee', spec: '#ffffff' },
        yellow: { rim: '#6e5208', base: '#e2b21c', hi: '#f7d45a', spec: '#fff2b8' },
        steel:  { rim: '#1e2b3b', base: '#3d5673', hi: '#6f8aa8', spec: '#c7d6e6' },
        galv:   { rim: '#3a3f45', base: '#7d858d', hi: '#b3bac1', spec: '#e6ebef' },
        white:  { rim: '#8d949b', base: '#e6e9ec', hi: '#f7f8f9', spec: '#ffffff' },
        green:  { rim: '#0b3a1f', base: '#1f7a45', hi: '#3fae6c', spec: '#a8e7c1' },
        black:  { rim: '#050607', base: '#1a1d21', hi: '#343a42', spec: '#58606a' },
        yellowBand: { rim: '#6e5208', base: '#e2b21c', hi: '#f7d45a', spec: '#fff2b8' },
        orange: { rim: '#6b2f06', base: '#e0701f', hi: '#f59a4d', spec: '#ffd2a8' },
    };

    function frame(inner, defs) {
        return `<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>${defs}
            <linearGradient id="dome" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity=".45"/><stop offset=".55" stop-color="#000" stop-opacity=".08"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>
            <linearGradient id="occl" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".3"/></linearGradient>
            <radialGradient id="sh" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#000" stop-opacity=".55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>
            ${inner}</svg>`;
    }

    function single(spec) {
        const p = `t${spec.tier}_${++uid}_`;
        const o = Object.assign({ key: 'a' }, spec.cyl);
        return frame(shadow(o.x + o.w / 2, o.bottom + 3, o.w * 0.75) + cylinder(p, o), defsFor(p, o));
    }

    function twin() {
        const p = `tw${++uid}_`;
        const common = { w: 48, top: 52, bottom: 184, boot: 0, paint: PAINT.galv,
            label: { y: 112, h: 16, text: 'AIR', size: 10, ink: '#0b1a2a', c: PAINT.white } };
        const L = Object.assign({ key: 'l', x: 48, flip: -1, vip: 90, vipColor: '#2e9b58' }, common);
        const R = Object.assign({ key: 'r', x: 104, flip: 1 }, common);
        let s = shadow(100, 187, 72);
        s += cylinder(p, L) + cylinder(p, R);
        // stainless bands with wing nuts
        [76, 150].forEach((y) => {
            s += `<rect x="44" y="${y}" width="112" height="7" rx="2" fill="url(#${p}chr)"/>`;
            s += `<rect x="94" y="${y - 3}" width="12" height="13" rx="2" fill="url(#${p}chr)" stroke="#3b424b" stroke-width=".6"/>`;
            s += `<circle cx="100" cy="${y + 3.5}" r="2.2" fill="#3b424b"/>`;
        });
        // isolation manifold bar across the valves, with the centre isolator knob
        s += `<rect x="68" y="33" width="64" height="9" rx="3" fill="url(#${p}chr)"/>`;
        s += `<rect x="94" y="18" width="12" height="16" rx="2" fill="url(#${p}chr)"/>`;
        s += `<ellipse cx="100" cy="14" rx="11" ry="5" fill="url(#${p}rub)"/>`;
        return frame(s, defsFor(p, L) + defsFor(p, R));
    }

    function ccr() {
        const p = `cc${++uid}_`;
        let d = chrome(`${p}chr`) + rubber(`${p}rub`);
        d += cylGrad(`${p}shell`, PAINT.black) + cylGrad(`${p}cover`, { rim: '#6e5208', base: '#e8b923', hi: '#f8d867', spec: '#fff4c4' });
        d += cylGrad(`${p}o2`, PAINT.white) + cylGrad(`${p}o2s`, PAINT.green) + cylGrad(`${p}dil`, PAINT.galv);
        d += `<linearGradient id="${p}lung" x1="0" x2="1"><stop offset="0" stop-color="#101214"/><stop offset=".4" stop-color="#2e333a"/><stop offset="1" stop-color="#0b0d0f"/></linearGradient>`;
        let s = shadow(100, 188, 76);
        // counterlungs behind (soft bags)
        s += `<path d="M30,70 Q22,120 36,170 Q52,180 60,168 L62,78 Q50,62 30,70 Z" fill="url(#${p}lung)"/>`;
        s += `<path d="M170,70 Q178,120 164,170 Q148,180 140,168 L138,78 Q150,62 170,70 Z" fill="url(#${p}lung)"/>`;
        // side cylinders: O2 (white, green shoulder) and diluent (grey)
        const side = (x, grad, shoulder) => `
            <path d="M${x},92 Q${x},82 ${x + 9},82 Q${x + 18},82 ${x + 18},92 L${x + 18},176 Q${x + 18},180 ${x + 14},180 L${x + 4},180 Q${x},180 ${x},176 Z" fill="url(#${p}${grad})"/>
            ${shoulder ? `<path d="M${x},92 Q${x},82 ${x + 9},82 Q${x + 18},82 ${x + 18},92 L${x + 18},98 L${x},98 Z" fill="url(#${p}${shoulder})"/>` : ''}
            <rect x="${x + 5}" y="72" width="8" height="11" rx="1.5" fill="url(#${p}chr)"/>
            <ellipse cx="${x + 9}" cy="70" rx="7" ry="3.5" fill="url(#${p}rub)"/>`;
        s += side(44, 'o2', 'o2s') + side(138, 'dil', null);
        // main shell and scrubber housing
        s += `<rect x="64" y="60" width="72" height="124" rx="14" fill="url(#${p}shell)"/>`;
        s += `<rect x="70" y="78" width="60" height="96" rx="10" fill="url(#${p}cover)"/>`;
        s += `<rect x="70" y="78" width="60" height="4" rx="2" fill="#fff" opacity=".35"/>`;
        s += `<g stroke="#000" stroke-opacity=".25" stroke-width="1.2">${[104, 128, 152].map((y) => `<line x1="72" x2="128" y1="${y}" y2="${y}"/>`).join('')}</g>`;
        s += `<text x="100" y="120" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="11" fill="#1a1206" opacity=".75">CCR</text>`;
        // head with electronics cable and latches
        s += `<rect x="60" y="52" width="80" height="20" rx="8" fill="url(#${p}shell)"/>`;
        s += `<rect x="66" y="66" width="10" height="10" rx="2" fill="url(#${p}chr)"/><rect x="124" y="66" width="10" height="10" rx="2" fill="url(#${p}chr)"/>`;
        s += `<circle cx="100" cy="60" r="4" fill="#1fb86b"/><circle cx="100" cy="60" r="1.6" fill="#b9ffd8"/>`;
        // corrugated loop hoses to the mouthpiece
        const hose = (d) => `<path d="${d}" fill="none" stroke="#0c0e10" stroke-width="11" stroke-linecap="round"/>
            <path d="${d}" fill="none" stroke="#2a2f36" stroke-width="11" stroke-dasharray="2.2 2.2" stroke-linecap="butt"/>
            <path d="${d}" fill="none" stroke="#fff" stroke-opacity=".08" stroke-width="3"/>`;
        s += hose('M74,56 C62,30 78,14 96,16');
        s += hose('M126,56 C138,30 122,14 104,16');
        // DSV mouthpiece
        s += `<rect x="88" y="8" width="24" height="16" rx="6" fill="url(#${p}shell)"/>`;
        s += `<rect x="96" y="3" width="8" height="8" rx="2" fill="url(#${p}cover)"/>`;
        s += `<rect x="94" y="22" width="12" height="7" rx="3" fill="#0a0b0d"/>`;
        return frame(s, d);
    }

    const SPECS = {
        1: { tier: 1, cyl: { x: 80, w: 40, top: 62, bottom: 186, boot: 16, paint: PAINT.alu,
            bands: [{ y: 104, h: 5, c: PAINT.yellowBand }],
            label: { y: 124, h: 14, text: 'AIR', size: 9, ink: '#1a1d21', c: PAINT.yellow }, vip: 150 } },
        2: { tier: 2, cyl: { x: 71, w: 58, top: 46, bottom: 188, boot: 20, paint: PAINT.yellow,
            shoulder: false, bands: [{ y: 88, h: 4, c: PAINT.black }],
            label: { y: 108, h: 18, text: 'AL80', size: 12, ink: '#1a1d21', c: PAINT.white }, vip: 138, vipColor: '#d23c2f' } },
        3: { tier: 3, cyl: { x: 69, w: 62, top: 40, bottom: 188, boot: 22, paint: PAINT.steel,
            bands: [{ y: 84, h: 4, c: PAINT.white }],
            label: { y: 104, h: 20, text: 'HP100', size: 12, ink: '#0b2a14', c: { rim: '#6f5e0a', base: '#dfd23a', hi: '#f2ea83', spec: '#fffbd0' } },
            vip: 136, vipColor: '#2e6fd2' } },
    };

    function tank(tier) {
        if (tier === 4) return twin();
        if (tier === 5) return ccr();
        return single(SPECS[tier] || SPECS[2]);
    }

    const tankSvg = (tier) => tank(tier);

    const BOAT_STYLE = {
        dinghy: { kind: 'dinghy', hull: '#E46A3C', deck: '#2d343e' },
        seashark: { kind: 'jetski', hull: '#e9ecef', deck: '#3f6fb0' },
        tropic: { kind: 'cruiser', hull: '#f3f5f7', deck: '#4FB3D9' },
        speeder: { kind: 'speed', hull: '#1b2027', deck: '#EE9A2E' },
        submersible: { kind: 'sub', hull: '#E0C04F', deck: '#2d343e' },
    };

    function boatSvg(model) {
        const st = BOAT_STYLE[model] || { kind: 'cruiser', hull: '#b3bbc4', deck: '#56606c' };
        const water = '<path d="M0,64 Q20,60 40,64 T80,64 T120,64 T160,64 T200,64 T240,64 L240,80 L0,80 Z" fill="#4FB3D9" opacity=".18"/>';
        let s = '';
        if (st.kind === 'dinghy') {
            s += `<path d="M40,46 L196,46 Q214,46 214,56 Q214,64 196,64 L48,64 Q34,64 34,56 Q34,50 40,46 Z" fill="${st.hull}"/>`;
            s += '<rect x="44" y="50" width="150" height="3" fill="#000" opacity=".15"/>';
            s += `<rect x="70" y="40" width="30" height="7" rx="2" fill="${st.deck}"/><rect x="120" y="40" width="30" height="7" rx="2" fill="${st.deck}"/>`;
            s += '<path d="M24,30 L36,30 L38,64 L30,70 L26,64 Z" fill="#232a33"/><rect x="22" y="26" width="18" height="8" rx="2" fill="#39424d"/>';
        } else if (st.kind === 'jetski') {
            s += `<path d="M50,50 L170,44 Q200,44 206,54 L200,62 L60,64 Q46,64 50,50 Z" fill="${st.hull}"/>`;
            s += `<path d="M90,44 L150,38 L160,44 L96,48 Z" fill="${st.deck}"/>`;
            s += '<path d="M150,38 L162,24 L170,26 L160,40 Z" fill="#232a33"/><rect x="156" y="20" width="22" height="5" rx="2" fill="#39424d"/>';
            s += `<path d="M60,58 L200,54" stroke="${st.deck}" stroke-width="3"/>`;
        } else if (st.kind === 'sub') {
            s += `<ellipse cx="120" cy="44" rx="78" ry="22" fill="${st.hull}"/>`;
            s += '<ellipse cx="170" cy="42" rx="22" ry="16" fill="#9fd6ea" opacity=".85"/><ellipse cx="166" cy="37" rx="10" ry="5" fill="#fff" opacity=".45"/>';
            s += `<rect x="94" y="16" width="36" height="10" rx="4" fill="${st.hull}"/><rect x="98" y="12" width="4" height="6" fill="#232a33"/>`;
            s += '<path d="M42,44 L26,30 L26,58 Z" fill="#232a33"/><circle cx="72" cy="62" r="5" fill="#232a33"/><circle cx="150" cy="64" r="5" fill="#232a33"/>';
            s += '<circle cx="110" cy="44" r="4" fill="#232a33"/><circle cx="130" cy="44" r="4" fill="#232a33"/>';
        } else {
            const long = st.kind === 'speed';
            s += `<path d="M24,40 L${long ? 196 : 188},40 Q${long ? 226 : 214},42 ${long ? 230 : 218},48 L${long ? 212 : 204},64 L40,64 Q26,62 24,52 Z" fill="${st.hull}"/>`;
            s += `<path d="M28,52 L${long ? 222 : 212},52" stroke="${st.deck}" stroke-width="4"/>`;
            s += `<path d="M${long ? 120 : 100},40 L${long ? 140 : 118},26 L${long ? 172 : 150},26 L${long ? 184 : 162},40 Z" fill="#0d1318" opacity=".85"/>`;
            if (!long) s += `<rect x="60" y="30" width="30" height="10" rx="3" fill="${st.deck}"/>`;
            s += '<rect x="18" y="38" width="10" height="16" rx="2" fill="#232a33"/>';
        }
        return `<svg viewBox="0 0 240 80" xmlns="http://www.w3.org/2000/svg">${water}${s}</svg>`;
    }

    // a small sonar screen per site: deterministic blips so it doesn't jump between renders
    function sonar(zone, hot) {
        let h = 0;
        for (const ch of zone.id) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
        const rnd = () => { h = (h * 1103515245 + 12345) >>> 0; return (h >>> 8) / 16777216; };
        let blips = '';
        const n = 5 + (zone.containers || []).length * 2;
        for (let i = 0; i < n; i++) {
            const a = rnd() * Math.PI * 2, r = Math.sqrt(rnd()) * 40;
            blips += `<circle class="blip ${i < hot ? 'hot' : ''}" cx="${(50 + Math.cos(a) * r).toFixed(1)}" cy="${(50 + Math.sin(a) * r).toFixed(1)}" r="${i < hot ? 2.8 : 1.9}" opacity="${(0.45 + rnd() * 0.55).toFixed(2)}"/>`;
        }
        const ang = rnd() * 360;
        return `<svg class="sonar" viewBox="0 0 100 100">
            <defs><radialGradient id="sweep" cx="50" cy="50" r="50" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="rgba(79,179,217,.35)"/><stop offset="1" stop-color="rgba(79,179,217,0)"/></radialGradient></defs>
            <circle class="sr" cx="50" cy="50" r="16"/><circle class="sr" cx="50" cy="50" r="31"/><circle class="sr" cx="50" cy="50" r="46"/>
            <path class="sr" d="M50 4V96M4 50H96"/>
            <path class="sweep" d="M50 50 L50 2 A48 48 0 0 1 91.6 26 Z" transform="rotate(${ang.toFixed(0)} 50 50)"/>
            ${blips}</svg>`;
    }

    /* ------------------------------------------------------------ data from Lua */
    // an empty Lua table can arrive as {} instead of [], so every list is normalised once
    const arr = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));

    function normalise(d) {
        ['levels', 'zones', 'contracts', 'tanks', 'shopItems', 'boats', 'rewards', 'myTanks', 'sell', 'recent'].forEach((k) => { d[k] = arr(d[k]); });
        d.zones.forEach((z) => { z.containers = arr(z.containers); });
        d.contracts.forEach((c) => { c.targets = c.targets ? arr(c.targets) : null; });
        d.rewards.forEach((r) => { r.items = arr(r.items); });
        if (d.contract && d.contract.targets) d.contract.targets = arr(d.contract.targets);
        d.containers = d.containers || {};
        return d;
    }

    /* ------------------------------------------------------------ state */
    const state = {
        data: null,
        tab: 'contracts',
        site: null,
        contract: null,
        shopSeg: 'buy',
        boat: null,
        launchSite: null,
        busy: null,        // key of the button waiting on the server
        flash: null,       // { ok, text }
        cancelArmed: false,
        board: { period: 'week', sort: 'containers', result: null, loading: false },
        clockSkew: 0,
    };

    const diver = () => state.data.diver;
    const siteById = (id) => state.data.zones.find((z) => z.id === id);
    const contractById = (id) => state.data.contracts.find((c) => c.id === id);
    const boatByModel = (m) => state.data.boats.find((b) => b.model === m);
    const unlocked = (lvl) => lvl <= diver().level;
    const serverNow = () => Date.now() / 1000 + state.clockSkew;
    const readyRewards = () => state.data.rewards.filter((r) => r.state === 'ready').length;

    function bestTank() {
        let best = null;
        for (const t of state.data.myTanks) {
            if (t.air <= 0) continue;
            if (!best || t.tier > best.tier || (t.tier === best.tier && t.air > best.air)) best = t;
        }
        return best;
    }

    function pickDefaults() {
        const d = state.data;
        const okSite = (id) => { const z = siteById(id); return z && unlocked(z.level); };
        if (!okSite(state.site)) {
            const saved = store.get('site');
            state.site = okSite(saved) ? saved : (d.zones.filter((z) => unlocked(z.level)).pop() || d.zones[0]).id;
        }
        const inSite = d.contracts.filter((c) => c.zone === state.site);
        if (!inSite.some((c) => c.id === state.contract)) state.contract = inSite.length ? inSite[0].id : null;

        const okBoat = (m) => { const b = boatByModel(m); return b && unlocked(b.level); };
        if (!okBoat(state.boat)) {
            const saved = store.get('boat');
            state.boat = okBoat(saved) ? saved : (d.boats.filter((b) => unlocked(b.level)).pop() || d.boats[0]).model;
        }
        if (d.contract) state.launchSite = d.contract.zone;
        if (!okSite(state.launchSite)) state.launchSite = state.site;
        if (!d.atShop && (state.tab === 'shop')) state.shopSeg = 'refill';
    }

    function contractEstimate(c) {
        const d = state.data;
        const zone = siteById(c.zone);
        const mult = diver().payMult;
        const pay = Math.round(c.pay * mult);
        const bonus = Math.round(c.bonus * mult);
        const kinds = c.targets && c.targets.length ? c.targets : null;
        let per = 0;
        if (kinds) per = kinds.reduce((a, k) => a + ((d.containers[k] || {}).xp || 0), 0) / kinds.length;
        else per = 14;
        const xp = Math.round(per * c.goal + c.xp * mult);
        return { pay, bonus, total: pay * c.goal + bonus, xp, zone };
    }

    const targetText = (c) => (c.targets && c.targets.length
        ? c.targets.map((k) => (state.data.containers[k] || { label: k }).label).join(' / ')
        : 'any container');

    /* ------------------------------------------------------------ render: chrome */
    function renderChrome() {
        const d = state.data;
        const w = diver();
        $('company').textContent = d.shop.label;
        $('company-sub').textContent = d.atShop ? 'Dive shop counter' : 'Dive terminal';
        const pct = w.nextXp ? clamp((w.xp - w.levelXp) / (w.nextXp - w.levelXp), 0, 1) * 100 : 100;
        $('driver-chip').innerHTML = `
            <div class="driver-meta">
                <b>${esc(w.name)}</b>
                <div class="lvl"><span><em>LV ${w.level}</em> · ${esc(w.title)}</span><span class="num">${w.nextXp ? int(w.xp) + ' / ' + int(w.nextXp) : 'MAX'}</span></div>
                <div class="xpbar"><i style="width:${pct}%"></i></div>
            </div>
            <div class="avatar">${esc(initials(w.name))}</div>`;

        const tabs = [
            ['contracts', 'Contracts', ICON.contracts, d.contract ? '' : null],
            ['shop', 'Shop', ICON.shop, null],
            ['boats', 'Boats', ICON.boat, d.rental ? '' : null],
            ['board', 'Scoreboard', ICON.board, null],
            ['diver', 'Diver', ICON.diver, null],
            ['rewards', 'Rewards', ICON.rewards, readyRewards() ? 'amber' : null],
        ];
        $('rail').innerHTML = tabs.map(([id, label, icon, dot]) => `
            <button class="tab ${state.tab === id ? 'active' : ''}" data-tab="${id}">
                ${icon}<span>${label}</span>
                ${dot !== null ? `<i class="dot ${dot}"></i>` : ''}
            </button>`).join('');

        document.querySelectorAll('.view').forEach((v) => { v.hidden = v.dataset.view !== state.tab; });
        $('body').classList.toggle('wide', !['contracts', 'boats'].includes(state.tab));

        const banner = $('banner');
        banner.hidden = d.allowed;
        banner.textContent = d.allowed ? '' : (d.reason || 'You cannot dive for the company right now.');

        const flash = $('flash');
        flash.hidden = !state.flash;
        if (state.flash) {
            flash.className = 'flash ' + (state.flash.ok ? 'ok' : 'bad');
            flash.textContent = state.flash.text;
        }
    }

    /* ------------------------------------------------------------ render: contracts */
    function renderContracts() {
        const d = state.data;
        const el = $('view-contracts');

        if (d.contract) {
            const c = d.contract;
            const C = 2 * Math.PI * 96, C2 = 2 * Math.PI * 80;
            const def = contractById(c.id) || { time: 30 };
            const left = Math.max(0, c.expires - serverNow());
            const off = C * (1 - clamp(c.done / c.goal, 0, 1));
            const off2 = C2 * (1 - clamp(left / (def.time * 60), 0, 1));
            el.innerHTML = `
                <div class="view-head">
                    <div><h2>Contract in progress</h2><p>${esc(c.zoneLabel)} · find ${esc(c.targets ? c.targets.join(' / ') : 'any container')}</p></div>
                    <div class="head-actions"><button class="btn-sm sea" data-gps="${c.coords.x},${c.coords.y}" data-gps-label="${esc(c.zoneLabel)}">${ICON.pin}GPS to site</button></div>
                </div>
                <div class="card active-shift">
                    <div class="ring">
                        <svg viewBox="0 0 220 220">
                            <circle class="track" cx="110" cy="110" r="96" fill="none" stroke-width="12"/>
                            <circle class="fill" cx="110" cy="110" r="96" fill="none" stroke-width="12" stroke-dasharray="${C.toFixed(1)}" stroke-dashoffset="${off.toFixed(1)}"/>
                            <circle class="track" cx="110" cy="110" r="80" fill="none" stroke-width="4"/>
                            <circle class="timer" id="ring-timer" cx="110" cy="110" r="80" fill="none" stroke-width="4" stroke-dasharray="${C2.toFixed(1)}" stroke-dashoffset="${off2.toFixed(1)}" data-c2="${C2}" data-total="${def.time * 60}"/>
                        </svg>
                        <div class="label"><div><b>${c.done}<span style="color:var(--ink-500)">/${c.goal}</span></b><small>found</small><span class="timer-big" data-left="${c.expires}">${mmss(left)}</span></div></div>
                    </div>
                    <div>
                        <span class="live">On contract</span>
                        <h3><span class="code" style="--c:${esc(c.color)}">${esc(c.code)}</span> ${esc(c.label)}</h3>
                        <p class="t-sub">${esc(c.zoneLabel)} · ${money(c.pay)} for each find, ${money(c.bonus)} when all ${c.goal} are up</p>
                        <div class="kpis">
                            <div class="kpi"><span>Earned</span><b>${money(c.earned)}</b></div>
                            <div class="kpi"><span>XP so far</span><b>+${int(c.xp)}</b></div>
                            <div class="kpi"><span>Time left</span><b data-left="${c.expires}">${mmss(left)}</b></div>
                        </div>
                        <div class="hint">${ICON.info}<div>Dive inside the <b>orange circle</b> on the map. Contract finds glow <b>amber</b> and have a marker above them; third-eye one to open it. Everything else still has loot. Watch your air - below your tank's depth rating it drains <b>twice as fast</b>.</div></div>
                    </div>
                </div>`;
            return;
        }

        const sites = d.zones.map((z) => {
            const count = d.contracts.filter((c) => c.zone === z.id).length;
            const open = unlocked(z.level);
            return `
            <button class="card route-card ${z.id === state.site ? 'selected' : ''} ${open ? '' : 'locked'}" data-site="${esc(z.id)}" ${open ? '' : 'disabled'}>
                <span class="check">${ICON.check}</span>
                <span class="code" style="--c:${esc(z.color)}">${esc(z.code)}</span>
                ${sonar(z, open ? 2 : 0)}
                <div class="route-info">
                    <h3>${esc(z.label)}</h3>
                    <div class="area">${esc(z.area)}</div>
                    <div class="chips">
                        ${open ? `<span class="chip sea">~${z.depth} m</span>` : `<span class="chip lock-note">${ICON.lock} Level ${z.level}</span>`}
                        <span class="chip">${count} contracts</span>
                        <span class="chip">tank T${z.tier}+</span>
                    </div>
                    <div class="desc">${esc(z.blurb)}</div>
                </div>
            </button>`;
        }).join('');

        const site = siteById(state.site);
        const list = d.contracts.filter((c) => c.zone === state.site).map((c) => {
            const e = contractEstimate(c);
            return `
            <button class="card contract-card ${c.id === state.contract ? 'selected' : ''}" data-contract="${esc(c.id)}">
                <span class="check">${ICON.check}</span>
                <h3>${esc(c.label)}</h3>
                <div class="goal"><b>${c.goal}</b><span>× ${esc(targetText(c))}</span></div>
                <div class="chips">
                    <span class="chip amber">${money(e.total)}</span>
                    <span class="chip">${c.time} min</span>
                    <span class="chip">~${int(e.xp)} XP</span>
                </div>
                <div class="desc">${esc(c.blurb)}</div>
            </button>`;
        }).join('');

        el.innerHTML = `
            <div class="view-head">
                <div><h2>Contracts</h2><p>Pick a dive site and a job. You're paid for every find the moment you open it, and a bonus when the job is done.</p></div>
            </div>
            <div class="route-grid">${sites}</div>
            <div class="section-label">Contracts · ${esc(site ? site.label : '')}</div>
            <div class="contract-grid">${list || '<div class="card empty-state">No contracts at this site.</div>'}</div>`;
    }

    function renderContractTicket() {
        const d = state.data;
        const el = $('ticket');

        if (d.contract) {
            const c = d.contract;
            el.innerHTML = `
                <h4>Contract ticket <span class="chip sea">Live</span></h4>
                <div class="t-cab"><div class="cab-art">${sonar(siteById(c.zone) || { id: c.zone, containers: [] }, c.goal - c.done)}</div>
                    <div class="t-title">${esc(c.label)}</div><div class="t-sub">${esc(c.zoneLabel)}</div></div>
                <div class="t-rows">
                    <div class="t-row"><span>Found</span><b class="num">${c.done} / ${c.goal}</b></div>
                    <div class="t-row"><span>Per find</span><b class="num">${money(c.pay)}</b></div>
                    <div class="t-row"><span>Completion bonus</span><b class="num">${money(c.bonus)}</b></div>
                    <div class="t-row hl"><span>Earned so far</span><b class="num">${money(c.earned)}</b></div>
                    <div class="t-row"><span>Time left</span><b class="num" data-left="${c.expires}">${mmss(c.expires - serverNow())}</b></div>
                </div>
                <p class="t-note">Cancelling keeps what you have been paid, but there is <b>no bonus</b>. If the timer runs out the contract fails the same way.</p>
                <div class="spacer"></div>
                <button class="btn btn-danger ${state.cancelArmed ? 'armed' : ''} ${state.busy === 'cancel' ? 'loading' : ''}" data-action="cancel">${state.cancelArmed ? 'Tap again to cancel' : 'Cancel contract'}</button>`;
            return;
        }

        const c = contractById(state.contract);
        const site = siteById(state.site);
        if (!c || !site) {
            el.innerHTML = '<h4>Contract ticket</h4><p class="t-note">Pick a site and a contract.</p>';
            return;
        }
        const e = contractEstimate(c);
        const best = bestTank();
        const tankChip = best
            ? `<span class="chip ${best.tier >= site.tier ? 'good' : 'bad'}">${esc(best.label)} · ${Math.round(best.air / best.max * 100)}%</span>`
            : '<span class="chip bad">No tank</span>';

        let reason = '';
        if (!d.allowed) reason = ' ';
        else if (!unlocked(site.level)) reason = `Site unlocks at level ${site.level}`;
        else if (d.cooldown > 0) reason = `Next contract in ${d.cooldown}s`;
        const can = !reason && state.busy !== 'accept';

        el.innerHTML = `
            <h4>Contract ticket <span class="chip">Pay ×${diver().payMult.toFixed(2)}</span></h4>
            <div class="t-cab"><div class="cab-art">${sonar(site, c.goal)}</div>
                <div class="t-title">${esc(c.label)}</div><div class="t-sub">${esc(site.label)} · ${c.goal} × ${esc(targetText(c))}</div></div>
            <div class="t-rows">
                <div class="t-row"><span>Per find</span><b class="num">${money(e.pay)}</b></div>
                <div class="t-row"><span>Completion bonus</span><b class="num">${money(e.bonus)}</b></div>
                <div class="t-row hl"><span>Total</span><b class="num">${money(e.total)}</b></div>
                <div class="t-row"><span>XP</span><b class="num">~${int(e.xp)}</b></div>
                <div class="t-row"><span>Time limit</span><b class="num">${c.time} min</b></div>
                <div class="t-row"><span>Depth · tank</span><b>~${site.depth} m · T${site.tier}+</b></div>
                <div class="t-row"><span>Your best tank</span><b>${tankChip}</b></div>
            </div>
            <p class="t-note">Boats launch from <b>${esc(site.launch)}</b>. Loot from every container is yours to keep or sell at the shop.</p>
            <div class="spacer"></div>
            ${reason.trim() ? `<div class="error">${esc(reason)}</div>` : ''}
            <button class="btn btn-primary ${state.busy === 'accept' ? 'loading' : ''}" data-action="accept" ${can ? '' : 'disabled'}>
                ${state.busy === 'accept' ? 'Accepting' : ICON.play + 'Accept contract'}
            </button>`;
    }

    /* ------------------------------------------------------------ render: shop */
    function awayCard() {
        const s = state.data.shop;
        return `<div class="card away">
            <div class="ico">${ICON.shop}</div>
            <div><h3>Visit ${esc(s.label)}</h3>
            <p>Tanks, air refills, boat rentals and selling your finds happen at the counter. Your tablet still shows what you're carrying.</p>
            <button class="btn-sm sea" data-gps="${s.x},${s.y}" data-gps-label="${esc(s.label)}">${ICON.pin}GPS to the shop</button></div>
        </div>`;
    }

    function renderShop() {
        const d = state.data;
        const el = $('view-shop');
        const shop = d.atShop;
        const segs = shop
            ? [['buy', 'Buy'], ['refill', `Refill · ${d.myTanks.length}`], ['sell', `Sell · ${d.sell.length}`]]
            : [['refill', `My tanks · ${d.myTanks.length}`]];
        if (!segs.some(([k]) => k === state.shopSeg)) state.shopSeg = segs[0][0];

        let content = '';
        if (state.shopSeg === 'buy') {
            const tanks = d.tanks.map((t) => {
                const open = unlocked(t.level);
                const owned = d.myTanks.filter((m) => m.item === t.item).length;
                const btn = !t.exists
                    ? '<span class="chip">Not stocked</span>'
                    : open
                        ? `<button class="btn-sm primary ${state.busy === 'buy:' + t.item ? 'loading' : ''}" data-buy="${esc(t.item)}">Buy</button>`
                        : `<span class="chip lock-note">${ICON.lock} Lv ${t.level}</span>`;
                return `<div class="card tank-card ${open ? '' : 'locked'}">
                    <div class="tank-art">${tankSvg(t.tier)}</div>
                    <div class="make">T${t.tier} · ${esc(t.tag)}</div>
                    <h3>${esc(t.label)}</h3>
                    <div class="kv"><span>Air</span><b>${mmss(t.air)}</b></div>
                    <div class="kv"><span>Rated to</span><b>${t.rating} m</b></div>
                    <div class="kv"><span>Refill</span><b>${money(t.refill)}</b></div>
                    <div class="kv"><span>You own</span><b>${owned}</b></div>
                    <div class="foot"><span class="price ${open ? '' : 'dim'}">${money(t.price)}</span>${btn}</div>
                </div>`;
            }).join('');
            const extras = d.shopItems.filter((i) => i.exists).map((i) => {
                const open = unlocked(i.level);
                return `<div class="card extra-card">
                    <div class="icon-tile">${ICON.tablet}</div>
                    <div><b>${esc(i.label)}</b><small>${esc(i.blurb || '')}</small></div>
                    <div class="buy"><span class="price">${money(i.price)}</span>${open
                        ? `<button class="btn-sm primary ${state.busy === 'buy:' + i.item ? 'loading' : ''}" data-buy="${esc(i.item)}">Buy</button>`
                        : `<span class="chip lock-note">${ICON.lock} Lv ${i.level}</span>`}</div>
                </div>`;
            }).join('');
            content = `<div class="tank-grid">${tanks}</div>
                ${extras ? `<div class="section-label">Equipment</div><div class="shop-extra">${extras}</div>` : ''}
                <p class="t-note">Use a tank from your inventory to put it on (and again to take it off). The air left is saved in the tank. Your level makes every tank last longer: <b>×${diver().airMult.toFixed(2)}</b> drain.</p>`;
        } else if (state.shopSeg === 'refill') {
            const total = d.myTanks.reduce((a, t) => a + t.cost, 0);
            const rows = d.myTanks.map((t) => {
                const pct = t.max ? t.air / t.max * 100 : 0;
                return `<div class="row-tank">
                    <div class="mini">${tankSvg(t.tier)}</div>
                    <div><b>${esc(t.label)}${t.equipped ? '<span class="tag-on">On</span>' : ''}</b><small>slot ${t.slot} · rated ${t.rating} m</small></div>
                    <div><div class="airbar ${pct <= 20 ? 'low' : ''}"><i style="width:${pct.toFixed(1)}%"></i></div>
                        <div class="airline"><span>${mmss(t.air)} / ${mmss(t.max)}</span><span>${Math.round(pct)}%</span></div></div>
                    <div class="r">${t.cost > 0 ? money(t.cost) : '-'}</div>
                    <div class="r">${shop
                        ? `<button class="btn-sm ${t.cost > 0 ? 'sea' : ''} ${state.busy === 'refill:' + t.slot ? 'loading' : ''}" data-refill="${t.slot}" ${t.cost > 0 ? '' : 'disabled'}>${t.cost > 0 ? 'Refill' : 'Full'}</button>`
                        : `<span class="chip ${pct >= 100 ? 'good' : pct > 20 ? 'sea' : 'bad'}">${pct >= 100 ? 'Full' : pct > 20 ? 'OK' : pct > 0 ? 'Low' : 'Empty'}</span>`}</div>
                </div>`;
            }).join('');
            content = d.myTanks.length
                ? `<div class="list"><div class="row-tank row-head"><span></span><span>Tank</span><span>Air</span><span class="r">Cost</span><span></span></div>${rows}</div>
                   ${shop ? `<div class="list-foot"><span class="total">Refill everything<b>${money(total)}</b></span>
                   <button class="btn-sm primary ${state.busy === 'refill:all' ? 'loading' : ''}" data-refill="all" ${total > 0 ? '' : 'disabled'}>${ICON.air}Refill all</button></div>` : ''}`
                : `<div class="card empty-state">${ICON.tank}<div>You aren't carrying a tank.${shop ? ' Pick one up in <b>Buy</b>.' : ''}</div></div>`;
        } else {
            const total = d.sell.reduce((a, s) => a + s.price * s.count, 0);
            const rows = d.sell.map((s) => `<div class="row-sell">
                    <div><b>${esc(s.label)}</b><small>${esc(s.name)}</small></div>
                    <div class="r">×${int(s.count)}</div>
                    <div class="r">${money(s.price)}</div>
                    <div class="r hl">${money(s.price * s.count)}</div>
                    <div class="r"><button class="btn-sm ${state.busy === 'sell:' + s.name ? 'loading' : ''}" data-sell="${esc(s.name)}">Sell</button></div>
                </div>`).join('');
            content = d.sell.length
                ? `<div class="list"><div class="row-sell row-head"><span>Item</span><span class="r">Have</span><span class="r">Each</span><span class="r">Total</span><span></span></div>${rows}</div>
                   <div class="list-foot"><span class="total">Sell everything<b>${money(total)}</b></span>
                   <button class="btn-sm primary ${state.busy === 'sell:all' ? 'loading' : ''}" data-sell="all">${ICON.coin}Sell all</button></div>`
                : `<div class="card empty-state">${ICON.box}<div>Nothing to sell. The shop buys metals, plastics, rubber, tech and anything that sparkles.</div></div>`;
        }

        el.innerHTML = `
            <div class="view-head">
                <div><h2>${shop ? 'Dive shop' : 'Gear'}</h2><p>${shop ? 'Five tank tiers. Deeper sites need better tanks, and every tank can be refilled here.' : 'The air in the tanks you are carrying.'}</p></div>
                <div class="seg" id="shop-seg">${segs.map(([k, l]) => `<button class="${state.shopSeg === k ? 'on' : ''}" data-seg="${k}">${l}</button>`).join('')}</div>
            </div>
            ${shop ? '' : awayCard()}
            ${content}`;
    }

    /* ------------------------------------------------------------ render: boats */
    function renderBoats() {
        const d = state.data;
        const el = $('view-boats');

        let rental = '';
        if (d.rental) {
            const r = d.rental;
            const status = r.lost ? ['bad', 'Lost'] : r.launched ? ['good', 'In the water'] : ['', `Waiting at ${r.launch}`];
            rental = `<div class="card rental-card">
                <div class="cab-art">${boatSvg(r.model)}</div>
                <div>
                    <span class="status-pill ${status[0]}">${esc(status[1])}</span>
                    <h3>${esc(r.label)} <span class="chip">${esc(r.plate)}</span></h3>
                    <p class="t-sub">${r.launched ? 'Third-eye the boat and choose <b>Return rental boat</b> when you are done.' : `Drive to ${esc(r.launch)}. It goes in the water as you arrive.`}</p>
                    <div class="kpis">
                        <div class="kpi"><span>Deposit</span><b>${money(r.deposit)}</b></div>
                        <div class="kpi"><span>Fuel</span><b>${r.fuel != null ? Math.round(r.fuel) + '%' : '-'}</b></div>
                        <div class="kpi"><span>Hull</span><b>${r.health != null ? r.health + '%' : '-'}</b></div>
                    </div>
                    ${r.launched ? '' : `<div class="head-actions" style="margin-top:14px"><button class="btn-sm sea" data-gps="${r.lx},${r.ly}" data-gps-label="${esc(r.launch)}">${ICON.pin}GPS to launch</button></div>`}
                </div>
            </div>`;
        }

        const boats = d.boats.map((b) => {
            const open = unlocked(b.level);
            const pips = (n) => `<div class="pips">${[1, 2, 3, 4, 5].map((i) => `<i class="${i <= n ? 'on' : ''}"></i>`).join('')}</div>`;
            return `<button class="card cab-card ${b.model === state.boat ? 'selected' : ''} ${open ? '' : 'locked'}" data-boat="${esc(b.model)}" ${open ? '' : 'disabled'}>
                <span class="check">${ICON.check}</span>
                <div class="cab-art">${boatSvg(b.model)}</div>
                <div class="make">${esc(b.tag)}</div>
                <h3>${esc(b.label)}</h3>
                <div class="desc">${esc(b.blurb)}</div>
                <div class="stats">
                    <div class="stat"><span>Speed</span>${pips(b.speed)}</div>
                    <div class="stat"><span>Seats</span>${pips(Math.min(5, b.seats))}</div>
                </div>
                <div class="row">${open ? `<span class="mult">${money(b.fee)}<small>+ ${money(b.deposit)} dep.</small></span>` : `<span class="lock-note">${ICON.lock} Level ${b.level}</span>`}</div>
            </button>`;
        }).join('');

        const sites = d.zones.map((z) => `<button class="${z.id === state.launchSite ? 'on' : ''}" data-launch="${esc(z.id)}" ${unlocked(z.level) ? '' : 'disabled'}>
            <span class="code" style="--c:${esc(z.color)}">${esc(z.code)}</span>${esc(z.label)}</button>`).join('');

        el.innerHTML = `
            <div class="view-head"><div><h2>Boats</h2><p>Rent at the counter; your boat waits at the launch for the site you pick. The deposit comes back when you return it.</p></div></div>
            ${d.atShop ? '' : awayCard()}
            ${rental}
            ${d.rental ? '' : `<div class="boat-grid">${boats}</div>
            <div class="section-label">Launch for</div>
            <div class="site-pick">${sites}</div>`}`;
    }

    function renderBoatTicket() {
        const d = state.data;
        const el = $('ticket');
        const fuelLabel = `Fuel: ${d.fuel}`;

        if (d.rental) {
            const r = d.rental;
            let action = '';
            if (!r.launched) {
                action = `<button class="btn btn-danger ${state.busy === 'return' ? 'loading' : ''}" data-action="return" ${d.atShop ? '' : 'disabled'}>${ICON.return}Cancel rental</button>`;
            } else if (r.lost) {
                action = `<button class="btn btn-danger ${state.busy === 'return' ? 'loading' : ''}" data-action="return">Clear lost rental</button>`;
            } else {
                action = `<button class="btn btn-primary ${state.busy === 'return' ? 'loading' : ''}" data-action="return">${ICON.return}Return boat</button>`;
            }
            el.innerHTML = `
                <h4>Rental <span class="chip">${esc(fuelLabel)}</span></h4>
                <div class="t-cab"><div class="cab-art">${boatSvg(r.model)}</div>
                    <div class="t-title">${esc(r.label)}</div><div class="t-sub">${esc(r.plate)} · ${esc(r.launch)}</div></div>
                <div class="t-rows">
                    <div class="t-row"><span>Fee paid</span><b class="num">${money(r.fee)}</b></div>
                    <div class="t-row hl"><span>Deposit</span><b class="num">${money(r.deposit)}</b></div>
                    <div class="t-row"><span>Fuel</span><b class="num">${r.fuel != null ? Math.round(r.fuel) + '%' : '-'}</b></div>
                    <div class="t-row"><span>Hull</span><b class="num">${r.health != null ? r.health + '%' : '-'}</b></div>
                </div>
                <p class="t-note">${r.launched
                    ? `Stand next to the boat to return it. Damage comes off the deposit, and fuel used is charged at <b>${money(d.fuelPrice)}</b> per 1%.`
                    : 'Not launched yet: cancel at the counter for a <b>full refund</b>.'}</p>
                <div class="spacer"></div>
                ${action}`;
            return;
        }

        const b = boatByModel(state.boat);
        const site = siteById(state.launchSite);
        let reason = '';
        if (!d.allowed) reason = ' ';
        else if (!d.atShop) reason = 'Rent at the dive shop counter';
        else if (!b || !unlocked(b.level)) reason = 'Boat is locked';
        else if (!site || !unlocked(site.level)) reason = 'Pick a site you have unlocked';
        el.innerHTML = `
            <h4>Rental ticket <span class="chip">${esc(fuelLabel)}</span></h4>
            <div class="t-cab"><div class="cab-art">${b ? boatSvg(b.model) : ''}</div>
                <div class="t-title">${b ? esc(b.label) : 'No boat selected'}</div>
                <div class="t-sub">${site ? 'Launch: ' + esc(site.launch) : 'Pick a site'}</div></div>
            <div class="t-rows">
                <div class="t-row"><span>Rental fee</span><b class="num">${b ? money(b.fee) : '-'}</b></div>
                <div class="t-row"><span>Deposit (back on return)</span><b class="num">${b ? money(b.deposit) : '-'}</b></div>
                <div class="t-row hl"><span>Due now</span><b class="num">${b ? money(b.fee + b.deposit) : '-'}</b></div>
                <div class="t-row"><span>For site</span><b>${site ? esc(site.label) : '-'}</b></div>
            </div>
            <p class="t-note">Leaves with a full tank. Fuel used is taken from the deposit at <b>${money(d.fuelPrice)}</b> per 1%, and so is hull damage. Paid from cash first, then bank.</p>
            <div class="spacer"></div>
            ${reason.trim() ? `<div class="error">${esc(reason)}</div>` : ''}
            <button class="btn btn-primary ${state.busy === 'rent' ? 'loading' : ''}" data-action="rent" ${reason ? 'disabled' : ''}>${ICON.boat}Rent boat</button>`;
    }

    /* ------------------------------------------------------------ render: board */
    const SORTS = { containers: 'Finds', earnings: 'Earnings', contracts: 'Contracts', xp: 'XP' };

    function renderBoard() {
        const el = $('view-board');
        const b = state.board;
        const fmt = (row, key) => (key === 'earnings' ? money(row.earnings) : int(row[key]));
        const seg = (key, opts) => `<div class="seg" id="board-${key}">${opts.map(([v, l]) => `<button class="${b[key] === v ? 'on' : ''}" data-${key}="${v}">${l}</button>`).join('')}</div>`;
        const second = b.sort === 'containers' ? 'earnings' : b.sort;

        let reset = '';
        if (b.period === 'week' && b.result && b.result.resetsIn > 0) {
            const s = b.result.resetsIn;
            const dd = Math.floor(s / 86400), hh = Math.floor((s % 86400) / 3600), mm = Math.floor((s % 3600) / 60);
            reset = `Resets in ${dd ? dd + 'd ' : ''}${hh}h ${dd ? '' : mm + 'm'}`;
        }

        let content;
        if (b.loading && !b.result) {
            content = `<div class="table">${'<div class="skeleton"></div>'.repeat(8)}</div>`;
        } else if (!b.result || !b.result.rows.length) {
            content = `<div class="card empty-state">${ICON.board}<div>${b.period === 'week' ? 'Nobody has been down this week yet. The top spot is open.' : 'Nobody has dived yet.'}</div></div>`;
        } else {
            const rows = b.result.rows;
            const pod = (row, place) => row
                ? `<div class="card pod ${place === 1 ? 'first' : ''} ${row.me ? 'is-me' : ''}"><div class="medal m${place}">${place}</div>
                    <div class="name">${esc(row.name)}</div><div class="sub">Level ${row.level} · deepest ${int(row.deepest)} m</div>
                    <div class="value">${fmt(row, b.sort)}</div></div>`
                : `<div class="card pod empty"><div class="medal m${place}">${place}</div><div class="name">Open</div><div class="sub">&nbsp;</div><div class="value">-</div></div>`;
            const line = (row) => `
                <div class="tr ${row.me ? 'me' : ''}">
                    <span class="rank">#${row.rank}</span>
                    <span class="who">${esc(row.name)}${row.me ? '<small>you</small>' : ''}</span>
                    <span class="r num">LV ${row.level}</span>
                    <span class="r num ${b.sort === 'containers' ? 'sorted' : ''}">${int(row.containers)}</span>
                    <span class="r num ${b.sort !== 'containers' ? 'sorted' : ''}">${fmt(row, second)}${second === 'xp' ? ' XP' : ''}</span>
                </div>`;
            const rest = rows.slice(3);
            const mine = b.result.me;
            const meVisible = rows.some((r) => r.me);
            content = `
                <div class="podium">${pod(rows[1], 2)}${pod(rows[0], 1)}${pod(rows[2], 3)}</div>
                ${rest.length ? `<div class="table">
                    <div class="tr head"><span>Rank</span><span>Diver</span><span class="r">Level</span><span class="r">Finds</span><span class="r">${SORTS[second]}</span></div>
                    ${rest.map(line).join('')}
                </div>` : ''}
                ${mine && !meVisible ? `<div class="table pinned">${line(mine)}</div>` : ''}
                ${!mine ? '<p class="t-note" style="text-align:center">You are not on this board yet. One find gets you on it.</p>' : ''}`;
        }

        el.innerHTML = `
            <div class="view-head">
                <div><h2>Scoreboard</h2><p id="board-sub">Ranked by ${SORTS[b.sort].toLowerCase()}${reset ? ' · ' + reset : ''}</p></div>
                <div class="board-controls">
                    ${seg('period', [['week', 'This week'], ['all', 'All time']])}
                    ${seg('sort', Object.entries(SORTS))}
                </div>
            </div>
            ${content}`;
    }

    async function loadBoard() {
        const b = state.board;
        b.loading = true;
        b.result = null;
        renderBoard();
        const want = b.period + b.sort;
        const res = await post('scoreboard', { period: b.period, sort: b.sort });
        if (want !== b.period + b.sort) return;
        b.loading = false;
        b.result = res && res.rows ? res : { rows: [], me: null };
        if (state.tab === 'board') renderBoard();
    }

    /* ------------------------------------------------------------ render: diver */
    function renderDiver() {
        const d = state.data;
        const el = $('view-diver');
        const w = diver();
        const pct = w.nextXp ? clamp((w.xp - w.levelXp) / (w.nextXp - w.levelXp), 0, 1) * 100 : 100;
        const rungs = d.levels.map((l) => {
            const cls = l.level < w.level ? 'done' : l.level === w.level ? 'current' : 'locked';
            const tone = cls === 'locked' ? '' : null;
            const chips = [
                ...d.tanks.filter((t) => t.level === l.level).map((t) => `<span class="chip ${tone ?? 'amber'}">${ICON.tank}${esc(t.label)}</span>`),
                ...d.boats.filter((b) => b.level === l.level).map((b) => `<span class="chip ${tone ?? 'sea'}">${ICON.boat}${esc(b.label)}</span>`),
                ...d.zones.filter((z) => z.level === l.level).map((z) => `<span class="chip ${tone ?? 'good'}">${ICON.site}${esc(z.label)}</span>`),
            ].join('');
            return `<div class="card rung ${cls}">
                <div class="n">${cls === 'done' ? ICON.check : l.level}</div>
                <div class="t"><b>${esc(l.title)}</b><small>${int(l.xp)} XP · pay ×${l.payMult.toFixed(2)} · air ×${l.airMult.toFixed(2)}</small></div>
                <div class="unlocks">${chips || '<span class="chip">-</span>'}</div>
            </div>`;
        }).join('');

        const recent = (d.recent || []).map((r) => {
            const z = siteById(r.zone) || { code: '--', color: '#56606c', label: r.zone || 'Open water' };
            const c = contractById(r.contract);
            const title = r.kind === 'contract' ? (c ? c.label : r.contract) : 'Free dive';
            const chip = r.kind === 'contract'
                ? (r.completed ? '<span class="chip good">Complete</span>' : '<span class="chip">Not finished</span>')
                : '<span class="chip sea">Free dive</span>';
            const detail = r.kind === 'contract' ? `${r.containers} opened · goal ${r.goal}` : `${r.containers} opened`;
            return `<div class="card shift-row">
                <span class="code" style="--c:${esc(z.color)}">${esc(z.code)}</span>
                <div><b>${esc(title)} ${chip}</b>
                <small>${esc(z.label)} · ${detail} · ${int(r.depth)} m deep · ${duration(r.duration)} · ${ago(r.ended, d.now)}</small></div>
                <div class="r"><b>+${money(r.earnings)}</b><small>+${int(r.xp)} XP</small></div>
            </div>`;
        }).join('');

        el.innerHTML = `
            <div class="view-head"><div><h2>Diver</h2><p>Every find earns XP, contract finds the most. Levels unlock deeper sites, better tanks and faster boats, and make your air last longer.</p></div></div>
            <div class="driver-grid">
                <div class="card profile">
                    <div class="lvl-badge"><div><b>${w.level}</b><small>LEVEL</small></div></div>
                    <h3>${esc(w.name)}</h3>
                    <div class="title">${esc(w.title)}</div>
                    <div class="xpbar"><i style="width:${pct}%"></i></div>
                    <div class="xp-line"><span class="num">${int(w.xp)} XP</span><span>${w.nextXp ? int(w.nextXp - w.xp) + ' XP to ' + esc(w.nextTitle) : 'Top level'}</span></div>
                    <div class="stat-grid">
                        <div class="kpi"><span>Finds</span><b>${int(w.containers)}</b></div>
                        <div class="kpi"><span>Contracts</span><b>${int(w.contracts)}</b></div>
                        <div class="kpi"><span>Earned</span><b>${money(w.earnings)}</b></div>
                        <div class="kpi"><span>Deepest</span><b>${int(w.deepest)} m</b></div>
                    </div>
                </div>
                <div>
                    <div class="ladder">${rungs}</div>
                    <div class="recent">
                        <div class="section-label">Recent dives</div>
                        ${recent || `<div class="card empty-state" style="padding:22px">${ICON.site}<div>No dives yet. The reef is waiting.</div></div>`}
                    </div>
                </div>
            </div>`;
    }

    /* ------------------------------------------------------------ render: rewards */
    function renderRewards() {
        const d = state.data;
        const el = $('view-rewards');
        const ready = readyRewards();
        const rows = d.rewards.map((r) => {
            const lvl = d.levels.find((l) => l.level === r.level) || { title: '' };
            const gifts = [
                r.money > 0 ? `<span class="chip cash">${money(r.money)}</span>` : '',
                ...r.items.map((i) => `<span class="chip ${r.state === 'locked' ? '' : 'amber'}">${ICON.box}${i.count > 1 ? i.count + '× ' : ''}${esc(i.label)}</span>`),
            ].join('');
            let act;
            if (r.state === 'ready') act = `<button class="btn-sm primary ${state.busy === 'claim:' + r.level ? 'loading' : ''}" data-claim="${r.level}">${ICON.rewards}Claim</button>`;
            else if (r.state === 'claimed') act = `<button class="btn-sm good" disabled>${ICON.check}Claimed</button>`;
            else act = `<button class="btn-sm" disabled>${ICON.lock}Level ${r.level}</button>`;
            return `<div class="card reward ${r.state}">
                <div class="lv">${r.state === 'claimed' ? ICON.check : `<div>${r.level}<small>LEVEL</small></div>`}</div>
                <div><h3>${esc(r.label)}</h3><div class="who">${esc(lvl.title)} · ${int(lvl.xp)} XP</div></div>
                <div class="gifts">${gifts || '<span class="chip">-</span>'}</div>
                <div class="act">${act}</div>
            </div>`;
        }).join('');
        el.innerHTML = `
            <div class="view-head"><div><h2>Rewards</h2><p>${ready ? `<span class="ready-count">${ready}</span> ready to claim. ` : ''}Each level pays out once per character. Tanks arrive full.</p></div></div>
            <div class="reward-list">${rows}</div>`;
    }

    function renderAll() {
        if (!state.data) return;
        renderChrome();
        if (state.tab === 'contracts') { renderContracts(); renderContractTicket(); }
        if (state.tab === 'shop') renderShop();
        if (state.tab === 'boats') { renderBoats(); renderBoatTicket(); }
        if (state.tab === 'board') renderBoard();
        if (state.tab === 'diver') renderDiver();
        if (state.tab === 'rewards') renderRewards();
    }

    /* ------------------------------------------------------------ tablet open/close (same scale rule as trx_taxijob) */
    function fitTablet() {
        const s = Math.min(window.innerWidth * 0.9 / 1236, window.innerHeight * 0.9 / 776, 1.25);
        $('tablet').style.setProperty('--s', s.toFixed(3));
    }

    let clockTimer = null;
    function tick() {
        $('clock').textContent = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
        const now = serverNow();
        document.querySelectorAll('[data-left]').forEach((n) => { n.textContent = mmss(Number(n.dataset.left) - now); });
        const ring = $('ring-timer');
        if (ring) {
            const left = Math.max(0, Number(state.data.contract ? state.data.contract.expires : 0) - now);
            ring.style.strokeDashoffset = (Number(ring.dataset.c2) * (1 - clamp(left / Number(ring.dataset.total), 0, 1))).toFixed(1);
        }
    }

    let flashTimer = null;
    function flash(ok, text) {
        state.flash = text ? { ok, text } : null;
        clearTimeout(flashTimer);
        if (text) {
            flashTimer = setTimeout(() => {
                state.flash = null;
                if (tabletOpen()) renderChrome();
            }, 4500);
        }
    }

    function openTablet(data) {
        const wasOpen = tabletOpen();
        state.data = normalise(data);
        state.clockSkew = (data.now || Date.now() / 1000) - Date.now() / 1000;
        state.busy = null;
        state.cancelArmed = false;
        if (!wasOpen) {
            state.flash = null;
            if (data.atShop && !data.contract && ['contracts', 'board', 'diver'].includes(state.tab)) state.tab = 'shop';
            if (!data.atShop && state.tab === 'shop') state.tab = 'contracts';
            if (data.contract) state.tab = 'contracts';
            if (data.atShop) state.shopSeg = 'buy';
        }
        pickDefaults();
        fitTablet();
        const tablet = $('tablet');
        tablet.classList.remove('closing');
        $('tablet-wrap').hidden = false;
        tick();
        clearInterval(clockTimer);
        clockTimer = setInterval(tick, 1000);
        renderAll();
        if (state.tab === 'board') loadBoard();
    }

    function hideTablet() {
        const wrap = $('tablet-wrap');
        if (wrap.hidden) return;
        clearInterval(clockTimer);
        const tablet = $('tablet');
        tablet.classList.add('closing');
        setTimeout(() => { wrap.hidden = true; tablet.classList.remove('closing'); }, 180);
    }

    function requestClose() {
        hideTablet();
        post('close');
    }

    const tabletOpen = () => !$('tablet-wrap').hidden && !!state.data;

    async function refresh() {
        const data = await post('refresh');
        if (data && tabletOpen()) {
            state.data = normalise(data);
            state.clockSkew = (data.now || Date.now() / 1000) - Date.now() / 1000;
            pickDefaults();
            renderAll();
        }
    }

    // runs one server action: marks the button busy, flashes the answer, refreshes
    async function act(key, name, body) {
        if (state.busy) return null;
        state.busy = key;
        renderAll();
        const res = await post(name, body);
        state.busy = null;
        if (res && (res.message || res.reason)) flash(!!res.ok, res.message || res.reason);
        else if (res && !res.ok) flash(false, 'That did not work. Try again.');
        if (tabletOpen()) await refresh();
        return res;
    }

    /* ------------------------------------------------------------ interaction */
    document.addEventListener('click', async (ev) => {
        const t = ev.target.closest('button');
        if (!t || t.disabled || !state.data) return;

        if (t.dataset.action === 'close') return requestClose();

        if (t.dataset.tab) {
            state.tab = t.dataset.tab;
            state.cancelArmed = false;
            state.flash = null;
            renderAll();
            if (state.tab === 'board') loadBoard();
            return;
        }
        if (t.dataset.site) {
            state.site = t.dataset.site;
            store.set('site', state.site);
            state.contract = null;
            pickDefaults();
            return renderAll();
        }
        if (t.dataset.contract) {
            state.contract = t.dataset.contract;
            return renderAll();
        }
        if (t.dataset.boat) {
            state.boat = t.dataset.boat;
            store.set('boat', state.boat);
            return renderAll();
        }
        if (t.dataset.launch) {
            state.launchSite = t.dataset.launch;
            return renderAll();
        }
        if (t.dataset.seg) {
            state.shopSeg = t.dataset.seg;
            state.flash = null;
            return renderAll();
        }
        if (t.dataset.period || t.dataset.sort) {
            if (t.dataset.period) state.board.period = t.dataset.period;
            if (t.dataset.sort) state.board.sort = t.dataset.sort;
            return loadBoard();
        }
        if (t.dataset.gps) {
            const [x, y] = t.dataset.gps.split(',').map(Number);
            post('gps', { x, y, label: t.dataset.gpsLabel || '' });
            flash(true, `GPS set: ${t.dataset.gpsLabel || 'location'}`);
            return renderChrome();
        }
        if (t.dataset.buy) return act('buy:' + t.dataset.buy, 'buy', { item: t.dataset.buy });
        if (t.dataset.refill) {
            const slot = t.dataset.refill === 'all' ? 'all' : Number(t.dataset.refill);
            return act('refill:' + t.dataset.refill, 'refill', { slot });
        }
        if (t.dataset.sell) return act('sell:' + t.dataset.sell, 'sell', { item: t.dataset.sell });
        if (t.dataset.claim) return act('claim:' + t.dataset.claim, 'claim', { level: Number(t.dataset.claim) });

        switch (t.dataset.action) {
            case 'accept': {
                const res = await act('accept', 'accept', { id: state.contract });
                if (res && res.ok) flash(true, 'Contract accepted - GPS set to the site.');
                return renderAll();
            }
            case 'cancel':
                if (!state.cancelArmed) {
                    state.cancelArmed = true;
                    renderAll();
                    setTimeout(() => { if (state.cancelArmed) { state.cancelArmed = false; if (tabletOpen()) renderAll(); } }, 3000);
                    return undefined;
                }
                state.cancelArmed = false;
                return act('cancel', 'cancel');
            case 'rent':
                return act('rent', 'rent', { model: state.boat, zone: state.launchSite });
            case 'return':
                return act('return', 'returnBoat');
            default:
                return undefined;
        }
    });

    document.addEventListener('keydown', (ev) => {
        if (ev.key === 'Escape' && !$('tablet-wrap').hidden) requestClose();
    });
    window.addEventListener('resize', fitTablet);

    /* ------------------------------------------------------------ dive HUD */
    const GAUGE_C = 2 * Math.PI * 32;

    function hud(data) {
        const el = $('hud');
        if (!data) {
            el.hidden = true;
            return;
        }
        el.hidden = false;
        el.classList.toggle('is-left', data.position === 'left');
        el.style.top = (data.top ?? 18) + '%';

        const z = data.zone, g = data.gear, c = data.contract;
        let top;
        if (z) {
            // the contract section below already says it's a contract; the badge only flags a locked site
            const badge = z.locked ? `<span class="hud-badge bad">Level ${z.locked}</span>` : '';
            top = `<span class="code" style="--c:${esc(z.color)}">${esc(z.code)}</span><span class="hud-site">${esc(z.label)}</span>${badge}`;
        } else if (c) {
            top = `<span class="code" style="--c:${esc(c.color)}">${esc(c.code)}</span><span class="hud-site">Heading to ${esc(c.zone)}</span>`;
        } else {
            top = '<span class="hud-site">Open water</span>';
        }

        let air;
        if (g) {
            const pct = g.max ? clamp(g.air / g.max, 0, 1) : 0;
            const low = pct * 100 <= (data.lowAir ?? 20);
            air = `<div class="hud-air">
                <div class="gauge ${low ? 'low' : ''}"><svg viewBox="0 0 76 76"><circle class="track" cx="38" cy="38" r="32" fill="none" stroke-width="6"/>
                    <circle class="fill" cx="38" cy="38" r="32" fill="none" stroke-width="6" stroke-dasharray="${GAUGE_C.toFixed(1)}" stroke-dashoffset="${(GAUGE_C * (1 - pct)).toFixed(1)}"/></svg>
                    <div class="val"><div><b>${Math.round(pct * 100)}</b><small>AIR %</small></div></div></div>
                <div class="t"><b>${esc(g.label)}</b><div class="time">${mmss(g.air)}</div><small>T${g.tier} · rated to ${g.rating} m</small></div>
            </div>`;
            if (g.air <= 0) air += '<div class="hud-warn">Tank empty · surface now</div>';
            else if (g.over) air += '<div class="hud-warn">Below tank rating · air drains 2×</div>';
        } else {
            air = `<div class="hud-air none"><div class="gauge low"><svg viewBox="0 0 76 76"><circle class="track" cx="38" cy="38" r="32" fill="none" stroke-width="6"/></svg>
                <div class="val"><div><b>-</b><small>NO TANK</small></div></div></div>
                <div class="t"><b>No tank on</b><div class="time">${data.underwater ? 'Holding breath' : 'Use a tank to dive'}</div><small>Buy and refill at the dive shop</small></div></div>`;
        }

        const rating = g ? g.rating : 20;
        const depthPct = clamp(data.depth / (rating * 1.25), 0, 1) * 100;
        const depth = !(g || data.underwater || data.depth > 0.5) ? '' : `<div class="hud-depth"><span class="d">${data.depth.toFixed(1)} m</span>
            <div class="scale"><i class="${g && g.over ? 'over' : ''}" style="width:${depthPct.toFixed(1)}%"></i></div><small>${g ? 'max ' + g.rating + ' m' : 'depth'}</small></div>`;

        let contract = '';
        if (c) {
            const pips = Array.from({ length: c.goal }, (_, i) => `<i class="${i < c.done ? 'on' : ''}"></i>`).join('');
            contract = `<div class="hud-contract">
                <div class="l"><span>Contract</span><span class="${c.left < 120 ? 'low' : ''}">${mmss(c.left)}</span></div>
                <h4>${esc(c.label)}</h4>
                <div class="sub">${c.inZone ? 'You are at the site' : `Head to ${esc(c.zone)}`}</div>
                <div class="hud-pips">${pips}</div>
                <div class="hud-row"><span>Found</span><b>${c.done} / ${c.goal}</b></div>
                <div class="hud-row"><span>Earned</span><b>${money(c.earned)}</b></div>
            </div>`;
        }

        const stats = [];
        if (z && !z.locked) stats.push(`<div><span>Nearby</span><strong>${z.near}</strong></div>`);
        // only worth a second number when some nearby containers don't count
        if (z && !z.locked && z.targets && z.targets !== z.near) stats.push(`<div><span>Contract finds</span><strong><em>${z.targets}</em></strong></div>`);
        if (data.fuel !== false && data.fuel != null) {
            const low = data.fuel < 20;
            stats.push(`<div class="hud-fuel ${low ? 'is-low' : ''}"><span>Boat fuel</span><strong>${Math.round(data.fuel)}%</strong><i><b style="width:${clamp(data.fuel, 0, 100)}%"></b></i></div>`);
        }

        el.innerHTML = `<div class="hud-top">${top}</div>${air}${depth}${contract}${stats.length ? `<div class="hud-stats">${stats.join('')}</div>` : ''}`;
    }

    /* ------------------------------------------------------------ contract summary */
    let summaryTimer = null;
    function summary(s) {
        const el = $('summary');
        if (!s) { el.hidden = true; return; }
        const failed = s.how !== 'complete';
        const eyebrow = { complete: 'Contract complete', failed: 'Contract failed - out of time', cancelled: 'Contract cancelled' }[s.how] || 'Contract ended';
        const levelUp = s.levelAfter > s.levelBefore;
        el.className = 'summary' + (failed ? ' failed' : '');
        el.innerHTML = `
            <div class="eyebrow">${esc(eyebrow)}</div>
            <div class="headline"><span class="code" style="--c:${esc(s.color)}">${esc(s.code)}</span>${esc(s.label)}</div>
            <h2>+${money(s.earned)}</h2>
            <div class="sub">${esc(s.zone)} · paid to your bank</div>
            <div class="summary-grid">
                <div><span>Found</span><b>${s.done} / ${s.goal}</b></div>
                <div><span>Bonus</span><b>${s.bonus ? money(s.bonus) : '-'}</b></div>
                <div><span>XP</span><b>+${int(s.xp)}</b></div>
                <div><span>Opened</span><b>${int(s.containers)}</b></div>
                <div><span>Deepest</span><b>${int(s.depth)} m</b></div>
                <div><span>Time</span><b>${duration(s.duration)}</b></div>
            </div>
            ${levelUp ? `<div class="summary-level">Level ${s.levelAfter} reached · ${esc(s.title)}</div>` : ''}
            <div class="summary-bar" id="summary-bar"></div>`;
        el.hidden = false;
        const bar = $('summary-bar');
        bar.style.transition = 'none';
        bar.style.transform = 'scaleX(1)';
        requestAnimationFrame(() => requestAnimationFrame(() => {
            bar.style.transition = 'transform 10s linear';
            bar.style.transform = 'scaleX(0)';
        }));
        clearTimeout(summaryTimer);
        summaryTimer = setTimeout(() => { el.hidden = true; }, 10000);
    }

    /* ------------------------------------------------------------ messages */
    window.addEventListener('message', (ev) => {
        const msg = ev.data || {};
        switch (msg.action) {
            case 'open': return openTablet(msg.data);
            case 'close': return hideTablet();
            case 'refresh': return tabletOpen() ? refresh() : undefined;
            case 'hud': return hud(msg.data);
            case 'summary': return summary(msg.data);
            default: return undefined;
        }
    });

    async function post(name, body) {
        try {
            const res = await fetch(`https://${RES}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(body || {}),
            });
            return await res.json();
        } catch (e) {
            return window.__mock ? window.__mock(name, body) : null;
        }
    }
})();
