// Runs only in WKContentWorld.defaultClient. No page globals or form values are read.
(() => {
    let enabled = GTIIT_INITIAL_ENABLED;
    const dark = matchMedia('(prefers-color-scheme: dark)');
    const sameHost = (host) => GTIIT_ALLOWED_HOSTS.includes(host);
    // 门户使用 Tailwind 渐变：深色模式下把白底渐变改成黑色，避免顶部仍是亮色。
    const portalDarkCSS = location.hostname === 'students.gtiit.edu.cn' ? [
        'html[data-darkreader-scheme="dark"] .app-bg{background:linear-gradient(75deg,#000 0%,#0b0f14 60%) !important}',
        'html[data-darkreader-scheme="dark"] .from-gray-50{--tw-gradient-from:#000 !important}',
        'html[data-darkreader-scheme="dark"] .from-white{--tw-gradient-from:#000 !important}',
        'html[data-darkreader-scheme="dark"] .bg-gradient-to-b,html[data-darkreader-scheme="dark"] .bg-gradient-to-t{--tw-gradient-to:rgba(0,0,0,0) !important}'
    ].join('') : '';
    const fixes = {
        disableProxyInjection: true,
        disableStyleSheetsProxy: true,
        disableCustomElementRegistryProxy: true,
        ignoreImageAnalysis: ['*'],
        ignoreInlineStyle: ['img', 'video', 'canvas', '[data-gtiit-original-colors]',
            '.reserved', '.unreservable', '.available', '.fc-event', '.fc-bg-event',
            '[class*="qrcode"]', '[class*="captcha"]'],
        invert: [], css: 'img[src*="logo" i], img[alt*="logo" i], .logo img, .navbar-brand img { background-color: #ffffff !important; }' + portalDarkCSS
    };
    const theme = {
        mode: 1, brightness: 100, contrast: 100, sepia: 0,
        darkSchemeBackgroundColor: '#17191c', darkSchemeTextColor: '#e9edf2',
        fontFamily: '', useFont: false, textStroke: 0, styleSystemControls: true
    };
    // Only stylesheets already used by the document, or their CSS imports. Never fetch images/documents.
    DarkReader.setFetchMethod(async (raw) => {
        const url = new URL(raw, document.baseURI);
        if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password) throw Error('CSS URL rejected');
        const links = Array.from(document.querySelectorAll('link[rel~="stylesheet"][href]')).map(e => new URL(e.href, document.baseURI));
        const exact = links.some(link => link.href === url.href);
        const imported = /\.css$/i.test(url.pathname) && (url.origin === location.origin || links.some(link => link.origin === url.origin));
        if (!exact && !imported) throw Error('Only existing stylesheets are allowed');
        const abort = new AbortController();
        const timeout = setTimeout(() => abort.abort(), 6000);
        try {
            const response = await fetch(url.href, {
                credentials: url.origin === location.origin ? 'same-origin' : 'omit',
                mode: 'cors', redirect: 'error', cache: 'force-cache', signal: abort.signal
            });
            if (!response.ok || !(response.headers.get('content-type') || '').toLowerCase().includes('text/css')) throw Error('Invalid CSS response');
            return response;
        } finally { clearTimeout(timeout); }
    });
    const broadcast = () => {
        for (const frame of document.querySelectorAll('iframe,frame')) {
            frame.contentWindow?.postMessage({type: 'gtiit-web-appearance', enabled}, '*');
        }
    };
    const apply = () => {
        try {
            const pdf = (document.contentType || '').toLowerCase().includes('pdf');
            const lock = document.querySelector('meta[name="darkreader-lock"]');
            if (enabled && dark.matches && !pdf && !lock) {
                if (!DarkReader.isEnabled()) DarkReader.enable(theme, fixes);
            } else if (DarkReader.isEnabled()) { DarkReader.disable(); }
        } catch (_) { try { DarkReader.disable(); } catch (_) {} }
    };
    const setEnabled = (value) => { enabled = !!value; apply(); broadcast(); };
    globalThis.__gtiitAppearance = {setEnabled, isEnabled: () => DarkReader.isEnabled()};
    dark.addEventListener('change', apply);
    addEventListener('message', (event) => {
        if (event.source !== parent || parent === self || !event.data || event.data.type !== 'gtiit-web-appearance' || typeof event.data.enabled !== 'boolean') return;
        try { if (sameHost(new URL(event.origin).hostname)) setEnabled(event.data.enabled); } catch (_) {}
    });
    // Native dark themes opt out via the standard lock marker; no forced inversion.
    const ready = () => { apply(); broadcast(); };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready, {once: true});
    else ready();
    apply();
})();