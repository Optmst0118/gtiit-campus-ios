"""Read-only loopback fixtures; POST body is echoed only for synthetic test data."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time
import json
METRICS = {"heads": 0, "cookie_headers": 0, "redirect_followed": 0, "private_cache_hits": 0, "pdf_posts": 0, "pdf_gets": 0, "preview_gets": 0, "preview_posts": 0, "once_gets": 0}

def preview_pdf():
    stream = b'BT /F1 18 Tf 40 120 Td (Preview fixture) Tj ET'
    objects = [b'<< /Type /Catalog /Pages 2 0 R >>', b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 240 180] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        b'<< /Length ' + str(len(stream)).encode() + b' >>\nstream\n' + stream + b'\nendstream']
    content = b'%PDF-1.4\n'
    offsets = [0]
    for i, obj in enumerate(objects, 1):
        offsets.append(len(content)); content += str(i).encode() + b' 0 obj\n' + obj + b'\nendobj\n'
    xref = len(content)
    content += b'xref\n0 6\n0000000000 65535 f \n'
    content += b''.join(f'{off:010d} 00000 n \n'.encode() for off in offsets[1:])
    content += b'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n' + str(xref).encode() + b'\n%%EOF\n'
    return content

class Handler(BaseHTTPRequestHandler):
    def preview_response(self, attachment=False, invalid=False):
        content = b'<html>not a PDF</html>' if invalid else preview_pdf()
        self.send_response(200); self.send_header('Content-Type', 'application/pdf')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Disposition', ('attachment' if attachment else 'inline') + '; filename="preview.pdf"')
        self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content)

    def log_message(self, *args):
        pass
    def do_HEAD(self):
        METRICS['heads'] += 1
        if self.headers.get('Cookie') or self.headers.get('Authorization'):
            METRICS['cookie_headers'] += 1
        if self.path == '/diagnostic':
            self.send_response(302)
            self.send_header('Location', '/should-not-follow')
            self.send_header('Set-Cookie', 'diagnostic=synthetic')
        else:
            self.send_response(200)
        self.send_header('Content-Length', '0'); self.end_headers()
    def do_POST(self):
        data = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if self.path == '/preview-post':
            METRICS['preview_posts'] += 1
            self.preview_response(); return
        if self.path == '/post-pdf':
            METRICS['pdf_posts'] += 1
            self.send_response(200); self.send_header('Content-Type', 'application/pdf')
            self.send_header('Content-Disposition', 'inline; filename="post-only.pdf"')
            content = b'%PDF-1.4\nOriginal POST response\n'
            self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content); return
        self.send_response(200); self.send_header('Content-Type', 'text/html'); self.end_headers()
        self.wfile.write(b'<title>POST received</title><body>' + data + b'</body>')
    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/dark-fixture':
            content = b'''<!doctype html><html><head><title>Dark fixture</title>
<style>html,body{background:#fff;color:#111;margin:0}body{padding:16px;font:16px sans-serif}.panel{background:#f5f5f5;color:#202020;padding:16px;width:260px;box-sizing:border-box}input,select,button{font:inherit;padding:8px;background:white;color:#111;border:1px solid #888}.reserved{background:#d80000;color:white}.available{background:#00a050;color:white}#qr{width:32px;height:32px}#dynamic{background:white;color:black}</style>
</head><body><div id="panel" class="panel"><h2>Campus fixture</h2><form id="form" action="/echo" method="post"><label>Name <input id="name" name="name" value="synthetic" required></label><label>Password <input id="password" type="password" value="synthetic-password"></label><select id="select"><option>A</option><option>B</option></select><input id="check" type="checkbox"><button id="disabled" disabled>Disabled</button><button type="button" id="dialogButton" onclick="document.getElementById('dialog').showModal()">Dialog</button><dialog id="dialog">Native dialog<button type="button" onclick="this.closest('dialog').close()">Close</button></dialog></form><div class="reserved">Reserved</div><div class="available">Available</div><img id="brand-logo" alt="GTIIT logo" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16'%3E%3C/svg%3E"><img id="qr" alt="Synthetic QR" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16'%3E%3Cpath fill='white' d='M0 0h16v16H0z'/%3E%3Cpath d='M0 0h8v8H0zM8 8h8v8H8z'/%3E%3C/svg%3E"><canvas id="canvas" width="16" height="16"></canvas><div id="dynamic">Dynamic content</div></div><script>window.originalInsertRule=CSSStyleSheet.prototype.insertRule;window.originalDefine=customElements.define;window.fixtureClicks=0;document.getElementById('check').addEventListener('change',()=>window.fixtureClicks++);</script></body></html>'''
            self.send_response(200); self.send_header('Content-Type', 'text/html'); self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content); return
        if path.startswith('/preview-'):
            if path == '/preview-post':
                METRICS['preview_gets'] += 1
                self.send_response(405); self.end_headers(); return
            if path == '/preview-once':
                METRICS['once_gets'] += 1
                if METRICS['once_gets'] > 1:
                    self.send_response(410); self.end_headers(); return
            self.preview_response(attachment=path == '/preview-attachment', invalid=path == '/preview-invalid'); return
        if path == '/slow-page':
            time.sleep(2)
            content = b'<title>Slow fixture</title><p>ready</p>'
            self.send_response(200); self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', str(len(content))); self.end_headers()
            try: self.wfile.write(content)
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if path == '/post-pdf':
            METRICS['pdf_gets'] += 1
            self.send_response(405); self.end_headers(); return
        if path == '/inline-pdf':
            content = b'%PDF-1.4\nInline authenticated PDF fixture\n'
            self.send_response(200); self.send_header('Content-Type', 'application/pdf')
            self.send_header('Content-Disposition', 'inline; filename="inline.pdf"')
            self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content); return
        if path.startswith('/private-cache/'):
            METRICS['private_cache_hits'] += 1
            print('PRIVATE CACHE GET', METRICS['private_cache_hits'], flush=True)
            content = ('<title>Private cache fixture ' + str(METRICS['private_cache_hits']) + '</title><p>Synthetic cached content</p>').encode()
            self.send_response(200); self.send_header('Content-Type', 'text/html')
            self.send_header('Cache-Control', 'private, max-age=3600')
            self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content); return
        if path == '/inspect':
            content = b'<title>Storage inspector</title><p>No storage writes</p>'
            self.send_response(200); self.send_header('Content-Type', 'text/html'); self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content); return
        if path == '/metrics':
            print('METRICS GET', METRICS, flush=True)
            content = json.dumps(METRICS).encode()
            self.send_response(200); self.send_header('Cache-Control', 'no-store'); self.send_header('Content-Length', str(len(content)))
            self.end_headers(); self.wfile.write(content); return
        if path == '/should-not-follow':
            METRICS['redirect_followed'] += 1
        if path in ['/file', '/slow']:
            content = (b'%PDF-1.4\n' + b'test only\n' * (150000 if path == '/slow' else 200))
            start = int(self.headers.get('Range', 'bytes=0-').split('=')[-1].split('-')[0])
            self.send_response(206 if start else 200)
            self.send_header('Content-Type', 'application/pdf')
            self.send_header('Content-Disposition', 'attachment; filename="review.pdf"')
            self.send_header('Accept-Ranges', 'bytes'); self.send_header('ETag', '"review-fixture"')
            if start:
                self.send_header('Content-Range', f'bytes {start}-{len(content)-1}/{len(content)}')
            self.send_header('Content-Length', str(len(content)-start)); self.end_headers()
            try:
                for offset in range(start, len(content), 16384):
                    self.wfile.write(content[offset:offset+16384]); self.wfile.flush()
                    if path == '/slow': time.sleep(.05)
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        if path == '/child':
            content = b'''<title>Child</title><script>if(window.opener){window.opener.postMessage('review-ok','*');window.close();}</script>'''
        else:
            content = b'''<title>Fixture</title><body><p>Non-sensitive review fixture</p>
<script>document.cookie='review=1;path=/';localStorage.setItem('review','fixture');window.reviewMessage='';setInterval(()=>{localStorage.setItem('timer','active');document.cookie='timer=active;path=/';},30);window.addEventListener('message',e=>window.reviewMessage=e.data);</script>
<a href='/b'>Next</a><form method='POST' action='/echo'><input name='review' value='synthetic'><input type='submit'></form></body>'''
        self.send_response(200); self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(content))); self.end_headers(); self.wfile.write(content)

if __name__ == '__main__':
    print('Fixtures on 127.0.0.1:48173', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 48173), Handler).serve_forever()
