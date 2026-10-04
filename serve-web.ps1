<#
.SYNOPSIS
  Serves the built web game locally for testing.

.DESCRIPTION
  Serves build/web/ on http://127.0.0.1:8060 with the COOP/COEP headers
  Godot web exports prefer. Requires Python 3 on PATH.
#>
param([int]$Port = 8060)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = Join-Path $root "build\web"

if (-not (Test-Path (Join-Path $dir "index.html"))) {
    Write-Error "No build found. Run ./build-web.ps1 first."
}

# Tiny Python server that adds cross-origin isolation headers.
$py = @"
import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', $Port), H) as s:
    print('Serving CorgiKnight at http://127.0.0.1:$Port')
    s.serve_forever()
"@

Set-Location $dir
Write-Host "Open http://127.0.0.1:$Port in your browser (Ctrl+C to stop)" -ForegroundColor Green
python -c $py
