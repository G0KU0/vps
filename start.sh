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
echo -e "${D}           Render.com VPS | ${C}Modified by szaby${N}"
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""

# ══════════════════════════════════════
# 1. FELHASZNÁLÓK
# ══════════════════════════════════════
echo -e "${C}[1/6]${W} Felhasználók...${N}"
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
mkdir -p /workspace /data /root/.ssh 2>/dev/null || true
echo -e "  ${G}✓${N} Root: ${G}root${N} / Jelszó: ${G}${ROOT_PASS}${N}"

# ══════════════════════════════════════
# 2. NGINX
# ══════════════════════════════════════
echo -e "${C}[2/6]${W} Nginx konfiguráció...${N}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t 2>/dev/null && echo -e "  ${G}✓${N} Nginx config OK" || echo -e "  ${R}✗${N} Nginx hiba"

# ══════════════════════════════════════
# 3. BORE WRAPPER
# ══════════════════════════════════════
echo -e "${C}[3/6]${W} bore tunnel wrapper...${N}"
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

# ══════════════════════════════════════
# 4. SFTP FRISSÍTŐ
# ══════════════════════════════════════
echo -e "${C}[4/6]${W} SFTP frissítő...${N}"

cat > /var/www/html/sftp.txt << EOF
Tunnel indítása (port: ${BORE_PORT})...
Várj 15 másodpercet!

ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
EOF

cat > /tmp/tunnel-info.json << EOF
{"status":"connecting","host":"bore.pub","port":"${BORE_PORT}","ssh_cmd":"ssh root@bore.pub -p ${BORE_PORT}","user":"root","password":"${ROOT_PASS}"}
EOF

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

# ══════════════════════════════════════
# 5. PERSISTENT PROCESS KEZELŐ
# ══════════════════════════════════════
echo -e "${C}[5/6]${W} Persistent Process Kezelő...${N}"

mkdir -p /root/.bg-processes

