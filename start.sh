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
BORE_SERVER="${BORE_SERVER:-bore.pub}"

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
echo -e "${C}[1/6]${W} Root beállítása...${N}"

# Shell fix
sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true

# Fiók feloldás
passwd -u root 2>/dev/null || true

# Shadow fix — ! és * eltávolítása
SHADOW_HASH=$(grep "^root:" /etc/shadow 2>/dev/null | cut -d: -f2)
if echo "$SHADOW_HASH" | grep -qE '^[!*]'; then
    echo -e "  ${Y}⚠${N} Root fiók zárolva volt — feloldás..."
fi

# Jelszó beállítás
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Újra feloldjuk a chpasswd után is
passwd -u root 2>/dev/null || true

mkdir -p /root/.ssh /workspace /data 2>/dev/null || true
chmod 700 /root /root/.ssh 2>/dev/null || true

echo -e "  ${G}✓${N} Root: ${G}root${N} / Jelszó: ${G}${ROOT_PASS}${N}"

# Ellenőrzés
SHADOW_CHECK=$(grep "^root:" /etc/shadow 2>/dev/null | cut -d: -f2 | head -c 1)
if [ "$SHADOW_CHECK" = "!" ] || [ "$SHADOW_CHECK" = "*" ]; then
    echo -e "  ${R}✗${N} Root ZÁROLVA maradt! Brute-force fix..."
    sed -i 's|^root:!|root:|' /etc/shadow 2>/dev/null || true
    sed -i 's|^root:\*|root:|' /etc/shadow 2>/dev/null || true
    echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
fi
echo ""

# ══════════════════════════════════════
# 2. SSH SZERVER
# ══════════════════════════════════════
echo -e "${C}[2/6]${W} SSH szerver indítása...${N}"

mkdir -p /var/run/sshd 2>/dev/null || true
chmod 755 /var/run/sshd 2>/dev/null || true

# Host kulcsok ellenőrzés
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo -e "  ${D}Host kulcsok generálása...${N}"
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N '' -q 2>/dev/null || true
    ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -N '' -q 2>/dev/null || true
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q 2>/dev/null || true
fi
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true

# Config teszt
/usr/sbin/sshd -t 2>/tmp/sshd_test.log
if [ $? -ne 0 ]; then
    echo -e "  ${R}✗${N} Config hiba — javítás..."
    cat /tmp/sshd_test.log
fi

# SSH indítás
/usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
sleep 1

# Ellenőrzés
if pgrep -x sshd >/dev/null 2>&1; then
    echo -e "  ${G}✓${N} SSH szerver FUT (PID: $(pgrep -x sshd | head -1))"
else
    echo -e "  ${R}✗${N} SSH NEM indult — debug:"
    cat /tmp/sshd.log 2>/dev/null | tail -10
    echo -e "  ${Y}  Újrapróbálás -D módban...${N}"
    /usr/sbin/sshd -D -E /tmp/sshd.log 2>/dev/null &
    sleep 2
    if pgrep -x sshd >/dev/null 2>&1; then
        echo -e "  ${G}✓${N} SSH fut (2. próba)"
    fi
fi

# Helyi SSH teszt
echo -e "  ${D}Helyi SSH teszt...${N}"
if ss -tlnp 2>/dev/null | grep -q ":22 "; then
    echo -e "  ${G}✓${N} Port 22 figyel"
else
    echo -e "  ${R}✗${N} Port 22 NEM figyel!"
    ss -tlnp 2>/dev/null
fi
echo ""

# ══════════════════════════════════════
# 3. BORE TUNNEL — RANDOM PORT (mindig működik)
# ══════════════════════════════════════
echo -e "${C}[3/6]${W} bore.pub tunnel indítása...${N}"
echo -e "  ${D}(bore.pub random portot ad — MINDIG működik)${N}"

BORE_LOG="/tmp/bore.log"
echo '{"status":"connecting","host":"bore.pub","port":"","user":"root","password":"2003"}' > /tmp/tunnel-info.json

# Régi bore leállítása
pkill -f "bore local" 2>/dev/null || true
sleep 1

# bore indítása RANDOM porttal (NEM használunk --port-ot!)
(bore local 22 --to "$BORE_SERVER" > "$BORE_LOG" 2>&1) &
BORE_PID=$!

