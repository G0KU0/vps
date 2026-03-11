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
# 1. ROOT FELHASZNÁLÓ — TELJES FIX
# ══════════════════════════════════════
echo -e "${C}[1/6]${W} Root hozzáférés beállítása...${N}"

# Root shell beállítása /bin/bash-ra
sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
chsh -s /bin/bash root 2>/dev/null || true

# Root fiók feloldása (Docker-ben alapból zárolva lehet)
passwd -u root 2>/dev/null || true

# Jelszó beállítása
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Shadow fájl fix — eltávolítjuk a zárolást jelző ! és * karaktereket
sed -i 's|^root:!|root:|' /etc/shadow 2>/dev/null || true
sed -i 's|^root:\*|root:|' /etc/shadow 2>/dev/null || true

# Újra beállítjuk a jelszót a shadow fix után
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Root könyvtár beállítás
mkdir -p /root/.ssh 2>/dev/null || true
chmod 700 /root 2>/dev/null || true
chmod 700 /root/.ssh 2>/dev/null || true

# Munkaterületek
mkdir -p /workspace /data 2>/dev/null || true

echo -e "  ${G}✓${N} Root: ${G}root${N} / Jelszó: ${G}${ROOT_PASS}${N}"

# ══════════════════════════════════════
# 2. SSH SZERVER — TELJES ÚJRAKONFIGURÁLÁS
# ══════════════════════════════════════
echo -e "${C}[2/6]${W} SSH szerver konfigurálása és indítása...${N}"

# sshd futtatási könyvtár
mkdir -p /var/run/sshd 2>/dev/null || true
chmod 755 /var/run/sshd 2>/dev/null || true

# SSH host kulcsok ÚJRAGENERÁLÁSA helyes jogosultságokkal
rm -f /etc/ssh/ssh_host_*
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N '' -q 2>/dev/null || true
ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -N '' -q 2>/dev/null || true
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q 2>/dev/null || true

# Jogosultságok fixálása
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
chown root:root /etc/ssh/ssh_host_* 2>/dev/null || true

# TELJES sshd_config FELÜLÍRÁSA — Docker-kompatibilis beállítások
cat > /etc/ssh/sshd_config <<'SSHCFG'
# ======================================
# SSH Server Config — Docker Compatible
# ======================================

# Alap beállítások
Port 22
AddressFamily any
ListenAddress 0.0.0.0

# Host kulcsok
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Bejelentkezés
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# PAM KIKAPCSOLVA — Docker-ben nem működik rendesen
UsePAM no

# Challenge-response kikapcsolva
KbdInteractiveAuthentication no

# SFTP — FileZilla-hoz szükséges
Subsystem sftp /usr/lib/openssh/sftp-server

# Hálózat
AllowTcpForwarding yes
GatewayPorts yes
X11Forwarding no
TCPKeepAlive yes

# Kapcsolat életben tartás
ClientAliveInterval 30
ClientAliveCountMax 120

# Egyéb
PrintMotd yes
PrintLastLog yes
AcceptEnv LANG LC_*
PermitUserEnvironment yes
MaxAuthTries 10
MaxSessions 20
LoginGraceTime 120

# Logging
SyslogFacility AUTH
LogLevel INFO
SSHCFG

echo -e "  ${G}✓${N} sshd_config felülírva (Docker-kompatibilis)"

# SSH config tesztelése
echo -e "  ${D}  SSH konfiguráció tesztelése...${N}"
/usr/sbin/sshd -t 2>/tmp/sshd_test.log
if [ $? -eq 0 ]; then
    echo -e "  ${G}✓${N} SSH konfiguráció: OK"
else
    echo -e "  ${R}✗${N} SSH konfigurációs hiba:"
    cat /tmp/sshd_test.log
    echo -e "  ${Y}  Javítás: KbdInteractiveAuthentication eltávolítása...${N}"
    # Régebbi OpenSSH nem ismeri ezt a direktívát
    sed -i '/KbdInteractiveAuthentication/d' /etc/ssh/sshd_config
    /usr/sbin/sshd -t 2>/tmp/sshd_test2.log
    if [ $? -eq 0 ]; then
        echo -e "  ${G}✓${N} SSH konfiguráció javítva: OK"
    else
        echo -e "  ${R}✗${N} Még mindig hibás:"
        cat /tmp/sshd_test2.log
    fi