# ── bg-start ──
cat > /usr/local/bin/bg-start << 'BGSTART'
#!/bin/bash
if [ $# -lt 2 ]; then
    echo ""
    echo -e "\033[1;36m  bg-start — Háttérfolyamat indítása\033[0m"
    echo ""
    echo "  Használat:"
    echo "    bg-start <név> <parancs>"
    echo ""
    echo "  Példák:"
    echo "    bg-start mybot 'python3 bot.py'"
    echo "    bg-start webserver 'node server.js'"
    echo "    bg-start miner './xmrig --config config.json'"
    echo "    bg-start monitor 'htop'"
    echo "    bg-start script 'bash /root/script.sh'"
    echo ""
    echo "  A folyamat SSH kilépés után is fut!"
    echo "  Csatlakozás: bg-attach <név>"
    echo ""
    exit 1
fi

NAME="$1"
shift
CMD="$*"
LOG_DIR="/root/.bg-processes"
LOG_FILE="${LOG_DIR}/${NAME}.log"
CMD_FILE="${LOG_DIR}/${NAME}.cmd"

mkdir -p "$LOG_DIR"

if tmux has-session -t "bg-${NAME}" 2>/dev/null; then
    echo -e "\033[1;33m⚠ '${NAME}' már fut!\033[0m"
    echo "  Leállítás: bg-stop ${NAME}"
    echo "  Újraindítás: bg-restart ${NAME}"
    echo "  Csatlakozás: bg-attach ${NAME}"
    exit 1
fi

echo "$CMD" > "$CMD_FILE"

tmux new-session -d -s "bg-${NAME}" "echo '═══════════════════════════════════════' && echo '  Folyamat: ${NAME}' && echo '  Indítás: $(date)' && echo '  Parancs: ${CMD}' && echo '═══════════════════════════════════════' && echo '' && ${CMD} 2>&1 | tee -a ${LOG_FILE}; echo ''; echo '═══════════════════════════════════════'; echo '  Folyamat LEÁLLT: $(date)'; echo '  Újraindítás: bg-restart ${NAME}'; echo '═══════════════════════════════════════'; sleep 999999"

if tmux has-session -t "bg-${NAME}" 2>/dev/null; then
    echo ""
    echo -e "\033[1;32m✅ '${NAME}' elindítva háttérben!\033[0m"
    echo ""
    echo "  Parancs:     ${CMD}"
    echo "  Log:         ${LOG_FILE}"
    echo ""
    echo "  Parancsok:"
    echo "    bg-logs ${NAME}        → Log megtekintés"
    echo "    bg-attach ${NAME}      → Csatlakozás (Ctrl+B, D = kilépés)"
    echo "    bg-stop ${NAME}        → Leállítás"
    echo "    bg-restart ${NAME}     → Újraindítás"
    echo "    bg-list                → Összes háttérfolyamat"
    echo ""
else
    echo -e "\033[1;31m✗ Hiba: '${NAME}' nem indult el!\033[0m"
    exit 1
fi
BGSTART
chmod +x /usr/local/bin/bg-start

# ── bg-stop ──
cat > /usr/local/bin/bg-stop << 'BGSTOP'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: bg-stop <név>"
    echo "Futó folyamatok: bg-list"
    exit 1
fi

NAME="$1"

if tmux has-session -t "bg-${NAME}" 2>/dev/null; then
    tmux kill-session -t "bg-${NAME}" 2>/dev/null
    echo -e "\033[1;32m✅ '${NAME}' leállítva.\033[0m"
else
    echo -e "\033[1;33m⚠ '${NAME}' nem fut.\033[0m"
fi
BGSTOP
chmod +x /usr/local/bin/bg-stop

# ── bg-list ──
cat > /usr/local/bin/bg-list << 'BGLIST'
#!/bin/bash
echo ""
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo -e "\033[1;36m  Háttérfolyamatok (Persistent)\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════\033[0m"
echo ""

SESSIONS=$(tmux list-sessions 2>/dev/null | grep "^bg-" || true)

if [ -z "$SESSIONS" ]; then
    echo -e "  \033[1;90mNincs futó háttérfolyamat.\033[0m"
    echo ""
    echo "  Indítás: bg-start <név> <parancs>"
    echo ""
    echo "  Példák:"
    echo "    bg-start mybot 'python3 bot.py'"
    echo "    bg-start web 'node server.js'"
    echo ""
else
    echo "$SESSIONS" | while read -r line; do
        SESS_NAME=$(echo "$line" | cut -d: -f1 | sed 's/^bg-//')
        CREATED=$(echo "$line" | grep -oP '\(created .*?\)' || echo "")
        CMD_FILE="/root/.bg-processes/${SESS_NAME}.cmd"
        CMD_TEXT=""
        if [ -f "$CMD_FILE" ]; then
            CMD_TEXT=$(cat "$CMD_FILE")
        fi
        echo -e "  \033[1;32m●\033[0m \033[1;37m${SESS_NAME}\033[0m"
        if [ -n "$CMD_TEXT" ]; then
            echo -e "    Parancs:  \033[1;33m${CMD_TEXT}\033[0m"
        fi
        if [ -n "$CREATED" ]; then
            echo -e "    \033[1;90m${CREATED}\033[0m"
        fi
        echo ""
    done
    echo "  Parancsok:"
    echo "    bg-logs <név>       → Log"
    echo "    bg-attach <név>     → Csatlakozás (Ctrl+B, D = kilépés)"
    echo "    bg-stop <név>       → Leállítás"
    echo "    bg-restart <név>    → Újraindítás"
fi
echo ""
BGLIST
chmod +x /usr/local/bin/bg-list

# ── bg-logs ──
cat > /usr/local/bin/bg-logs << 'BGLOGS'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: bg-logs <név> [sorok]"
    echo "  bg-logs mybot          → utolsó 50 sor"
    echo "  bg-logs mybot 200      → utolsó 200 sor"
    echo "  bg-logs mybot -f       → élő követés (Ctrl+C = kilépés)"
    exit 1
fi

NAME="$1"
LINES="${2:-50}"
LOG_FILE="/root/.bg-processes/${NAME}.log"

if [ ! -f "$LOG_FILE" ]; then
    echo -e "\033[1;33m⚠ Nincs log '${NAME}' számára.\033[0m"
    echo "  Futó folyamatok: bg-list"
    exit 1
fi

if [ "$LINES" = "-f" ]; then
    echo -e "\033[1;36m══ ${NAME} — ÉLŐ LOG (Ctrl+C = kilépés) ══\033[0m"
    tail -f "$LOG_FILE"
else
    echo -e "\033[1;36m══ ${NAME} — utolsó ${LINES} sor ══\033[0m"
    tail -n "$LINES" "$LOG_FILE"
    echo -e "\033[1;36m══════════════════════════════════════\033[0m"
    echo "  Élő követés: bg-logs ${NAME} -f"
fi
BGLOGS
chmod +x /usr/local/bin/bg-logs

# ── bg-attach ──
cat > /usr/local/bin/bg-attach << 'BGATTACH'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: bg-attach <név>"
    echo "  Kilépés a folyamatból (DE tovább fut): Ctrl+B, majd D"
    echo ""
    echo "Futó folyamatok: bg-list"
    exit 1
fi

NAME="$1"

if tmux has-session -t "bg-${NAME}" 2>/dev/null; then
    echo -e "\033[1;36m  Csatlakozás '${NAME}' folyamathoz...\033[0m"
    echo -e "\033[1;33m  Kilépés (DE tovább fut!): Ctrl+B, majd D\033[0m"
    echo ""
    sleep 1
    tmux attach-session -t "bg-${NAME}"
else
    echo -e "\033[1;33m⚠ '${NAME}' nem fut.\033[0m"
    echo "  Futó folyamatok: bg-list"
fi
BGATTACH
chmod +x /usr/local/bin/bg-attach

# ── bg-restart ──
cat > /usr/local/bin/bg-restart << 'BGRESTART'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: bg-restart <név>"
    exit 1
fi

NAME="$1"
CMD_FILE="/root/.bg-processes/${NAME}.cmd"

if [ ! -f "$CMD_FILE" ]; then
    echo -e "\033[1;31m✗ Nem található mentett parancs '${NAME}' számára.\033[0m"
    echo "  Indítsd újra: bg-start ${NAME} '<parancs>'"
    exit 1
fi

CMD=$(cat "$CMD_FILE")

echo "Leállítás..."
bg-stop "$NAME" 2>/dev/null

sleep 2

echo "Újraindítás..."
bg-start "$NAME" $CMD
BGRESTART
chmod +x /usr/local/bin/bg-restart

# ── bg-stopall ──
cat > /usr/local/bin/bg-stopall << 'BGSTOPALL'
#!/bin/bash
echo ""
echo -e "\033[1;33m⚠ Minden háttérfolyamat leállítása...\033[0m"
echo ""

SESSIONS=$(tmux list-sessions 2>/dev/null | grep "^bg-" | cut -d: -f1 || true)

if [ -z "$SESSIONS" ]; then
    echo "  Nincs futó háttérfolyamat."
else
    echo "$SESSIONS" | while read -r sess; do
        NAME=$(echo "$sess" | sed 's/^bg-//')
        tmux kill-session -t "$sess" 2>/dev/null
        echo -e "  \033[1;31m●\033[0m ${NAME} leállítva"
    done
    echo ""
    echo -e "\033[1;32m✅ Minden leállítva.\033[0m"
fi
echo ""
BGSTOPALL
chmod +x /usr/local/bin/bg-stopall

echo -e "  ${G}✓${N} Persistent Process Kezelő telepítve"
echo -e "  ${D}  bg-start, bg-stop, bg-list, bg-logs, bg-attach, bg-restart, bg-stopall${N}"

# ══════════════════════════════════════
# 6. SEGÉDPARANCSOK ÉS BASHRC (SFTP JAVÍTÁSSAL)
# ══════════════════════════════════════
echo -e "${C}[6/6]${W} Segédparancsok...${N}"

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
BG_COUNT=$(tmux list-sessions 2>/dev/null | grep -c "^bg-" || echo "0")
echo "  Háttérfolyamatok: ${BG_COUNT} db"
if [ "$BG_COUNT" -gt 0 ]; then
    tmux list-sessions 2>/dev/null | grep "^bg-" | while read -r line; do
        SESS=$(echo "$line" | cut -d: -f1 | sed 's/^bg-//')
        echo "    ● ${SESS}"
    done
fi
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

cat > /root/.bashrc << 'BEOF'
# >>> SFTP JAVÍTÁS KEZDETE <<<
# Ha a kapcsolat nem interaktív (pl. SFTP program csatlakozik), azonnal kilép a scriptből,
# így nem dobja fel a színes menüt, és nem zavarja meg a FileZillát.
case $- in
    *i*) ;;
      *) return;;