# Port kiolvasása a bore kimenetéből
BORE_PORT=""
echo -e "  ${D}Várakozás a tunnel-re...${N}"
for i in $(seq 1 45); do
    # bore kimenet: "listening at bore.pub:XXXXX"
    if [ -f "$BORE_LOG" ]; then
        BORE_PORT=$(grep -oE 'bore\.pub:[0-9]+' "$BORE_LOG" 2>/dev/null | grep -oE '[0-9]+$' | tail -1 || echo "")
        if [ -z "$BORE_PORT" ]; then
            BORE_PORT=$(grep -oE 'remote_port=[0-9]+' "$BORE_LOG" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "")
        fi
        if [ -z "$BORE_PORT" ]; then
            BORE_PORT=$(grep -oE ':[0-9]{4,5}' "$BORE_LOG" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "")
        fi
    fi

    if [ -n "$BORE_PORT" ]; then
        break
    fi

    # Hiba ellenőrzés
    if grep -qi "error\|panic\|failed" "$BORE_LOG" 2>/dev/null; then
        echo -e "  ${R}✗${N} bore hiba:"
        cat "$BORE_LOG" 2>/dev/null
        echo ""
        # Újrapróbálás
        echo -e "  ${Y}  Újrapróbálás...${N}"
        pkill -f "bore local" 2>/dev/null || true
        sleep 3
        (bore local 22 --to "$BORE_SERVER" > "$BORE_LOG" 2>&1) &
        BORE_PID=$!
    fi

    sleep 2
done

if [ -n "$BORE_PORT" ]; then
    echo -e "  ${G}✓${N} Tunnel AKTÍV!"
    echo -e "  ${G}✓${N} Cím: ${Y}${BORE_SERVER}:${BORE_PORT}${N}"
    echo -e "  ${G}✓${N} SSH: ${G}ssh root@${BORE_SERVER} -p ${BORE_PORT}${N}"

    cat > /tmp/tunnel-info.json <<EOF
{
    "status":"active",
    "host":"${BORE_SERVER}",
    "port":"${BORE_PORT}",
    "ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}",
    "user":"root",
    "password":"2003",
    "updated":"$(date -Iseconds)"
}
EOF
else
    echo -e "  ${R}✗${N} Tunnel NEM jött létre!"
    echo -e "  ${D}bore log:${N}"
    cat "$BORE_LOG" 2>/dev/null
    echo ""
    echo -e "  ${Y}A háttérmonitor 90 másodpercenként próbálja újra.${N}"
    echo -e "  ${Y}Vagy a web terminálban: vps-tunnel-restart${N}"
