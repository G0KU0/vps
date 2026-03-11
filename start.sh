#!/bin/bash

C="\033[1;36m"
G="\033[1;32m"
Y="\033[1;33m"
R="\033[1;31m"
W="\033[1;37m"
D="\033[1;90m"
N="\033[0m"

SSH_USER="${SSH_USER:-root}"
SSH_PASS="${SSH_PASS:-2003}"
ROOT_PASS="${ROOT_PASS:-2003}"
PORT="${PORT:-10000}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
BORE_PORT="${BORE_PORT:-48251}"

cleanup() {
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

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

# ══════════════════════════════════════
# 1. ROOT FELHASZNÁLÓ
# ══════════════════════════════════════
echo -e "${C}[1/6]${W} Root hozzáférés beállítása...${N}"
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
sed -i 's|root:x:0:0:root:/root:/usr/sbin/nologin|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
sed -i 's|root:x:0:0:root:/root:/bin/false|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
mkdir -p /root/.ssh 2>/dev/null || true
chmod 700 /root 2>/dev/null || true
mkdir -p /workspace /data 2>/dev/null || true
echo -e "  ${G}✓${N} Root: ${G}root${N} / Jelszó: ${G}${ROOT_PASS}${N}"

# ══════════════════════════════════════
# 2. SSH SZERVER
# ══════════════════════════════════════
echo -e "${C}[2/6]${W} SSH szerver indítása...${N}"
mkdir -p /var/run/sshd 2>/dev/null || true
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A 2>/dev/null || true
fi
/usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
echo -e "  ${G}✓${N} SSH fut (port 22)"

# ══════════════════════════════════════
# 3. BORE TUNNEL — FIX PORT: 48251
# ══════════════════════════════════════
echo -e "${C}[3/6]${W} bore.pub tunnel indítása (fix port: ${BORE_PORT})...${N}"
BORE_LOG="/tmp/bore.log"

# Tunnel info előre beállítva fix porttal
cat > /tmp/tunnel-info.json <<EOF
{
    "status":"active",
    "host":"${BORE_SERVER}",
    "port":"${BORE_PORT}",
    "ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}",
    "user":"root",
    "password":"${ROOT_PASS}",
    "updated":"$(date -Iseconds)"
}
EOF

# bore indítása FIX PORTTAL
(bore local 22 --to "$BORE_SERVER" --port "$BORE_PORT" > "$BORE_LOG" 2>&1) &
BORE_PID=$!

# Várakozás hogy a tunnel tényleg elinduljon
TUNNEL_OK=""
for i in $(seq 1 30); do
    if grep -q "listening" "$BORE_LOG" 2>/dev/null || grep -q "remote" "$BORE_LOG" 2>/dev/null || grep -q "$BORE_PORT" "$BORE_LOG" 2>/dev/null; then
        TUNNEL_OK="yes"
        break
    fi
    sleep 2
done

if [ -n "$TUNNEL_OK" ]; then
    echo -e "  ${G}✓${N} Tunnel aktív: ${Y}${BORE_SERVER}:${BORE_PORT}${N}"
    echo -e "  ${G}✓${N} SSH: ${G}ssh root@${BORE_SERVER} -p ${BORE_PORT}${N}"
else
    echo -e "  ${Y}⚠${N} Tunnel indítás folyamatban — port: ${Y}${BORE_PORT}${N}"
    echo -e "  ${D}  (Ha a port foglalt, a háttérmonitor újrapróbálja)${N}"
fi

# ══════════════════════════════════════
# 4. FÁJLKEZELŐ
# ══════════════════════════════════════
echo -e "${C}[4/6]${W} Webes fájlkezelő indítása...${N}"
FB_DB="/tmp/filebrowser.db"
filebrowser config init --database "$FB_DB" > /dev/null 2>&1 || true
filebrowser config set --address 127.0.0.1 --port 8080 --baseurl /files \
    --root / --database "$FB_DB" --noauth > /dev/null 2>&1 || true
(filebrowser --database "$FB_DB" --noauth --address 127.0.0.1 --port 8080 \
    --baseurl /files --root / > /tmp/filebrowser.log 2>&1) &
sleep 1
echo -e "  ${G}✓${N} Fájlkezelő: ${Y}/files/${N}"

# ══════════════════════════════════════
# 5. WEB TERMINÁL
# ══════════════════════════════════════
echo -e "${C}[5/6]${W} Web terminál indítása...${N}"
(ttyd --port 7681 --writable \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono',monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#a9b1d6","cursor":"#c0caf5"}' \
    --ping-interval 30 \
    bash -l > /tmp/ttyd.log 2>&1) &
sleep 1
echo -e "  ${G}✓${N} Web terminál: ${Y}/terminal/${N}"

# ══════════════════════════════════════
# DASHBOARD HTML
# ══════════════════════════════════════
cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>7oq1_ Ubuntu VPS</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0f0f1a;color:#c0caf5;font-family:'Segoe UI',monospace;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:20px}
.logo{color:#7aa2f7;font-size:10px;line-height:1.2;white-space:pre;text-align:center;margin:20px 0 5px;font-family:monospace}
.sub{color:#565f89;font-size:13px;margin-bottom:20px;text-align:center}
.c{max-width:850px;width:100%}
.card{background:#1a1b2e;border:1px solid #292e42;border-radius:12px;padding:18px;margin-bottom:14px}
.card h2{color:#7aa2f7;font-size:15px;margin-bottom:12px;display:flex;align-items:center;gap:8px}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px}
.dot.on{background:#9ece6a;box-shadow:0 0 8px #9ece6a}
.dot.off{background:#f7768e}
.dot.wait{background:#e0af68;animation:p 1.5s infinite}
@keyframes p{0%,100%{opacity:1}50%{opacity:.3}}
.r{display:flex;justify-content:space-between;padding:7px 10px;border-bottom:1px solid #292e42;font-size:13px}
.r:last-child{border-bottom:none}
.r .l{color:#565f89}
.r .v{color:#c0caf5;font-family:monospace;user-select:all}
.r .v.h{color:#9ece6a;font-weight:bold}
.cmd{background:#13131f;border:1px solid #292e42;border-radius:8px;padding:11px 14px;margin:6px 0;font-family:monospace;font-size:13px;color:#bb9af7;cursor:pointer;transition:border-color .2s;position:relative;word-break:break-all}
.cmd:hover{border-color:#7aa2f7}
.cmd .ch{position:absolute;right:10px;top:50%;transform:translateY(-50%);color:#565f89;font-size:11px}
.cmd.ok .ch{color:#9ece6a}
.btns{display:flex;gap:10px;margin-top:14px;flex-wrap:wrap}
.btn{display:inline-flex;align-items:center;gap:8px;padding:9px 18px;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600;transition:all .2s;border:1px solid transparent;cursor:pointer}
.bp{background:#7aa2f7;color:#1a1b2e}.bp:hover{background:#89b4fa}
.bs{background:#292e42;color:#c0caf5;border-color:#3b4261}.bs:hover{background:#3b4261}
.g{display:grid;grid-template-columns:1fr 1fr;gap:10px}
@media(max-width:650px){.g{grid-template-columns:1fr}}
.sc{text-align:center;padding:14px;background:#13131f;border-radius:8px}
.sv{font-size:20px;font-weight:bold;color:#7aa2f7}
.sl{font-size:11px;color:#565f89;margin-top:2px}
.n{text-align:center;color:#565f89;font-size:11px;margin:8px 0}
.fix{background:#9ece6a22;border:1px solid #9ece6a44;border-radius:8px;padding:10px 14px;margin:8px 0;text-align:center}
.fix b{color:#9ece6a}
</style>
</head>
<body>
<div class="logo">
░▒▓████████▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████▓▒░
        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░
       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░  ░▒▓█▓▒░
      ░▒▓█▓▒░  ░▒▓██████▓▒░ ░▒▓██████▓▒░   ░▒▓█▓▒░
</div>
<div class="sub">Render.com Ubuntu VPS — Modified by 7oq1_</div>
<div class="c">

<div class="card">
<h2>📊 Rendszer</h2>
<div class="g">
<div class="sc"><div class="sv">Ubuntu 24.04</div><div class="sl">OS</div></div>
<div class="sc"><div class="sv" id="cpu">-</div><div class="sl">vCPU</div></div>
<div class="sc"><div class="sv" id="ram">-</div><div class="sl">RAM</div></div>
<div class="sc"><div class="sv" id="disk">-</div><div class="sl">Disk</div></div>
</div>
</div>

<div class="card">
<h2><span class="dot wait" id="td"></span> SSH / SFTP Tunnel</h2>
<div class="fix">🔒 Fix port: <b>48251</b> — ez SOSEM változik!</div>
<div id="ts" style="padding:6px 0;color:#e0af68">⏳ Betöltés...</div>
<div id="tt" style="display:none">
<div class="r"><span class="l">Host</span><span class="v h" id="th">bore.pub</span></div>
<div class="r"><span class="l">Port</span><span class="v h" id="tp">48251</span></div>
<div class="r"><span class="l">Felhasználó</span><span class="v" id="tu">root</span></div>
<div class="r"><span class="l">Jelszó</span><span class="v" id="tw">2003</span></div>
</div>
</div>

<div class="card">
<h2>🔌 SSH csatlakozás</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Ezt futtasd a saját gépeden (MINDIG UGYANEZ):</p>
<div class="cmd" onclick="cc(this)" id="sc"><span>ssh root@bore.pub -p 48251</span><span class="ch">📋 másolás</span></div>
<p style="font-size:12px;color:#565f89;margin-top:8px">Jelszó: <span style="color:#9ece6a;font-weight:bold">2003</span></p>
</div>

<div class="card">
<h2>📁 FileZilla (SFTP)</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Írd be a FileZilla-ba (MINDIG UGYANEZ):</p>
<div class="r"><span class="l">Kiszolgáló (Host)</span><span class="v h">bore.pub</span></div>
<div class="r"><span class="l">Port</span><span class="v h">48251</span></div>
<div class="r"><span class="l">Protokoll</span><span class="v">SFTP</span></div>
<div class="r"><span class="l">Bejelentkezés típusa</span><span class="v">Normál (Normal)</span></div>
<div class="r"><span class="l">Felhasználó</span><span class="v">root</span></div>
<div class="r"><span class="l">Jelszó</span><span class="v">2003</span></div>
</div>

<div class="card">
<h2>🚀 Gyors elérés</h2>
<div class="btns">
<a href="/terminal/" target="_blank" class="btn bp">🖥️ Web Terminál (root)</a>
<a href="/files/" target="_blank" class="btn bs">📂 Fájlkezelő</a>
<button onclick="rf()" class="btn bs">🔄 Frissítés</button>
</div>
</div>

<div class="n">Automatikus frissítés 20 másodpercenként</div>
</div>

<script>
function cc(e){
    const t=e.querySelector('span').textContent;
    navigator.clipboard.writeText(t).then(()=>{
        e.classList.add('ok');
        e.querySelector('.ch').textContent='✅ másolva!';
        setTimeout(()=>{
            e.classList.remove('ok');
            e.querySelector('.ch').textContent='📋 másolás';
        },2000)
    })
}
function rf(){
    fetch('/api/tunnel-info?t='+Date.now())
    .then(r=>r.json())
    .then(d=>{
        const dot=document.getElementById('td');
        const ts=document.getElementById('ts');
        const tt=document.getElementById('tt');
        if(d.status==='active'){
            dot.className='dot on';
            ts.innerHTML='<span style="color:#9ece6a">✅ Tunnel aktív — fix port: 48251</span>';
            ts.style.color='#9ece6a';
            tt.style.display='block';
        } else if(d.status==='connecting'){
            dot.className='dot wait';
            ts.innerHTML='⏳ Tunnel csatlakozás (port: 48251)...';
            ts.style.color='#e0af68';
            tt.style.display='block';
        } else {
            dot.className='dot off';
            ts.innerHTML='❌ Tunnel hiba — /terminal/ oldalon írd be: vps-tunnel-restart';
            ts.style.color='#f7768e';
            tt.style.display='block';
        }
    }).catch(()=>{});
}
rf();
setInterval(rf,20000);
</script>
</body>
</html>
HTMLEOF

# ══════════════════════════════════════
# SEGÉDPARANCSOK
# ══════════════════════════════════════

cat > /usr/local/bin/vps-info << 'VIEOF'
#!/bin/bash
echo ""
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo -e "\033[1;32m  📊  VPS INFORMÁCIÓK\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo "  OS:     $(lsb_release -ds 2>/dev/null || echo 'Ubuntu 24.04')"
echo "  CPU:    $(nproc) vCPU"
echo "  RAM:    $(free -h | awk '/Mem:/{print $7 " szabad / " $2 " össz."}')"
echo "  Disk:   $(df -h / | awk 'NR==2{print $4 " szabad / " $2 " össz."}')"
echo ""
echo -e "\033[1;32m  Tunnel: FIX PORT\033[0m"
echo "  SSH:       ssh root@bore.pub -p 48251"
echo "  Jelszó:    2003"
echo ""
echo "  FileZilla: Host=bore.pub  Port=48251  SFTP  User=root  Pass=2003"
echo ""
if [ -f /tmp/tunnel-info.json ]; then
    S=$(cat /tmp/tunnel-info.json | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "  Tunnel állapot: $S"
fi
echo ""
VIEOF
chmod +x /usr/local/bin/vps-info

cat > /usr/local/bin/vps-tunnel << 'VTEOF'
#!/bin/bash
if [ -f /tmp/tunnel-info.json ]; then
    cat /tmp/tunnel-info.json | jq . 2>/dev/null || cat /tmp/tunnel-info.json
else
    echo "Nincs tunnel info."
fi
echo ""
echo "Fix csatlakozás:"
echo "  SSH:      ssh root@bore.pub -p 48251"
echo "  Jelszó:   2003"
VTEOF
chmod +x /usr/local/bin/vps-tunnel

cat > /usr/local/bin/vps-tunnel-restart << 'VREOF'
#!/bin/bash
BORE_SERVER="${BORE_SERVER:-bore.pub}"
BORE_PORT="${BORE_PORT:-48251}"
echo "Tunnel újraindítás (fix port: ${BORE_PORT})..."
pkill -f "bore local" 2>/dev/null || true
sleep 2
echo '{"status":"connecting","host":"bore.pub","port":"48251","user":"root","password":"2003"}' > /tmp/tunnel-info.json
(bore local 22 --to "$BORE_SERVER" --port "$BORE_PORT" > /tmp/bore.log 2>&1) &
echo "Várakozás (~15mp)..."
for i in $(seq 1 30); do
    if grep -q "listening" /tmp/bore.log 2>/dev/null || grep -q "remote" /tmp/bore.log 2>/dev/null || grep -q "$BORE_PORT" /tmp/bore.log 2>/dev/null; then
        cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${BORE_PORT}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
        echo -e "\033[1;32m✅ Tunnel aktív!\033[0m"
        echo -e "\033[1;32m   SSH:    ssh root@${BORE_SERVER} -p ${BORE_PORT}\033[0m"
        echo -e "\033[1;32m   Jelszó: 2003\033[0m"
        exit 0
    fi
    sleep 2
done
echo -e "\033[1;31m✗ Időtúllépés. Log:\033[0m"
cat /tmp/bore.log 2>/dev/null
echo ""
echo "Próbáld újra: vps-tunnel-restart"
VREOF
chmod +x /usr/local/bin/vps-tunnel-restart

# Root bashrc
cat >> /root/.bashrc << 'BEOF'
if [ -z "$VPS_GREETED" ]; then
    export VPS_GREETED=1
    echo ""
    echo -e "\033[1;36m  Üdvözöllek ROOT!\033[0m"
    echo -e "\033[1;90m  SSH: \033[1;33mssh root@bore.pub -p 48251\033[0m"
    echo -e "\033[1;90m  Írd be: \033[1;33mvps-info\033[1;90m a részletekért\033[0m"
    echo ""
fi
BEOF

# ══════════════════════════════════════
# 6. NGINX
# ══════════════════════════════════════
echo -e "${C}[6/6]${W} Nginx indítása (port: ${PORT})...${N}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# ══════════════════════════════════════
# ÖSSZEFOGLALÓ
# ══════════════════════════════════════
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo -e "${G}          ✅  UBUNTU VPS AUTOMATIKUSAN KÉSZ!${N}"
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""
echo -e "  ${W}Felhasználó:${N} ${G}root${N}"
echo -e "  ${W}Jelszó:${N}      ${G}2003${N}"
echo ""
echo -e "  ${C}──── FIX CSATLAKOZÁSI ADATOK (SOSEM VÁLTOZIK) ────${N}"
echo ""
echo -e "  ${W}SSH:${N}         ${G}ssh root@bore.pub -p 48251${N}"
echo -e "  ${W}Jelszó:${N}      ${G}2003${N}"
echo ""
echo -e "  ${W}FileZilla (SFTP):${N}"
echo -e "    Host:    ${G}bore.pub${N}"
echo -e "    Port:    ${G}48251${N}"
echo -e "    User:    ${G}root${N}"
echo -e "    Pass:    ${G}2003${N}"
echo ""
echo -e "  ${C}──── BÖNGÉSZŐS HOZZÁFÉRÉS ────${N}"
echo ""
echo -e "  ${W}Dashboard:${N}   ${Y}https://<render-url>/${N}"
echo -e "  ${W}Terminál:${N}    ${Y}https://<render-url>/terminal/${N}"
echo -e "  ${W}Fájlkezelő:${N}  ${Y}https://<render-url>/files/${N}"
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"

# ══════════════════════════════════════
# HÁTTÉR MONITOR
# ══════════════════════════════════════
(
    while true; do
        sleep 120

        # bore tunnel ellenőrzés — FIX PORT
        if ! pgrep -f "bore local" >/dev/null 2>&1; then
            echo "[MONITOR] bore tunnel újraindítás (port: ${BORE_PORT})..."
            (bore local 22 --to "$BORE_SERVER" --port "$BORE_PORT" > /tmp/bore.log 2>&1) &
            sleep 15
            if grep -q "listening" /tmp/bore.log 2>/dev/null || grep -q "remote" /tmp/bore.log 2>/dev/null || grep -q "$BORE_PORT" /tmp/bore.log 2>/dev/null; then
                cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${BORE_PORT}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
                echo "[MONITOR] Tunnel aktív: ${BORE_SERVER}:${BORE_PORT}"
            fi
        fi

        # SSH ellenőrzés
        if ! pgrep -x sshd >/dev/null 2>&1; then
            /usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
        fi

        # ttyd ellenőrzés
        if ! pgrep -x ttyd >/dev/null 2>&1; then
            (ttyd --port 7681 --writable -t fontSize=15 --ping-interval 30 bash -l >/tmp/ttyd.log 2>&1) &
        fi

        # filebrowser ellenőrzés
        if ! pgrep -x filebrowser >/dev/null 2>&1; then
            (filebrowser --database /tmp/filebrowser.db --noauth --address 127.0.0.1 --port 8080 --baseurl /files --root / >/tmp/filebrowser.log 2>&1) &
        fi
    done
) &

# ══════════════════════════════════════
# NGINX (FŐ FOLYAMAT)
# ══════════════════════════════════════
exec nginx -g "daemon off;"
