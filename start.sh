#!/bin/bash

C="\033[1;36m"
G="\033[1;32m"
Y="\033[1;33m"
R="\033[1;31m"
W="\033[1;37m"
D="\033[1;90m"
N="\033[0m"

ROOT_PASS="${ROOT_PASS:-2003}"
PORT="${PORT:-10000}"
BORE_PORT="${BORE_PORT:-48251}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"

echo ""
echo -e "${C}░▒▓████████▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░ ${N}"
echo -e "${C}░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████▓▒░${N}"
echo -e "${C}        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░${N}"
echo -e "${C}       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░${N}"
echo -e "${C}       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░${N}"
echo -e "${C}      ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░${N}"
echo -e "${C}      ░▒▓█▓▒░  ░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░${N}"
echo -e "${D}           Render.com VPS | ${C}Modified by 7oq1_${N}"
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""

# ── Jelszavak ──
echo -e "${C}[1/5]${W} Felhasználók...${N}"
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
mkdir -p /workspace /data /root/.ssh 2>/dev/null || true
echo -e "  ${G}✓${N} Root: ${G}root${N} / Jelszó: ${G}${ROOT_PASS}${N}"

# ── Nginx config ──
echo -e "${C}[2/5]${W} Nginx konfiguráció...${N}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t 2>/dev/null && echo -e "  ${G}✓${N} Nginx config OK" || echo -e "  ${R}✗${N} Nginx hiba"

# ── bore wrapper (auto-reconnect) ──
echo -e "${C}[3/5]${W} bore tunnel wrapper...${N}"
cat > /usr/local/bin/bore-wrapper.sh << BORESCRIPT
#!/bin/bash
echo "[BORE] Fix port: ${BORE_PORT}"

while true; do
    echo "[BORE] \$(date '+%H:%M:%S') Csatlakozás bore.pub:${BORE_PORT}..."
    /usr/local/bin/bore local 22 --to bore.pub --port ${BORE_PORT} 2>&1
    EXIT_CODE=\$?
    echo "[BORE] \$(date '+%H:%M:%S') Megszakadt (exit: \$EXIT_CODE), újra 5mp múlva..."
    sleep 5
done
BORESCRIPT
chmod +x /usr/local/bin/bore-wrapper.sh
echo -e "  ${G}✓${N} bore-wrapper kész (port: ${G}${BORE_PORT}${N})"

# ── SFTP info frissítő ──
echo -e "${C}[4/5]${W} SFTP frissítő...${N}"

# Kezdeti SFTP info
cat > /var/www/html/sftp.txt << EOF
Tunnel indítása (port: ${BORE_PORT})...
Várj 15 másodpercet!

ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
EOF

# Tunnel info JSON
cat > /tmp/tunnel-info.json << EOF
{"status":"connecting","host":"bore.pub","port":"${BORE_PORT}","ssh_cmd":"ssh root@bore.pub -p ${BORE_PORT}","user":"root","password":"${ROOT_PASS}"}
EOF

# SFTP updater script
cat > /usr/local/bin/update-sftp.sh << SCRIPT
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        if grep -q 'bore\.pub' /var/log/bore.log 2>/dev/null; then
            cat > /var/www/html/sftp.txt << EOF
AKTIV

SSH: ssh root@bore.pub -p ${BORE_PORT}
Jelszó: ${ROOT_PASS}

FileZilla (SFTP):
  Protocol: SFTP
  Host: bore.pub
  Port: ${BORE_PORT}
  User: root
  Pass: ${ROOT_PASS}

Fix port: ${BORE_PORT}

Frissítve: \$(date '+%H:%M:%S')
EOF

            cat > /tmp/tunnel-info.json << EOF2
{"status":"active","host":"bore.pub","port":"${BORE_PORT}","ssh_cmd":"ssh root@bore.pub -p ${BORE_PORT}","user":"root","password":"${ROOT_PASS}","updated":"\$(date -Iseconds)"}
EOF2
        fi
    fi
done
SCRIPT
chmod +x /usr/local/bin/update-sftp.sh
echo -e "  ${G}✓${N} SFTP frissítő kész"

# ── Segédparancsok ──
echo -e "${C}[5/5]${W} Segédparancsok...${N}"