fi

# SSH indítása
echo -e "  ${D}  SSH szerver indítása...${N}"
/usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null
SSHD_EXIT=$?

if [ $SSHD_EXIT -eq 0 ]; then
    echo -e "  ${G}✓${N} SSH szerver fut (port 22)"
else
    echo -e "  ${R}✗${N} SSH indítás sikertelen (exit: $SSHD_EXIT)"
    echo -e "  ${D}  Log:${N}"
    cat /tmp/sshd.log 2>/dev/null | tail -20
    # Második próba debug módban
    echo -e "  ${Y}  Újrapróbálás...${N}"
    /usr/sbin/sshd -D -e > /tmp/sshd_debug.log 2>&1 &
    sleep 2
    if pgrep -x sshd >/dev/null 2>&1; then
        echo -e "  ${G}✓${N} SSH szerver fut (2. próba)"
    else
        echo -e "  ${R}✗${N} SSH nem indult el"
        cat /tmp/sshd_debug.log 2>/dev/null | tail -20
    fi
fi

# SSH tesztelése — helyi csatlakozás ellenőrzése
sleep 1
if pgrep -x sshd >/dev/null 2>&1; then
    echo -e "  ${G}✓${N} SSH folyamat fut (PID: $(pgrep -x sshd | head -1))"
else
    echo -e "  ${R}✗${N} SSH folyamat NEM fut!"
fi

# ══════════════════════════════════════
# 3. BORE TUNNEL — FIX PORT: 48251
# ══════════════════════════════════════
echo -e "${C}[3/6]${W} bore.pub tunnel indítása (fix port: ${BORE_PORT})...${N}"
BORE_LOG="/tmp/bore.log"

# Tunnel info beállítása
cat > /tmp/tunnel-info.json <<EOF
{
    "status":"connecting",
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

# Várakozás
TUNNEL_OK=""
for i in $(seq 1 30); do
    if grep -qi "listening" "$BORE_LOG" 2>/dev/null || grep -qi "remote" "$BORE_LOG" 2>/dev/null || grep -q "$BORE_PORT" "$BORE_LOG" 2>/dev/null; then
        TUNNEL_OK="yes"
        break
    fi
    # Ha hiba van a logban, jelezzük
    if grep -qi "error" "$BORE_LOG" 2>/dev/null; then
        echo -e "  ${R}✗${N} bore hiba észlelve:"
        cat "$BORE_LOG"
        break
    fi
    sleep 2
done

if [ -n "$TUNNEL_OK" ]; then
    echo -e "  ${G}✓${N} Tunnel aktív: ${Y}${BORE_SERVER}:${BORE_PORT}${N}"
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
else
    echo -e "  ${Y}⚠${N} Tunnel indítás folyamatban (port: ${BORE_PORT})"
    echo -e "  ${D}  bore log:${N}"
    cat "$BORE_LOG" 2>/dev/null | tail -5
    echo ""
    # Ha a fix port foglalt, próbáljuk port nélkül
    if grep -qi "error" "$BORE_LOG" 2>/dev/null; then
        echo -e "  ${Y}⚠${N} Fix port (${BORE_PORT}) valószínűleg foglalt."
        echo -e "  ${Y}  Próba random porttal...${N}"
        pkill -f "bore local" 2>/dev/null || true
        sleep 1
        (bore local 22 --to "$BORE_SERVER" > "$BORE_LOG" 2>&1) &
        BORE_PID=$!
        sleep 10
        RANDOM_PORT=$(grep -oP '(?<=:)\d{4,5}' "$BORE_LOG" 2>/dev/null | tail -1 || echo "")
        if [ -n "$RANDOM_PORT" ]; then
            BORE_PORT="$RANDOM_PORT"
            echo -e "  ${G}✓${N} Tunnel aktív random porton: ${Y}${BORE_SERVER}:${BORE_PORT}${N}"
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
        fi
    fi
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
<div class="r"><span class="l">Host</span><span class="v h" id="th">bore.pub</span></div>
<div class="r"><span class="l">Port</span><span class="v h" id="tp">48251</span></div>
<div class="r"><span class="l">Felhasználó</span><span class="v" id="tu">root</span></div>
<div class="r"><span class="l">Jelszó</span><span class="v" id="tw">2003</span></div>
</div>
</div>

<div class="card">
<h2>🔌 SSH csatlakozás</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Ezt futtasd a saját gépeden:</p>
<div class="cmd" onclick="cc(this)" id="sc"><span>ssh root@bore.pub -p 48251</span><span class="ch">📋 másolás</span></div>
<p style="font-size:12px;color:#565f89;margin-top:8px">Jelszó: <span style="color:#9ece6a;font-weight:bold">2003</span></p>
<div class="warn">💡 Ha "Connection refused" hibát kapsz, várj 1-2 percet és próbáld újra. Ha továbbra sem megy, nézd meg a /terminal/ oldalt és írd be: <b>vps-tunnel-restart</b></div>
</div>

<div class="card">
<h2>📁 FileZilla (SFTP)</h2>
<p style="font-size:12px;color:#565f89;margin-bottom:8px">Írd be a FileZilla-ba:</p>
<div class="r"><span class="l">Kiszolgáló (Host)</span><span class="v h" id="fh">bore.pub</span></div>
<div class="r"><span class="l">Port</span><span class="v h" id="fp">48251</span></div>
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

<div class="n">Automatikus frissítés 15 másodpercenként</div>
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
            ts.innerHTML='<span style="color:#9ece6a">✅ Tunnel aktív!</span>';
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
            ts.innerHTML='⏳ Tunnel csatlakozás...';
            tt.style.display='block';
        } else {
            dot.className='dot off';
            ts.innerHTML='❌ Tunnel hiba — /terminal/ oldalon: vps-tunnel-restart';
            tt.style.display='block';
        }
    }).catch(()=>{});
}
rf();
setInterval(rf,15000);
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
    S=$(cat /tmp/tunnel-info.json | jq -r '.status' 2>/dev/null || echo "unknown")
    H=$(cat /tmp/tunnel-info.json | jq -r '.host' 2>/dev/null || echo "bore.pub")
    P=$(cat /tmp/tunnel-info.json | jq -r '.port' 2>/dev/null || echo "48251")
    echo "  Tunnel:  $S"
    echo "  SSH:     ssh root@${H} -p ${P}"
    echo "  Jelszó:  2003"
    echo ""
    echo "  FileZilla: Host=${H}  Port=${P}  SFTP  User=root  Pass=2003"