fi
echo ""

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
echo ""

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
echo ""

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
.warn{background:#e0af6822;border:1px solid #e0af6844;border-radius:8px;padding:10px 14px;margin:8px 0;font-size:12px;color:#e0af68}
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
<div id="ts" style="padding:6px 0;color:#e0af68">⏳ Betöltés...</div>
<div id="tt" style="display:none">
<div class="r"><span class="l">Host</span><span class="v h" id="th">-</span></div>
<div class="r"><span class="l">Port</span><span class="v h" id="tp">-</span></div>
<div class="r"><span class="l">Felhasználó</span><span class="v" id="tu">root</span></div>
<div class="r"><span class="l">Jelszó</span><span class="v" id="tw">2003</span></div>
</div>
</div>

<div class="card">
<h2>🔌 SSH csatlakozás</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Ezt futtasd a saját gépeden:</p>
<div class="cmd" onclick="cc(this)" id="sc"><span>ssh root@bore.pub -p XXXXX</span><span class="ch">📋 másolás</span></div>
<p style="font-size:12px;color:#565f89;margin-top:8px">Jelszó: <span style="color:#9ece6a;font-weight:bold">2003</span></p>
<div class="warn">💡 A port szám a Tunnel kártyán látható fent. Újraindításnál változhat!</div>
</div>

<div class="card">
<h2>📁 FileZilla (SFTP)</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Írd be a FileZilla-ba:</p>
<div class="r"><span class="l">Kiszolgáló (Host)</span><span class="v h" id="fh">bore.pub</span></div>
<div class="r"><span class="l">Port</span><span class="v h" id="fp">-</span></div>
<div class="r"><span class="l">Protokoll</span><span class="v">SFTP</span></div>
<div class="r"><span class="l">Bejelentkezés típusa</span><span class="v">Normál (Normal)</span></div>
<div class="r"><span class="l">Felhasználó</span><span class="v" id="fu">root</span></div>
<div class="r"><span class="l">Jelszó</span><span class="v" id="fw">2003</span></div>
</div>

<div class="card">
<h2>🚀 Gyors elérés</h2>
<div class="btns">
<a href="/terminal/" target="_blank" class="btn bp">🖥️ Web Terminál (root)</a>
<a href="/files/" target="_blank" class="btn bs">📂 Fájlkezelő</a>
<button onclick="rf()" class="btn bs">🔄 Frissítés</button>
</div>
</div>

<div class="n">Automatikus frissítés 10 másodpercenként</div>
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
        if(d.status==='active' && d.port){
            dot.className='dot on';
            ts.innerHTML='<span style="color:#9ece6a">✅ Tunnel aktív! Port: <b>'+d.port+'</b></span>';
            tt.style.display='block';
            document.getElementById('th').textContent=d.host;
            document.getElementById('tp').textContent=d.port;
            document.getElementById('tu').textContent=d.user||'root';
            document.getElementById('tw').textContent=d.password||'2003';
            document.getElementById('sc').querySelector('span').textContent=d.ssh_cmd;
            document.getElementById('fh').textContent=d.host;
            document.getElementById('fp').textContent=d.port;
            document.getElementById('fu').textContent=d.user||'root';
            document.getElementById('fw').textContent=d.password||'2003';
        } else if(d.status==='connecting'){
            dot.className='dot wait';
            ts.innerHTML='⏳ Tunnel csatlakozás folyamatban...';
            tt.style.display='none';
        } else {
            dot.className='dot off';
            ts.innerHTML='❌ Tunnel nem elérhető — /terminal/ oldalon: <b>vps-tunnel-restart</b>';
            tt.style.display='none';
        }
    }).catch(()=>{});
}
rf();
setInterval(rf,10000);
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
if [ -f /tmp/tunnel-info.json ]; then
    S=$(cat /tmp/tunnel-info.json | jq -r '.status' 2>/dev/null || echo "?")
    H=$(cat /tmp/tunnel-info.json | jq -r '.host' 2>/dev/null || echo "?")
    P=$(cat /tmp/tunnel-info.json | jq -r '.port' 2>/dev/null || echo "?")
    if [ "$S" = "active" ] && [ -n "$P" ] && [ "$P" != "null" ] && [ "$P" != "" ]; then
        echo -e "\033[1;32m  Tunnel: AKTÍV\033[0m"
        echo "  SSH:       ssh root@${H} -p ${P}"
        echo "  Jelszó:    2003"
        echo ""
        echo "  FileZilla: Host=${H}  Port=${P}  SFTP  User=root  Pass=2003"
    else
        echo -e "\033[1;33m  Tunnel: ${S}\033[0m"
        echo "  Futtasd: vps-tunnel-restart"
    fi
fi
echo ""
echo "  SSH proc:  $(pgrep -x sshd >/dev/null 2>&1 && echo 'FUT' || echo 'NEM FUT')"
echo "  bore proc: $(pgrep -f 'bore local' >/dev/null 2>&1 && echo 'FUT' || echo 'NEM FUT')"
echo "  Port 22:   $(ss -tlnp 2>/dev/null | grep -q ':22 ' && echo 'FIGYEL' || echo 'NEM FIGYEL')"
echo ""
VIEOF
chmod +x /usr/local/bin/vps-info

cat > /usr/local/bin/vps-tunnel << 'VTEOF'
#!/bin/bash
echo ""
echo "=== TUNNEL INFO ==="
if [ -f /tmp/tunnel-info.json ]; then
    cat /tmp/tunnel-info.json | jq . 2>/dev/null || cat /tmp/tunnel-info.json
fi
echo ""
echo "=== BORE LOG (utolsó 15 sor) ==="
cat /tmp/bore.log 2>/dev/null | tail -15
echo ""
echo "=== BORE FOLYAMAT ==="
pgrep -fa "bore local" 2>/dev/null || echo "NEM FUT"
echo ""
VTEOF
chmod +x /usr/local/bin/vps-tunnel