cat > /usr/local/bin/vps-info << 'VIEOF'
#!/bin/bash
echo ""
echo -e "\033[1;36m═══════════════════════════════\033[0m"
echo -e "\033[1;32m  VPS INFO\033[0m"
echo -e "\033[1;36m═══════════════════════════════\033[0m"
echo "  OS:   $(lsb_release -ds 2>/dev/null || echo 'Ubuntu 24.04')"
echo "  CPU:  $(nproc) vCPU"
echo "  RAM:  $(free -h | awk '/Mem:/{print $7"/"$2}')"
echo "  Disk: $(df -h / | awk 'NR==2{print $4"/"$2}')"
echo ""
BORE_PORT="${BORE_PORT:-48251}"
echo "  SSH:  ssh root@bore.pub -p ${BORE_PORT}"
echo "  Pass: 2003"
echo ""
echo "  FileZilla:"
echo "    Host: bore.pub"
echo "    Port: ${BORE_PORT}"
echo "    User: root"
echo "    Pass: 2003"
echo ""
echo "  dropbear: $(pgrep -x dropbear >/dev/null && echo 'FUT' || echo 'NEM')"
echo "  bore:     $(pgrep -f 'bore local' >/dev/null && echo 'FUT' || echo 'NEM')"
echo "  ttyd:     $(pgrep -x ttyd >/dev/null && echo 'FUT' || echo 'NEM')"
echo "  nginx:    $(pgrep -x nginx >/dev/null && echo 'FUT' || echo 'NEM')"
echo ""
VIEOF
chmod +x /usr/local/bin/vps-info

cat > /usr/local/bin/vps-tunnel-restart << 'VREOF'
#!/bin/bash
BORE_PORT="${BORE_PORT:-48251}"
echo "Bore újraindítás..."
supervisorctl restart bore 2>/dev/null || (pkill -f "bore local" && sleep 2 && /usr/local/bin/bore-wrapper.sh &)
echo "Várakozás..."
sleep 10
if pgrep -f "bore local" >/dev/null; then
    echo -e "\033[1;32m✅ bore fut\033[0m"
    echo "SSH: ssh root@bore.pub -p ${BORE_PORT}"
else
    echo -e "\033[1;31m✗ bore nem fut\033[0m"
    cat /var/log/bore.log 2>/dev/null | tail -10
fi
VREOF
chmod +x /usr/local/bin/vps-tunnel-restart

# Root bashrc
cat > /root/.bashrc << 'BEOF'
export PS1='\[\033[01;32m\]\u@7oq1-vps\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM=xterm-256color
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cls='clear'
alias info='vps-info'

if [ -z "$VPS_GREETED" ]; then
    export VPS_GREETED=1
    echo ""
    echo -e "\033[1;36m  ═════════════════════════════\033[0m"
    echo -e "\033[1;36m   7oq1_ VPS — ROOT\033[0m"
    echo -e "\033[1;36m  ═════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;33m  vps-info\033[0m             → Infó"
    echo -e "\033[1;33m  vps-tunnel-restart\033[0m   → Tunnel újra"
    echo ""
fi
BEOF
echo -e "  ${G}✓${N} Parancsok kész"