fi
echo ""
echo "  SSH folyamat: $(pgrep -x sshd >/dev/null 2>&1 && echo 'FUT' || echo 'NEM FUT')"
echo "  bore folyamat: $(pgrep -f 'bore local' >/dev/null 2>&1 && echo 'FUT' || echo 'NEM FUT')"
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
echo "SSH:     ssh root@bore.pub -p 48251"
echo "Jelszó:  2003"
echo ""
echo "bore log:"
cat /tmp/bore.log 2>/dev/null | tail -10
VTEOF
chmod +x /usr/local/bin/vps-tunnel

cat > /usr/local/bin/vps-tunnel-restart << 'VREOF'
#!/bin/bash
BORE_SERVER="${BORE_SERVER:-bore.pub}"
BORE_PORT="${BORE_PORT:-48251}"
echo ""
echo "═══════════════════════════════════"
echo "  Tunnel újraindítás"
echo "═══════════════════════════════════"
echo ""

# SSH ellenőrzés
echo "[1/3] SSH szerver ellenőrzése..."
if ! pgrep -x sshd >/dev/null 2>&1; then
    echo "  SSH nem fut — újraindítás..."
    /usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
    sleep 1
fi
if pgrep -x sshd >/dev/null 2>&1; then
    echo "  ✓ SSH fut"
else
    echo "  ✗ SSH NEM fut! Debug log:"
    /usr/sbin/sshd -d -e 2>&1 | head -20
fi

# bore leállítás
echo ""
echo "[2/3] bore tunnel leállítása..."
pkill -f "bore local" 2>/dev/null || true
sleep 3

# bore újraindítás
echo ""
echo "[3/3] bore tunnel indítása (port: ${BORE_PORT})..."
echo '{"status":"connecting","host":"bore.pub","port":"'${BORE_PORT}'","user":"root","password":"2003"}' > /tmp/tunnel-info.json
(bore local 22 --to "$BORE_SERVER" --port "$BORE_PORT" > /tmp/bore.log 2>&1) &
echo "  Várakozás (~20mp)..."