esac
# >>> SFTP JAVÍTÁS VÉGE <<<

export PS1='\[\033[01;32m\]\u@szaby\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM=xterm-256color
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cls='clear'
alias info='vps-info'

if [ -z "$VPS_GREETED" ]; then
    export VPS_GREETED=1
    echo ""
    echo -e "\033[1;36m  ═════════════════════════════════════════\033[0m"
    echo -e "\033[1;36m   Szaby VPS — ROOT\033[0m"
    echo -e "\033[1;36m  ═════════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;37m  Alap parancsok:\033[0m"
    echo -e "\033[1;33m    vps-info\033[0m              → Rendszer infó"
    echo -e "\033[1;33m    vps-tunnel-restart\033[0m    → Tunnel újra"
    echo ""
    echo -e "\033[1;37m  Háttérfolyamatok (SSH kilépés után is futnak!):\033[0m"
    echo -e "\033[1;33m    bg-start <név> <cmd>\033[0m  → Indítás"
    echo -e "\033[1;33m    bg-stop <név>\033[0m         → Leállítás"
    echo -e "\033[1;33m    bg-list\033[0m               → Lista"
    echo -e "\033[1;33m    bg-logs <név>\033[0m         → Log"
    echo -e "\033[1;33m    bg-attach <név>\033[0m       → Csatlakozás"
    echo -e "\033[1;33m    bg-restart <név>\033[0m      → Újraindítás"
    echo -e "\033[1;33m    bg-stopall\033[0m            → Minden leáll"
    echo ""