# ── Dashboard HTML ──
cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>7oq1_ Ubuntu VPS</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,sans-serif;padding:20px}
.wrap{max-width:1100px;margin:0 auto}
h1{color:#58a6ff;text-align:center;font-size:2.2em;margin-bottom:20px}
.logo{color:#58a6ff;font-size:9px;line-height:1.2;white-space:pre;text-align:center;margin:15px 0 5px;font-family:monospace}
.sub{color:#8b949e;font-size:13px;text-align:center;margin-bottom:20px}
.row{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-bottom:15px}
.card{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:20px}
.card h2{color:#7ee787;margin-bottom:12px;font-size:1.2em}
.full{grid-column:1/-1}
pre{background:#0d1117;padding:15px;border-radius:6px;color:#7ee787;font-family:'Courier New',monospace;font-size:13px;line-height:1.6;white-space:pre-wrap;overflow-x:auto}
.btn{display:block;text-align:center;padding:14px;background:#238636;color:#fff;text-decoration:none;border-radius:8px;font-size:16px;font-weight:600;margin-top:10px;transition:background .2s}
.btn:hover{background:#2ea043}
.status{text-align:center;padding:15px;border-radius:8px;font-size:1.2em;font-weight:bold;margin-bottom:15px}
.active{background:#0d2818;border:1px solid #238636;color:#7ee787}
.loading{background:#1c1e26;border:1px solid #ffa657;color:#ffa657}
.info{color:#8b949e;font-size:13px;margin-top:8px}
@media(max-width:768px){.row{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class="wrap">
<div class="logo">
░▒▓████████▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████▓▒░
        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░
       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░
      ░▒▓█▓▒░  ░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░
</div>
<div class="sub">Render.com Ubuntu VPS — Modified by 7oq1_</div>

<div class="status" id="status"><span class="loading">🔄 Betöltés...</span></div>

<div class="row">
    <div class="card">
        <h2>🔐 SSH Csatlakozás</h2>
        <pre id="ssh-info">Betöltés...</pre>
    </div>
    <div class="card">
        <h2>📂 FileZilla (SFTP)</h2>
        <pre id="sftp-info">Betöltés...</pre>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>🖥️ Web Terminál</h2>
        <a href="/terminal" class="btn" target="_blank">🖥️ Terminál megnyitása</a>
        <p class="info">Teljes root Linux shell — nem kell semmi telepíteni!</p>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>📂 Webes Fájlkezelő</h2>
        <a href="/files" class="btn" target="_blank" style="background:#1f6feb">📂 Fájlkezelő megnyitása</a>
        <p class="info">Drag & drop fájlfeltöltés — böngészőből!</p>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>🖥️ Beágyazott Terminál</h2>
        <div style="background:#000;border-radius:8px;overflow:hidden;height:500px">
            <iframe src="/terminal" style="width:100%;height:100%;border:none"></iframe>
        </div>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>📚 Parancsok</h2>
        <pre>vps-info              # Rendszer infó + SSH adatok
vps-tunnel-restart    # Tunnel újraindítás
htop                  # Folyamatok
ll                    # Fájlok listázása</pre>
    </div>
</div>
</div>

<script>
function load(){
    fetch('/sftp.txt').then(r=>r.text()).then(t=>{
        if(t.includes('AKTIV')){
            document.getElementById('status').innerHTML='<span class="active">✅ Szerver aktív — SSH és SFTP működik!</span>';
            var lines=t.split('\n');
            var host='',port='';
            lines.forEach(l=>{
                if(l.includes('Host:')&&!l.includes('Protocol'))host=l.split('Host:')[1].trim();
                if(l.includes('Port:')&&!l.includes('Protocol'))port=l.split('Port:')[1].trim();
            });
            if(host&&port){
                document.getElementById('ssh-info').textContent=
                    'SSH parancs:\n  ssh root@'+host+' -p '+port+'\n\nJelszó: 2003\n\nPuTTY:\n  Host: '+host+'\n  Port: '+port+'\n  User: root\n  Pass: 2003';
                document.getElementById('sftp-info').textContent=
                    'Protocol: SFTP\nHost: '+host+'\nPort: '+port+'\nUser: root\nPass: 2003\n\nMappa: /';
            }
        } else {
            document.getElementById('status').innerHTML='<span class="loading">⏳ Tunnel indítása...</span>';
            document.getElementById('ssh-info').textContent=t;
            document.getElementById('sftp-info').textContent=t;
        }
    }).catch(()=>{});
}
load();setInterval(load,3000);
</script>
</body>
</html>
HTMLEOF

# ══════════════════════════════════════
# ÖSSZEFOGLALÓ
# ══════════════════════════════════════
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo -e "${G}            ✅  VPS KÉSZ!${N}"
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""
echo -e "  User: ${G}root${N}  Pass: ${G}2003${N}"
echo -e "  SSH:  ${G}ssh root@bore.pub -p ${BORE_PORT}${N}"
echo ""
echo -e "  FileZilla:"
echo -e "    Host: ${G}bore.pub${N}"
echo -e "    Port: ${G}${BORE_PORT}${N}"
echo -e "    User: ${G}root${N}"
echo -e "    Pass: ${G}2003${N}"
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""

# ══════════════════════════════════════
# SUPERVISOR INDÍTÁS (ez kezeli az ÖSSZES szolgáltatást)
# ══════════════════════════════════════
echo -e "${C}Supervisor indítása...${N}"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