cat > /usr/local/bin/vps-tunnel-restart << 'VREOF'
#!/bin/bash
BORE_SERVER="${BORE_SERVER:-bore.pub}"
echo ""
echo "═══════════════════════════════════"
echo "  TUNNEL ÚJRAINDÍTÁS"
echo "═══════════════════════════════════"
echo ""

# 1. SSH ellenőrzés
echo "[1/3] SSH ellenőrzés..."
if ! pgrep -x sshd >/dev/null 2>&1; then
    echo "  SSH nem fut — indítás..."
    /usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
    sleep 1
fi
if pgrep -x sshd >/dev/null 2>&1; then
    echo "  ✓ SSH fut"
else
    echo "  ✗ SSH NEM FUT!"
fi
if ss -tlnp 2>/dev/null | grep -q ":22 "; then
    echo "  ✓ Port 22 figyel"
else
    echo "  ✗ Port 22 nem figyel!"
fi

# 2. bore leállítás
echo ""
echo "[2/3] bore leállítás..."
pkill -f "bore local" 2>/dev/null || true
sleep 3

# 3. bore indítás (random port)
echo ""
echo "[3/3] bore indítás..."
echo '{"status":"connecting"}' > /tmp/tunnel-info.json
(bore local 22 --to "$BORE_SERVER" > /tmp/bore.log 2>&1) &
echo "  Várakozás..."

for i in $(seq 1 45); do
    P=""
    if [ -f /tmp/bore.log ]; then
        P=$(grep -oE 'bore\.pub:[0-9]+' /tmp/bore.log 2>/dev/null | grep -oE '[0-9]+$' | tail -1 || echo "")
        if [ -z "$P" ]; then
            P=$(grep -oE 'remote_port=[0-9]+' /tmp/bore.log 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "")
        fi
        if [ -z "$P" ]; then
            P=$(grep -oE ':[0-9]{4,5}' /tmp/bore.log 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "")
        fi
    fi
    if [ -n "$P" ]; then
        cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${P}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${P}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
        echo ""
        echo -e "\033[1;32m✅ Tunnel AKTÍV!\033[0m"
        echo -e "\033[1;32m   SSH:      ssh root@${BORE_SERVER} -p ${P}\033[0m"
        echo -e "\033[1;32m   Jelszó:   2003\033[0m"
        echo -e "\033[1;32m   FileZilla: Host=${BORE_SERVER} Port=${P} SFTP\033[0m"
        echo ""
        exit 0
    fi

    if grep -qiE "error|panic|failed" /tmp/bore.log 2>/dev/null; then
        echo ""
        echo -e "\033[1;31m✗ bore hiba:\033[0m"
        cat /tmp/bore.log 2>/dev/null
        echo ""
        echo "Újrapróbálás 5 mp múlva..."
        pkill -f "bore local" 2>/dev/null || true
        sleep 5
        (bore local 22 --to "$BORE_SERVER" > /tmp/bore.log 2>&1) &
    fi

    sleep 2
done

echo ""
echo -e "\033[1;31m✗ Időtúllépés.\033[0m"
echo "bore log:"
cat /tmp/bore.log 2>/dev/null
echo ""
VREOF
chmod +x /usr/local/bin/vps-tunnel-restart

cat > /usr/local/bin/vps-ssh-debug << 'SDEOF'
#!/bin/bash
echo ""
echo "═══════════════════════════════════"
echo "  SSH DEBUG"
echo "═══════════════════════════════════"
echo ""
echo "1. sshd folyamat:"
pgrep -xa sshd 2>/dev/null || echo "  NEM FUT!"
echo ""
echo "2. Port 22:"
ss -tlnp 2>/dev/null | grep :22 || echo "  NEM FIGYEL!"
echo ""
echo "3. Root passwd entry:"
grep "^root:" /etc/passwd
echo ""
echo "4. Root shadow (első 10 karakter):"
grep "^root:" /etc/shadow | cut -d: -f2 | head -c 10
echo "..."
echo ""
echo "5. Root zárolva?"
S=$(grep "^root:" /etc/shadow | cut -d: -f2 | head -c 1)
if [ "$S" = "!" ] || [ "$S" = "*" ]; then
    echo "  ⚠ IGEN — ZÁROLVA!"
    echo "  Javítás: passwd -u root && echo root:2003 | chpasswd"
else
    echo "  ✓ NEM zárolva"