fi
BEOF
echo -e "  ${G}✓${N} Parancsok kész"

# ══════════════════════════════════════
# DASHBOARD HTML
# ══════════════════════════════════════
cat > /var/www/html/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Szaby Ubuntu VPS</title>
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
<div class="sub">Render.com Ubuntu VPS — Modified by szaby</div>

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
        <a href="/terminal/" class="btn" target="_blank">🖥️ Terminál megnyitása</a>
        <p class="info">Teljes root Linux shell — nem kell semmi telepíteni!</p>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>📂 Webes Fájlkezelő</h2>
        <a href="/files/" class="btn" target="_blank" style="background:#1f6feb">📂 Fájlkezelő megnyitása</a>
        <p class="info">Drag & drop fájlfeltöltés — böngészőből!</p>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>🖥️ Beágyazott Terminál</h2>
        <div style="background:#000;border-radius:8px;overflow:hidden;height:500px">
            <iframe src="/terminal/" style="width:100%;height:100%;border:none"></iframe>
        </div>
    </div>
</div>

<div class="row">
    <div class="card full">
        <h2>📚 Parancsok</h2>
        <pre>═══ ALAP ═══
vps-info              # Rendszer infó + SSH adatok
vps-tunnel-restart    # Tunnel újraindítás

═══ HÁTTÉRFOLYAMATOK (SSH kilépés után is futnak!) ═══
bg-start mybot 'python3 bot.py'    # Indítás háttérben
bg-start web 'node server.js'     # Másik folyamat
bg-list                            # Futó folyamatok listája
bg-logs mybot                      # Log megtekintés
bg-logs mybot -f                   # Élő log követés
bg-attach mybot                    # Csatlakozás (Ctrl+B, D = kilép)
bg-stop mybot                      # Leállítás
bg-restart mybot                   # Újraindítás
bg-stopall                         # Minden leáll

═══ RENDSZER ═══
htop                  # Folyamatok
ll                    # Fájlok listázása
free -h               # Memória
df -h                 # Lemezterület</pre>
    </div>
</div>
</div>

<script>
function load(){
    fetch('/sftp.txt').then(r=>r.text()).then(t=>{
        if(t.includes('AKTIV')){
            document.getElementById('status').innerHTML='<span class="active">✅ Szerver aktív — SSH, SFTP és háttérfolyamatok működnek!</span>';
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
echo -e "  ${C}Háttérfolyamatok:${N}"
echo -e "    ${G}bg-start mybot 'python3 bot.py'${N} → Indít"
echo -e "    ${G}bg-list${N}                          → Lista"
echo -e "    ${G}bg-attach mybot${N}                  → Csatlakozás"
echo ""
echo -e "${C}════════════════════════════════════════════════════════${N}"
echo ""

# ══════════════════════════════════════
# SUPERVISOR INDÍTÁS
# ══════════════════════════════════════
echo -e "${C}Supervisor indítása...${N}"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
