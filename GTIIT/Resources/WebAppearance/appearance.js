// Runs only in WKContentWorld.defaultClient. No page globals or form values are read.
(() => {
    let enabled = GTIIT_INITIAL_ENABLED;
    const dark = matchMedia('(prefers-color-scheme: dark)');
    const sameHost = (host) => GTIIT_ALLOWED_HOSTS.includes(host);
    const pageHost = location.hostname;
    const officialHost = GTIIT_ALLOWED_HOSTS.includes(pageHost);
    const cleanupHost = (typeof GTIIT_CLEANUP_HOSTS === 'undefined' ? GTIIT_ALLOWED_HOSTS : GTIIT_CLEANUP_HOSTS)
        .includes(pageHost);

    // 站点自带的页脚、版权条与商标条。
    const shellCSS = [
        'footer,#footer,.footer,#page-footer,#course-footer,[class*="footer" i],[id*="footer" i],',
        '[class*="copyright" i],[class*="powered-by" i]{display:none !important}',
        'body{overscroll-behavior-y:none;-webkit-tap-highlight-color:transparent}',
        '::-webkit-scrollbar{width:0;height:0}'
    ].join('');

    // 校徽/品牌图：登录页、各站导航与登录卡片里的重复标志。
    const brandingCSS = [
        'img[src*="logo" i],img[src*="emblem" i],',
        'img[alt*="logo" i],img[alt*="GTIIT" i],img[alt*="Guangdong" i],img[alt*="Technion" i],',
        'img[alt*="体育中心"],img[alt*="Sports Center" i],img[class*="logo" i],',
        '#companyLogo,[id*="companyLogo" i],.banner-logo,.company-logo,.logo img,#logo img,',
        '.navbar-brand img,.brand img,svg[class*="logo" i],[class*="school-logo" i],',
        '[class*="brand-logo" i]{display:none !important}'
    ].join('');

    // 门户顶部原本是白色 Tailwind 渐变；直接去掉，让网页背景跟随 App 深浅色。
    const portalCSS = pageHost === 'students.gtiit.edu.cn' ? [
        '.app-bg{background:transparent !important}',
        '.bg-gradient-to-b,.bg-gradient-to-t,.bg-gradient-to-r{background-image:none !important}',
        '.from-white,.from-gray-50{--tw-gradient-from:transparent !important}'
    ].join('') : '';

    // Booked：登录页顶部只剩空的品牌条时直接收起。
    const roomsCSS = pageHost === 'roombooking.gtiit.edu.cn' ? [
        '.navbar .logo,.navbar a.logo,#header .logo,#logo a,a.logo{display:none !important}'
    ].join('') : '';

    // 体育中心：删除顶部 hero 图与标题，保留开放时间、说明和场馆内容。
    const sportsCSS = pageHost === 'gtiit.mike-x.com' ? [
        '.background-fixed{display:none !important}',
        '.main > .header{display:none !important}',
        '.page-package > .fb_component:first-child .fbc_pictureImage{display:none !important}'
    ].join('') : '';

    const installStyles = () => {
        try {
            if (document.getElementById('gtiit-native-chrome')) return;
            const style = document.createElement('style');
            style.id = 'gtiit-native-chrome';
            style.textContent = (officialHost ? shellCSS : '') + brandingCSS + portalCSS + roomsCSS + sportsCSS;
            (document.head || document.documentElement).appendChild(style);
        } catch (_) {}
    };

    const CREDIT_PATTERNS = [
        /©\s*\d{4}/i, /copyright/i, /all rights reserved/i,
        /powered by/i, /twinkle toes/i, /booked scheduler/i,
        /mi-?ke|米客/
    ];
    const hideCreditBlocks = () => {
        if (!officialHost || !document.body) return;
        const docHeight = Math.max(
            document.documentElement.scrollHeight,
            document.body.scrollHeight,
            window.innerHeight
        );
        for (const element of document.querySelectorAll('body *')) {
            if (element.dataset.gtiitHidden) continue;
            if (element.closest('[role="dialog"],[aria-modal="true"],.modal,form,dialog')) continue;
            if (element.children.length > 2) continue;
            const text = (element.textContent || '').trim();
            if (!text || text.length > 160) continue;
            if (!CREDIT_PATTERNS.some((pattern) => pattern.test(text))) continue;
            const rect = element.getBoundingClientRect();
            const fixed = getComputedStyle(element).position === 'fixed';
            if (!fixed && rect.top + window.scrollY < docHeight * 0.7) continue;
            let target = element;
            for (let depth = 0; depth < 3 && target.parentElement && target.parentElement !== document.body; depth += 1) {
                const parent = target.parentElement;
                if ((parent.textContent || '').trim().length > 220) break;
                if (parent.querySelector('input,select,textarea,button,form')) break;
                target = parent;
            }
            target.style.setProperty('display', 'none', 'important');
            target.dataset.gtiitHidden = '1';
        }
    };

    // 兜底隐藏带“校徽/校名”语义的图片（包括登录页的 companyLogo）。
    const hideBrandingImages = () => {
        if (!cleanupHost || !document.body) return;
        for (const image of document.images) {
            if (image.dataset.gtiitHidden) continue;
            const label = [
                image.getAttribute('alt') || '', image.className || '', image.id || ''
            ].join(' ').toLowerCase();
            const source = (image.currentSrc || image.src || '').toLowerCase();
            if (!/logo|emblem|technion|gtiit|体育中心|sports center/.test(label) &&
                !/logo|emblem/.test(source)) continue;
            image.style.setProperty('display', 'none', 'important');
            image.dataset.gtiitHidden = '1';
        }
    };

    // Moodle dashboard：Course overview 下方的 3 个筛选控件。
    const hideMoodleOverviewFilters = () => {
        if (pageHost !== 'moodle.gtiit.edu.cn' || !document.body) return;
        const headings = Array.from(document.querySelectorAll('h2,h3,h4,h5,legend,span,div'))
            .filter((element) => element.children.length === 0 &&
                /course overview|课程概览/i.test((element.textContent || '').trim()));
        for (const heading of headings) {
            const block = heading.closest('.block,[data-block],.block-myoverview,[data-region="myoverview"]') ||
                heading.parentElement;
            if (!block) continue;
            const controls = block.querySelectorAll(
                '.dropdown,select,button[data-toggle="dropdown"],.dropdown-toggle,[data-region="filter"],.filter');
            for (const control of controls) {
                if (control.dataset.gtiitHidden) continue;
                let target = control;
                for (let depth = 0; depth < 2 && target.parentElement && target.parentElement !== block; depth += 1) {
                    const parent = target.parentElement;
                    if ((parent.textContent || '').trim().length > 120) break;
                    target = parent;
                }
                target.style.setProperty('display', 'none', 'important');
                target.dataset.gtiitHidden = '1';
            }
        }
    };

    const hideBookedLoginHeader = () => {
        if (pageHost !== 'roombooking.gtiit.edu.cn' || !document.body) return;
        if (!document.querySelector('input[type="password"]')) return;
        const header = document.querySelector('#header, header, .navbar');
        if (header && !header.querySelector('input[type="password"]')) {
            header.style.setProperty('display', 'none', 'important');
        }
    };

    const runCleanup = () => {
        hideBrandingImages();
        hideCreditBlocks();
        hideBookedLoginHeader();
        hideMoodleOverviewFilters();
    };

    const scheduleCleanup = () => {
        runCleanup();
        setTimeout(runCleanup, 800);
        setTimeout(runCleanup, 2500);
        if (window.MutationObserver && document.body) {
            let timer = 0;
            const observer = new MutationObserver(() => {
                clearTimeout(timer);
                timer = setTimeout(runCleanup, 250);
            });
            observer.observe(document.body, { childList: true, subtree: true });
            setTimeout(() => observer.disconnect(), 12000);
        }
    };

    installStyles();
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => { installStyles(); scheduleCleanup(); }, { once: true });
    } else {
        scheduleCleanup();
    }

    const fixes = {
        disableProxyInjection: true,
        disableStyleSheetsProxy: true,
        disableCustomElementRegistryProxy: true,
        ignoreImageAnalysis: ['*'],
        ignoreInlineStyle: ['img', 'video', 'canvas', '[data-gtiit-original-colors]',
            '.reserved', '.unreservable', '.available', '.fc-event', '.fc-bg-event',
            '[class*="qrcode"]', '[class*="captcha"]'],
        invert: [], css: ''
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
            if (officialHost && enabled && dark.matches && !pdf && !lock) {
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