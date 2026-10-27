// Runs only in WKContentWorld.defaultClient. No page globals or form values are read.
(() => {
    let enabled = GTIIT_INITIAL_ENABLED;
    const dark = matchMedia('(prefers-color-scheme: dark)');
    const sameHost = (host) => GTIIT_ALLOWED_HOSTS.includes(host);
    const pageHost = location.hostname || (() => {
        if (location.href !== 'about:blank') return '';
        try { return new URL(document.baseURI).hostname; } catch (_) { return ''; }
    })();
    const officialHost = GTIIT_ALLOWED_HOSTS.includes(pageHost);
    const cleanupHost = (typeof GTIIT_CLEANUP_HOSTS === 'undefined' ? GTIIT_ALLOWED_HOSTS : GTIIT_CLEANUP_HOSTS)
        .includes(pageHost);

    // Student's public frontend uses showcase.* only for first-run tours.
    // Disable those before React starts; preserve all unrelated preferences.
    const disablePortalTours = () => {
        if (pageHost !== 'students.gtiit.edu.cn') return;
        try {
            const stored = JSON.parse(localStorage.getItem('showcase') || '{}');
            if (!stored || typeof stored !== 'object' || Array.isArray(stored)) return;
            const keys = ['landing', 'landing_v2', 'grades', 'enrollments'];
            if (keys.every(key => stored[key] === false)) return;
            keys.forEach(key => { stored[key] = false; });
            localStorage.setItem('showcase', JSON.stringify(stored));
        } catch (_) {}
    };
    const closePortalIntroductions = () => {
        if (pageHost !== 'students.gtiit.edu.cn' || !document.body) return;
        // This exact informational reminder's Continue handler releases the
        // site's own data-filter lock. Do not hide arbitrary dialogs or mutate
        // account/session keys, consent, authorization or submission state.
        for (const note of document.querySelectorAll('p')) {
            if ((note.textContent || '').trim() !== 'If this is not your account, please sign out immediately.') continue;
            const reminder = note.parentElement;
            if (!reminder || reminder.classList.contains('hidden') || reminder.dataset.gtiitClosing) continue;
            const buttons = Array.from(reminder.querySelectorAll('button'));
            const next = buttons.find(button => (button.textContent || '').trim() === 'Continue');
            if (!next || next.disabled || !buttons.some(button => (button.textContent || '').trim() === 'Logout')) continue;
            reminder.dataset.gtiitClosing = '1';
            next.click();
            setTimeout(() => { delete reminder.dataset.gtiitClosing; }, 0);
        }
        // Dismiss a late-mounted tour with its own Skip action, releasing its
        // scroll/focus management rather than leaving an invisible blocker.
        const skip = document.querySelector('.react-joyride__tooltip [data-action="skip"]');
        if (skip && !skip.disabled) skip.click();
    };
    disablePortalTours();

    const LOGIN_EMAIL = GTIIT_LOGIN_EMAIL || '';
    const PREFILL_LOGIN_EMAIL = GTIIT_PREFILL_EMAIL;
    const prefillMicrosoftEmail = () => {
        if (!PREFILL_LOGIN_EMAIL || !LOGIN_EMAIL || !cleanupHost) return;
        if (!/(^|\.)microsoftonline\.com$/i.test(pageHost) && pageHost !== 'login.microsoft.com') return;
        if (document.querySelector('input[type="password"]')) return;
        const input = document.querySelector('input[type="email"], input[name="loginfmt"], input#i0116, input[autocomplete="username"]');
        if (!input || input.value) return;
        try {
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
            if (setter) setter.call(input, LOGIN_EMAIL); else input.value = LOGIN_EMAIL;
            input.dispatchEvent(new Event('input', {bubbles: true}));
            input.dispatchEvent(new Event('change', {bubbles: true}));
        } catch (_) {}
    };

    // 站点自带的页脚、版权条与商标条。
    const shellCSS = [
        'footer,#footer,.footer,#page-footer,#course-footer,[class*="footer" i],[id*="footer" i],',
        '[class*="copyright" i],[class*="powered-by" i]{display:none !important}',
        // Strip the website's outer page frame, not borders on cards, forms,
        // tables or focusable controls inside the page.
        'html,body,body > #root,body > #app,#root > .app,#app > .app,',
        '#page-wrapper,#page,#page-content,#region-main-box,#region-main,.main-inner,',
        'body > #main,body > #content,body > .main,body > .container,body > .container-fluid,',
        '#root > div,#app > div,#root main,#app main,.main > .page-content',
        '{border:0 !important;box-shadow:none !important;outline:0 !important}',
        'body > iframe,#region-main > iframe,#page-content > iframe{border:0 !important}',
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
        '#react-joyride-portal,.react-joyride__portal,.react-joyride__tooltip{visibility:hidden !important;pointer-events:none !important}',
        '.app-bg{background:transparent !important}',
        'body:not(:has(main)){padding-bottom:var(--gtiit-bottom-obstruction,env(safe-area-inset-bottom)) !important}',
        'nav[aria-label="Checklist steps"]{bottom:var(--gtiit-bottom-obstruction,env(safe-area-inset-bottom)) !important}',
        'main{scroll-padding-bottom:var(--gtiit-bottom-obstruction,env(safe-area-inset-bottom));padding-bottom:calc(.75rem + var(--gtiit-bottom-obstruction,env(safe-area-inset-bottom))) !important}',
        '.bg-gradient-to-b,.bg-gradient-to-t,.bg-gradient-to-r{background-image:none !important}',
        '.from-white,.from-gray-50{--tw-gradient-from:transparent !important}',
        '.rounded,.rounded-md,.rounded-lg,.rounded-xl,.rounded-2xl,.rounded-3xl,.card,.gtiit-private-card{border-radius:22px !important}',
        'details.gtiit-attendance-rules{background:Canvas;color:CanvasText;border-radius:22px;padding:16px 18px;margin:0 0 16px;box-shadow:0 1px 2px rgba(0,0,0,.06)}',
        'details.gtiit-attendance-rules summary{display:flex;align-items:center;justify-content:space-between;list-style:none;cursor:pointer;font-size:17px;font-weight:600}',
        'details.gtiit-attendance-rules summary::-webkit-details-marker{display:none}',
        'details.gtiit-attendance-rules summary::after{content:"⌄";font-size:17px;color:#6b7280;transition:transform .18s ease}',
        'details.gtiit-attendance-rules[open] summary::after{transform:rotate(180deg)}',
        '.gtiit-attendance-rules-body{padding-top:10px;font-size:14px;line-height:1.45;color:CanvasText}',
        // Student web actions are represented by native chrome.
        '[aria-label*=\"notification\" i],[aria-label*=\"通知\"],[title*=\"notification\" i],[title*=\"通知\"],[data-testid*=\"notification\" i]{display:none !important}',
        '[aria-label*=\"error\" i],[aria-label*=\"故障\"],[title*=\"error\" i],[title*=\"故障\"],[data-testid*=\"error\" i]{display:none !important}',
        // Student page navigation/menu chrome is native now. Keep the actual
        // page content and the checklist step bar, remove every other menu.
        'header, nav:not([aria-label="Checklist steps"]), aside,',
        '[role="navigation"]:not([aria-label="Checklist steps"]), [role="menu"],',
        '[class*="sidebar" i],[class*="side-nav" i],[class*="sidenav" i],',
        '[class*="topbar" i],[class*="top-bar" i],[class*="app-header" i],',
        '[class*="site-header" i],[class*="page-header" i],[class*="main-menu" i],',
        '[class*="menu-bar" i],[class*="nav-bar" i],',
        '[class*="drawer" i],[class*="menu" i],[class*="navigation" i],',
        '[class*="breadcrumb" i]{display:none !important}',
        // Privacy cards: blur only their contents. Children carry the blur, so
        // the card background, border, radius and shadow stay perfectly sharp.
        '.gtiit-private-card{cursor:pointer;-webkit-user-select:none;user-select:none}',
        '.gtiit-private-card > *{filter:blur(11px) !important;',
        'transition:filter .18s ease}',
        '.gtiit-private-card.gtiit-private-revealed > *{filter:none !important}'
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

    // Zammad remains responsible for forms; native chrome supplies navigation.
    const serviceCSS = pageHost === 'servicehub.gtiit.edu.cn' ? [
        'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif !important}',
        'input,textarea,select,[contenteditable=true]{font-size:16px !important}',
        '.login{max-width:480px;margin-inline:auto}',
        '@media(max-width:600px){.ticket-article{padding:16px !important}.ticket-article img{max-width:100%;height:auto}textarea,[contenteditable=true]{max-width:100%;box-sizing:border-box}}'
    ].join('') : '';

    const installStyles = () => {
        try {
            if (document.getElementById('gtiit-native-chrome')) return;
            const style = document.createElement('style');
            style.id = 'gtiit-native-chrome';
            style.textContent = (officialHost ? shellCSS : '') + brandingCSS + portalCSS + roomsCSS + sportsCSS + serviceCSS;
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

    // 学生门户首页的 GPA / 成功率 / 学分 / 排名卡片：默认高斯模糊，点按显示。
    const PORTAL_PRIVATE_LABELS = [
        /overall\s*gpa/i, /总\s*gpa/i, /平均绩点/i, /\bgpa\b/i,
        /success\s*rate/i, /成功率/i, /通过率/i,
        /accumulated\s*credits?/i, /累计学分/i, /已修学分/i,
        /cohort\s*rank/i, /年级排名/i, /班排名/i
    ];
    const portalTextRoots = () => {
        const roots = [document.body];
        const visit = (root) => {
            for (const element of root.querySelectorAll('*')) {
                if (element.shadowRoot) { roots.push(element.shadowRoot); visit(element.shadowRoot); }
            }
        };
        try { visit(document.body); } catch (_) {}
        return roots;
    };
    // Moodle 的站点导航目前是 sticky/fixed，会一直吸附在界面上方并与
    // 原生大标题抢位置。把它放回网页内容流，让它随页面一起滚走。
    const releaseMoodleNavigation = () => {
        if (pageHost !== 'moodle.gtiit.edu.cn' || !document.body) return;
        if (document.documentElement.dataset.gtiitMoodleReleased) return;
        const candidates = Array.from(document.querySelectorAll(
            'nav.navbar, .navbar.fixed-top, .navbar.sticky-top, #page-header nav, nav[aria-label="Site navigation"]'));
        const bar = candidates.find((element) => {
            const rect = element.getBoundingClientRect();
            return rect.height > 20 && rect.width > 120;
        });
        if (!bar) return;
        document.documentElement.dataset.gtiitMoodleReleased = '1';
        bar.dataset.gtiitMoodleNav = '1';
        bar.style.setProperty('position', 'static', 'important');
        bar.style.setProperty('top', 'auto', 'important');
        // Bootstrap adds body padding for a fixed navbar; it is no longer needed
        // once the bar is back in the normal flow.
        const padding = parseFloat(getComputedStyle(document.body).paddingTop) || 0;
        if (padding > 0) document.body.style.setProperty('padding-top', '0', 'important');
    };

    // Moodle dashboard 的「Customise this page」卡片和它留下的空白区域。
    const removeMoodleCustomizeCard = () => {
        if (pageHost !== 'moodle.gtiit.edu.cn' || !document.body) return;
        const patterns = [/customi[sz]e this page/i, /自定义此页/i, /自定义此页面/i, /编辑此页/i];
        for (const element of document.querySelectorAll('button,a,span,div')) {
            if (element.children.length > 2) continue;
            const text = (element.textContent || '').replace(/\s+/g, ' ').trim();
            if (!text || text.length > 60 || !patterns.some((pattern) => pattern.test(text))) continue;
            let target = element.closest('.block,[data-block],.card,.dashboard-card,.page-actions');
            if (!target) target = element.closest('header,section') || element;
            if (target === document.body) target = element;
            // Remove the node, not just hide it: hiding keeps its text in the
            // parent's textContent, which prevents the empty wrapper collapsing.
            target.remove();
            // Collapse wrappers that become completely empty so the next block
            // (Recent accessed courses) moves directly under the web navbar.
            let parent = target.parentElement;
            for (let depth = 0; depth < 4 && parent && parent !== document.body; depth += 1) {
                const rect = parent.getBoundingClientRect();
                const media = parent.querySelector('img,video,iframe,input,button,a');
                const remaining = (parent.textContent || '').trim().length;
                if (remaining > 0 || media || rect.height > 180) break;
                parent.style.setProperty('display', 'none', 'important');
                parent = parent.parentElement;
            }
            break;
        }
    };

    const markPortalPrivateCards = () => {
        if (pageHost !== 'students.gtiit.edu.cn' || !document.body) return;
        const findLabel = (pattern) => {
            let best = null;
            let bestScore = Infinity;
            for (const root of portalTextRoots()) {
                const elements = root.querySelectorAll('h1,h2,h3,h4,h5,p,span,div');
                for (const element of elements) {
                    if (element.querySelectorAll('*').length > 4) continue;
                    if (element.closest('.gtiit-private-card')) continue;
                    const text = (element.textContent || '').replace(/\s+/g, ' ').trim();
                    if (!text || text.length > 60 || !pattern.test(text)) continue;
                    // Prefer the smallest/deepest match: "Overall GPA" over the
                    // whole card whose text also contains the value.
                    const score = text.length + element.querySelectorAll('*').length * 40;
                    if (score < bestScore) { best = element; bestScore = score; }
                }
            }
            return best;
        };
        for (const pattern of PORTAL_PRIVATE_LABELS) {
            const label = findLabel(pattern);
            if (!label) continue;
            let card = null;
            let node = label;
            for (let depth = 0; depth < 8 && node.parentElement && node.parentElement !== document.body; depth += 1) {
                const parent = node.parentElement;
                const rect = parent.getBoundingClientRect();
                const style = getComputedStyle(parent);
                const radius = parseFloat(style.borderTopLeftRadius) || 0;
                if (rect.width > 100 && rect.height > 55 && rect.height < innerHeight * 0.75 &&
                    (radius >= 8 || style.boxShadow !== 'none' ||
                        /card|stat|metric|tile|bg-white|rounded/i.test(parent.className))) {
                    card = parent;
                    break;
                }
                if ((parent.textContent || '').trim().length > 500) break;
                node = parent;
            }
            // Fallback for custom markup without rounded/shadow classes: blur
            // the smallest container that still holds just this stat.
            if (!card) {
                const parent = label.parentElement;
                if (parent && parent !== document.body &&
                    (parent.textContent || '').trim().length <= 220) card = parent;
            }
            if (!card || card === document.body || card.dataset.gtiitPrivate) continue;
            card.dataset.gtiitPrivate = '1';
            card.classList.add('gtiit-private-card');
            card.setAttribute('role', 'button');
            card.setAttribute('aria-label', '点击显示数据');
            card.addEventListener('click', (event) => {
                if (card.classList.contains('gtiit-private-revealed')) return;
                event.preventDefault();
                event.stopPropagation();
                card.classList.add('gtiit-private-revealed');
            }, true);
        }
    };

    const isAttendancePage = () => pageHost === 'students.gtiit.edu.cn' && /^\/attendance(?:\/|$)/.test(location.pathname);

    const hideAttendanceChrome = () => {
        if (!isAttendancePage() || !document.body) return;
        for (const element of document.querySelectorAll('hr,[data-gtiit-attendance-hidden]')) {
            element.style.setProperty('display', 'none', 'important');
        }
        for (const element of document.querySelectorAll('button,a,[role="button"]')) {
            const rect = element.getBoundingClientRect();
            if (rect.width > 64 || rect.height > 64 || rect.width === 0 || rect.height === 0) continue;
            const text = (element.textContent || '').trim();
            const label = ((element.getAttribute('aria-label') || '') + ' ' + String(element.className || '')).toLowerCase();
            const style = getComputedStyle(element);
            const radius = parseFloat(style.borderTopLeftRadius) || 0;
            const blue = /rgb\((?:0|1?[0-9]|2[0-9]|3[0-9]),\s*(?:[6-9][0-9]|1[0-9][0-9]),\s*(?:1[3-9][0-9]|2[0-5][0-9])\)/.test(style.backgroundColor);
            const plus = text === '+' || /add|attendance|新增|考勤/i.test(label) ||
                (rect.width <= 56 && rect.height <= 56 && radius >= 18 && blue);
            if (!plus) continue;
            element.style.setProperty('display', 'none', 'important');
            element.setAttribute('data-gtiit-attendance-hidden', '1');
            let ancestor = element.parentElement;
            for (let depth = 0; depth < 4 && ancestor && ancestor !== document.body; depth += 1) {
                const ancestorRect = ancestor.getBoundingClientRect();
                if (ancestorRect.width > innerWidth * 0.5) {
                    ancestor.style.setProperty('border-bottom', 'none', 'important');
                    ancestor.style.setProperty('box-shadow', 'none', 'important');
                }
                ancestor = ancestor.parentElement;
            }
            const parent = element.parentElement;
            if (parent && parent !== document.body && parent.children.length === 1) {
                parent.style.setProperty('display', 'none', 'important');
                parent.setAttribute('data-gtiit-attendance-hidden', '1');
            }
        }
        // The thin rule under the add control is a visual separator, not content.
        for (const element of document.querySelectorAll('div,span')) {
            const rect = element.getBoundingClientRect();
            if (rect.height > 2 || rect.width < innerWidth * 0.55) continue;
            const style = getComputedStyle(element);
            if (style.backgroundColor !== 'rgba(0, 0, 0, 0)' || parseFloat(style.borderTopWidth) > 0) {
                element.style.setProperty('display', 'none', 'important');
            }
        }
        // Some portals draw the separator as a border on a short wrapper
        // rather than as an element with its own height.
        for (const element of document.querySelectorAll('div,section')) {
            const rect = element.getBoundingClientRect();
            if (rect.width < innerWidth * 0.5 || rect.height > 24) continue;
            const style = getComputedStyle(element);
            if (parseFloat(style.borderTopWidth) > 0 || parseFloat(style.borderBottomWidth) > 0) {
                element.style.setProperty('border-top', 'none', 'important');
                element.style.setProperty('border-bottom', 'none', 'important');
            }
        }
    };

    const setupAttendanceRules = () => {
        if (!isAttendancePage() || !document.body || document.querySelector('.gtiit-attendance-rules')) return;
        const candidates = Array.from(document.querySelectorAll('div,section,article')).filter((element) => {
            if (element.closest('.gtiit-attendance-rules')) return false;
            const text = (element.textContent || '').replace(/\s+/g, ' ').trim();
            return /(attendance rules|it is the responsibility of the students)/i.test(text) && text.length < 3500;
        });
        if (!candidates.length) return;
        candidates.sort((a, b) => a.textContent.length - b.textContent.length);
        let card = candidates[0];
        for (let depth = 0; depth < 4 && card.parentElement && card.parentElement !== document.body; depth += 1) {
            const parent = card.parentElement;
            const rect = parent.getBoundingClientRect();
            if (rect.width < 250 || rect.height < 60 || rect.height > 700) break;
            card = parent;
        }
        const details = document.createElement('details');
        details.className = 'gtiit-attendance-rules';
        const summary = document.createElement('summary');
        summary.textContent = 'Attendance rules';
        const body = document.createElement('div');
        body.className = 'gtiit-attendance-rules-body';
        body.innerHTML = card.innerHTML;
        details.appendChild(summary);
        details.appendChild(body);
        card.style.setProperty('display', 'none', 'important');
        card.parentElement.insertBefore(details, card);
    };

    const runCleanup = () => {
        closePortalIntroductions();
        prefillMicrosoftEmail();
        hideBrandingImages();
        hideCreditBlocks();
        hideBookedLoginHeader();
        hideMoodleOverviewFilters();
        releaseMoodleNavigation();
        removeMoodleCustomizeCard();
        markPortalPrivateCards();
        hideAttendanceChrome();
        setupAttendanceRules();
    };

    const scheduleCleanup = () => {
        runCleanup();
        setTimeout(runCleanup, 800);
        setTimeout(runCleanup, 2500);
        if (pageHost === 'students.gtiit.edu.cn') {
            let scans = 0;
            const timer = setInterval(() => {
                markPortalPrivateCards();
                hideAttendanceChrome();
                setupAttendanceRules();
                scans += 1;
                if (scans > 25) clearInterval(timer);
            }, 800);
        }
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

    // Keep only the lightweight introduction dismissal observer alive across
    // delayed account loading and SPA navigation, beyond the generic 12s scan.
    const watchPortalIntroductions = () => {
        if (pageHost !== 'students.gtiit.edu.cn' || !document.body || !window.MutationObserver) return;
        let scheduled = false;
        const observer = new MutationObserver(() => {
            if (scheduled) return;
            scheduled = true;
            requestAnimationFrame(() => { scheduled = false; closePortalIntroductions(); });
        });
        observer.observe(document.body, {childList: true, subtree: true, attributes: true, attributeFilter: ['class']});
        closePortalIntroductions();
    };
    installStyles();
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', watchPortalIntroductions, {once: true});
    } else { watchPortalIntroductions(); }
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
        darkSchemeBackgroundColor: 'GTIIT_DARK_CANVAS', darkSchemeTextColor: '#e9edf2',
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
    // Keep the page canvas consistent with native Me, while preserving elevated
    // cards, booking status colors, media, authentication and original-color opt-out.
    const canvasSelectors = ['html', 'body', '#root', '#app'];
    if (pageHost === 'students.gtiit.edu.cn') canvasSelectors.push('.app-bg', '#root > div', 'main', '.page-content', '.site-content');
    if (pageHost === 'moodle.gtiit.edu.cn') canvasSelectors.push('#page', '#page-wrapper', '#page-content');
    if (pageHost === 'roombooking.gtiit.edu.cn') canvasSelectors.push('#page', '#page-wrapper');
    if (pageHost === 'gtiit.mike-x.com') canvasSelectors.push('.main', '.page-package', '.page-group', '.page', '.page > .content');
    if (pageHost === 'servicehub.gtiit.edu.cn') canvasSelectors.push('#app', '.content', '.main', '.content-main');
    // Dark Reader's final override is deliberately not color-transformed again.
    fixes.css = canvasSelectors.map(selector => selector === 'html' ? 'html:root' : ':root ' + selector).join(',') + '{background-color:GTIIT_DARK_CANVAS !important;background-image:none !important;}';
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
