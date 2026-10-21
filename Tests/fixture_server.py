"""Read-only loopback fixtures; POST body is echoed only for synthetic test data."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time
import json
METRICS = {"heads": 0, "cookie_headers": 0, "redirect_followed": 0}

class Handler(BaseHTTPRequestHandler):
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
        self.send_response(200); self.send_header('Content-Type', 'text/html'); self.end_headers()
        self.wfile.write(b'<title>POST received</title><body>' + data + b'</body>')
    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/metrics':
            content = json.dumps(METRICS).encode()
            self.send_response(200); self.send_header('Content-Length', str(len(content)))
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