for i in $(seq 1 30); do
    if grep -qi "listening" /tmp/bore.log 2>/dev/null || grep -qi "remote" /tmp/bore.log 2>/dev/null || grep -q "$BORE_PORT" /tmp/bore.log 2>/dev/null; then
        cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${BORE_PORT}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
        echo ""
        echo -e "\033[1;32m✅ Tunnel aktív!\033[0m"
        echo -e "\033[1;32m   SSH:    ssh root@${BORE_SERVER} -p ${BORE_PORT}\033[0m"
        echo -e "\033[1;32m   Jelszó: 2003\033[0m"
        echo ""
        exit 0
    fi
    if grep -qi "error" /tmp/bore.log 2>/dev/null; then
        echo ""
        echo -e "\033[1;31m✗ bore hiba:\033[0m"
        cat /tmp/bore.log
        echo ""
        echo "Próba random porttal..."
        pkill -f "bore local" 2>/dev/null || true
        sleep 2
        (bore local 22 --to "$BORE_SERVER" > /tmp/bore.log 2>&1) &
        sleep 10
        RP=$(grep -oP '(?<=:)\d{4,5}' /tmp/bore.log 2>/dev/null | tail -1 || echo "")
        if [ -n "$RP" ]; then
            cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${RP}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${RP}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
            echo -e "\033[1;32m✅ Tunnel aktív random porton: ${RP}\033[0m"
            echo -e "\033[1;32m   SSH:    ssh root@${BORE_SERVER} -p ${RP}\033[0m"
            exit 0
        fi
        exit 1
    fi
    sleep 2
done
echo ""
echo -e "\033[1;31m✗ Időtúllépés.\033[0m"
echo "bore log:"
cat /tmp/bore.log 2>/dev/null
echo ""
echo "Próbáld: vps-tunnel-restart"
VREOF
chmod +x /usr/local/bin/vps-tunnel-restart

# SSH debug parancs
cat > /usr/local/bin/vps-ssh-debug << 'SDEOF'
#!/bin/bash
echo ""
echo "═══════════════════════════════════"
echo "  SSH DEBUG INFORMÁCIÓK"
echo "═══════════════════════════════════"
echo ""
echo "1. SSH folyamat:"
pgrep -xa sshd 2>/dev/null || echo "  NEM FUT!"
echo ""
echo "2. SSH port:"
ss -tlnp 2>/dev/null | grep :22 || echo "  Port 22 nem figyel!"
echo ""
echo "3. Root fiók:"
grep "^root:" /etc/passwd
echo ""
echo "4. Root shadow (zárolva?):"
S=$(grep "^root:" /etc/shadow | cut -d: -f2 | head -c 3)
if echo "$S" | grep -q '!' || echo "$S" | grep -q '*'; then
    echo "  ⚠ ROOT FIÓK ZÁROLVA! Javítás: passwd -u root && echo root:2003 | chpasswd"
else
    echo "  ✓ Root fiók aktív"
fi
echo ""
echo "5. SSH konfig teszt:"
/usr/sbin/sshd -t 2>&1
echo ""
echo "6. sshd log (utolsó 20 sor):"
cat /tmp/sshd.log 2>/dev/null | tail -20
echo ""
echo "7. bore log (utolsó 10 sor):"
cat /tmp/bore.log 2>/dev/null | tail -10
echo ""
SDEOF
chmod +x /usr/local/bin/vps-ssh-debug

# Root bashrc
cat > /root/.bashrc << 'BEOF'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export TERM=xterm-256color