fi
echo ""
echo "6. sshd_config teszt:"
/usr/sbin/sshd -t 2>&1
echo ""
echo "7. sshd log (utolsó 20 sor):"
cat /tmp/sshd.log 2>/dev/null | tail -20
echo ""
echo "8. bore log (utolsó 10 sor):"
cat /tmp/bore.log 2>/dev/null | tail -10
echo ""
echo "9. bore folyamat:"
pgrep -fa "bore local" 2>/dev/null || echo "  NEM FUT!"
echo ""
SDEOF
chmod +x /usr/local/bin/vps-ssh-debug

# Root bashrc
cat > /root/.bashrc << 'BEOF'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export TERM=xterm-256color
export BORE_SERVER="${BORE_SERVER:-bore.pub}"

if [ -z "$VPS_GREETED" ]; then
    export VPS_GREETED=1
    echo ""
    echo -e "\033[1;36m  ═════════════════════════════════\033[0m"
    echo -e "\033[1;36m   7oq1_ VPS — Üdvözöllek ROOT!\033[0m"
    echo -e "\033[1;36m  ═════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;33m  vps-info\033[1;90m            → Infó + SSH cím\033[0m"
    echo -e "\033[1;33m  vps-tunnel-restart\033[1;90m  → Tunnel újraindítás\033[0m"
    echo -e "\033[1;33m  vps-ssh-debug\033[1;90m       → SSH hibakeresés\033[0m"
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
echo -e "${G}          ✅  UBUNTU VPS KÉSZ!${N}"
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""
echo -e "  ${W}Felhasználó:${N} ${G}root${N}"
echo -e "  ${W}Jelszó:${N}      ${G}2003${N}"
echo ""
if [ -n "$BORE_PORT" ]; then
    echo -e "  ${W}SSH:${N}  ${G}ssh root@${BORE_SERVER} -p ${BORE_PORT}${N}"
    echo -e "  ${W}Pass:${N} ${G}2003${N}"
    echo ""
    echo -e "  ${W}FileZilla:${N}"
    echo -e "    Host: ${G}${BORE_SERVER}${N}"
    echo -e "    Port: ${G}${BORE_PORT}${N}"
    echo -e "    User: ${G}root${N}"
    echo -e "    Pass: ${G}2003${N}"
else
    echo -e "  ${Y}Tunnel még csatlakozik — nézd a dashboardot${N}"
fi
echo ""
echo -e "  ${W}Böngésző:${N}"
echo -e "    ${Y}https://<render-url>/${N}          Dashboard"
echo -e "    ${Y}https://<render-url>/terminal/${N}  Terminál"
echo -e "    ${Y}https://<render-url>/files/${N}     Fájlkezelő"
echo ""
echo -e "  ${W}Szolgáltatások:${N}"
echo -e "  SSH:         $(pgrep -x sshd >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo -e "  Port 22:     $(ss -tlnp 2>/dev/null | grep -q ':22 ' && echo -e "${G}FIGYEL${N}" || echo -e "${R}NEM${N}")"
echo -e "  bore:        $(pgrep -f 'bore local' >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"

# ══════════════════════════════════════
# HÁTTÉR MONITOR
# ══════════════════════════════════════
(
    while true; do
        sleep 90

        # Root fiók ellenőrzés
        SCHECK=$(grep "^root:" /etc/shadow 2>/dev/null | cut -d: -f2 | head -c 1)
        if [ "$SCHECK" = "!" ] || [ "$SCHECK" = "*" ]; then
            passwd -u root 2>/dev/null || true
            echo "root:2003" | chpasswd 2>/dev/null || true
        fi

        # SSH ellenőrzés
        if ! pgrep -x sshd >/dev/null 2>&1; then
            /usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
        fi

        # bore ellenőrzés
        if ! pgrep -f "bore local" >/dev/null 2>&1; then
            (bore local 22 --to "$BORE_SERVER" > /tmp/bore.log 2>&1) &
            sleep 20
            NP=""
            if [ -f /tmp/bore.log ]; then
                NP=$(grep -oE 'bore\.pub:[0-9]+' /tmp/bore.log 2>/dev/null | grep -oE '[0-9]+$' | tail -1 || echo "")
                if [ -z "$NP" ]; then
                    NP=$(grep -oE ':[0-9]{4,5}' /tmp/bore.log 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "")
                fi
            fi
            if [ -n "$NP" ]; then
                cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${NP}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${NP}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
            fi
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