if [ -z "$VPS_GREETED" ]; then
    export VPS_GREETED=1
    echo ""
    echo -e "\033[1;36m  ═══════════════════════════════════════\033[0m"
    echo -e "\033[1;36m   Üdvözöllek ROOT! — 7oq1_ VPS\033[0m"
    echo -e "\033[1;36m  ═══════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;90m  Parancsok:\033[0m"
    echo -e "\033[1;33m    vps-info\033[1;90m           → Rendszer & tunnel infó\033[0m"
    echo -e "\033[1;33m    vps-tunnel\033[1;90m         → Tunnel állapot\033[0m"
    echo -e "\033[1;33m    vps-tunnel-restart\033[1;90m → Tunnel újraindítás\033[0m"
    echo -e "\033[1;33m    vps-ssh-debug\033[1;90m      → SSH hibakeresés\033[0m"
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
echo -e "  ${C}──── CSATLAKOZÁSI ADATOK ────${N}"
echo ""
echo -e "  ${W}SSH:${N}         ${G}ssh root@${BORE_SERVER} -p ${BORE_PORT}${N}"
echo -e "  ${W}Jelszó:${N}      ${G}2003${N}"
echo ""
echo -e "  ${W}FileZilla (SFTP):${N}"
echo -e "    Host:    ${G}${BORE_SERVER}${N}"
echo -e "    Port:    ${G}${BORE_PORT}${N}"
echo -e "    User:    ${G}root${N}"
echo -e "    Pass:    ${G}2003${N}"
echo ""
echo -e "  ${C}──── BÖNGÉSZŐ ────${N}"
echo ""
echo -e "  ${W}Dashboard:${N}   ${Y}https://<render-url>/${N}"
echo -e "  ${W}Terminál:${N}    ${Y}https://<render-url>/terminal/${N}"
echo -e "  ${W}Fájlkezelő:${N}  ${Y}https://<render-url>/files/${N}"
echo ""
echo -e "  ${C}──── SZOLGÁLTATÁSOK ────${N}"
echo ""
echo -e "  SSH:         $(pgrep -x sshd >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo -e "  bore:        $(pgrep -f 'bore local' >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo -e "  ttyd:        $(pgrep -x ttyd >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo -e "  filebrowser: $(pgrep -x filebrowser >/dev/null 2>&1 && echo -e "${G}FUT${N}" || echo -e "${R}NEM FUT${N}")"
echo -e "  nginx:       ${G}INDUL${N}"
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"

# ══════════════════════════════════════
# HÁTTÉR MONITOR
# ══════════════════════════════════════
(
    while true; do
        sleep 90

        # bore tunnel ellenőrzés
        if ! pgrep -f "bore local" >/dev/null 2>&1; then
            echo "[MONITOR] bore tunnel újraindítás (port: ${BORE_PORT})..."
            (bore local 22 --to "$BORE_SERVER" --port "$BORE_PORT" > /tmp/bore.log 2>&1) &
            sleep 15
            if grep -qi "listening" /tmp/bore.log 2>/dev/null || grep -qi "remote" /tmp/bore.log 2>/dev/null || grep -q "$BORE_PORT" /tmp/bore.log 2>/dev/null; then
                cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${BORE_PORT}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${BORE_PORT}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
                echo "[MONITOR] Tunnel aktív: ${BORE_SERVER}:${BORE_PORT}"
            else
                # Próba random porttal ha fix port nem megy
                if grep -qi "error" /tmp/bore.log 2>/dev/null; then
                    pkill -f "bore local" 2>/dev/null || true
                    sleep 2
                    (bore local 22 --to "$BORE_SERVER" > /tmp/bore.log 2>&1) &
                    sleep 15
                    NP=$(grep -oP '(?<=:)\d{4,5}' /tmp/bore.log 2>/dev/null | tail -1 || echo "")
                    if [ -n "$NP" ]; then
                        cat > /tmp/tunnel-info.json <<EOF
{"status":"active","host":"${BORE_SERVER}","port":"${NP}","ssh_cmd":"ssh root@${BORE_SERVER} -p ${NP}","user":"root","password":"2003","updated":"$(date -Iseconds)"}
EOF
                        echo "[MONITOR] Tunnel aktív random porton: ${NP}"
                    fi
                fi
            fi
        fi

        # SSH ellenőrzés
        if ! pgrep -x sshd >/dev/null 2>&1; then
            echo "[MONITOR] SSH újraindítás..."
            /usr/sbin/sshd -E /tmp/sshd.log 2>/dev/null || true
        fi

        # Root fiók ellenőrzés (zárolva lehet-e)
        if grep "^root:" /etc/shadow 2>/dev/null | grep -q "^root:!" ; then
            echo "[MONITOR] Root fiók zárolva — feloldás..."
            passwd -u root 2>/dev/null || true
            echo "root:2003" | chpasswd 2>/dev/null || true
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
