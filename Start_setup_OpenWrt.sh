#!/bin/sh
# ============================================================
#  Start_setup_OpenWrt 2.0
#  Установщик пакетов и утилит для OpenWrt
#  https://github.com/moseszz007/Start_setup_OpenWrt
#
#  Использование:
#    sh Start_setup_OpenWrt.sh          # интерактивное меню
#    sh Start_setup_OpenWrt.sh 1 4 9    # сразу выбранные пункты
#    sh Start_setup_OpenWrt.sh 2-5      # диапазон пунктов
#    sh Start_setup_OpenWrt.sh --all    # установить всё
# ============================================================

APP_VER="2.0"

# ---------- Цвета (только в терминале) ----------
if [ -t 1 ]; then
    C_RED='\033[0;31m'
    C_GRN='\033[0;32m'
    C_YEL='\033[1;33m'
    C_BLU='\033[0;34m'
    C_CYN='\033[0;36m'
    C_DIM='\033[2m'
    C_BLD='\033[1m'
    C_RST='\033[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_CYN=''; C_DIM=''; C_BLD=''; C_RST=''
fi

# ---------- Единый вывод ----------
info() { printf '%b  ... %s%b\n' "$C_CYN" "$1" "$C_RST"; }
ok()   { printf '%b  [ok] %s%b\n' "$C_GRN" "$1" "$C_RST"; }
warn() { printf '%b  [!]  %s%b\n' "$C_YEL" "$1" "$C_RST"; }
err()  { printf '%b  [x]  %s%b\n' "$C_RED" "$1" "$C_RST"; }
step() { printf '\n%b>>> %s%b\n' "$C_BLD$C_BLU" "$1" "$C_RST"; }
line() { printf '%b%s%b\n' "$C_DIM" "------------------------------------------------------------" "$C_RST"; }

# ---------- Итоги ----------
SUM_OK=0
SUM_FAIL=0
SUM_LINES=""

add_result() {
    if [ "$1" = "ok" ]; then
        SUM_OK=$((SUM_OK + 1))
        SUM_LINES="${SUM_LINES}\n ${C_GRN}[ok]${C_RST}  $2"
    else
        SUM_FAIL=$((SUM_FAIL + 1))
        SUM_LINES="${SUM_LINES}\n ${C_RED}[x]${C_RST}   $2"
    fi
}

# ---------- Пакетный менеджер ----------
if command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"; UPDATE_CMD="apk update"; INSTALL_CMD="apk add"; ALLOW_UNTRUSTED="--allow-untrusted"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"; UPDATE_CMD="opkg update"; INSTALL_CMD="opkg install"; ALLOW_UNTRUSTED=""
else
    printf '%bОшибка: ни opkg, ни apk не найдены%b\n' "$C_RED" "$C_RST"
    exit 1
fi

# ---------- Прошивка ----------
RELEASE="unknown"; ARCH="unknown"
if [ -f /etc/openwrt_release ]; then
    . /etc/openwrt_release
    [ -n "$DISTRIB_RELEASE" ] && RELEASE="$DISTRIB_RELEASE"
    [ -n "$DISTRIB_ARCH" ] && ARCH="$DISTRIB_ARCH"
fi

# ---------- Базовые пакеты ----------
PACKAGES="
nano|Текстовый редактор nano
unzip|Распаковка ZIP-архивов
ttyd|Веб-терминал
luci-app-ttyd|LuCI-приложение для ttyd
luci-i18n-ttyd-ru|Русский язык для ttyd
luci-app-filemanager|Файловый менеджер в LuCI
luci-i18n-filemanager-ru|Русский язык для файлового менеджера
luci-i18n-base-ru|Русский язык для LuCI
"

# ---------- Компоненты: key|описание|пакет для статуса ----------
FEATURES="
dnsproxy|DNS Proxy: мой UI + готовый конфиг|luci-app-dnsproxy
dnsproxy-config|Только применить готовый конфиг|
zapret|Zapret Manager: обход блокировок|
internet-detector|Детектор интернета + русификатор|luci-app-internet-detector
luci-theme-koka|Моя тема: скин и дашборд|luci-theme-koka
zerotier|VPN-доступ к роутеру|zerotier
fix-apk|Фикс установки локальных пакетов в LuCI|
ipv6-off|Полное отключение IPv6|
"

BASE_COUNT=$(printf '%s\n' "$PACKAGES" | grep -c '|')
FEAT_COUNT=$(printf '%s\n' "$FEATURES" | grep -c '|')
FEAT_START=$((BASE_COUNT + 1))
MAX_NUM=$((BASE_COUNT + FEAT_COUNT))

# ---------- Мои репозитории ----------
GH_USER="moseszz007"
DNSPROXY_REPO="$GH_USER/luci-app-dnsproxy"
DNSPROXY_PKG="luci-app-dnsproxy"
DNSPROXY_FALLBACK="2026.11.28-r1"
KOKA_REPO="$GH_USER/luci-theme-koka"
KOKA_PKG="luci-theme-koka"
KOKA_FALLBACK="2026.11.28-r22"

# Прямая ссылка на конкретный релиз — без GitHub API, без поиска "последнего"
release_url() {   # <repo> <pkg> <версия> <apk|ipk>
    if [ "$4" = "apk" ]; then
        printf 'https://github.com/%s/releases/download/v%s/%s-%s.apk' "$1" "$3" "$2" "$3"
    else
        printf 'https://github.com/%s/releases/download/v%s/%s_%s_all.ipk' "$1" "$3" "$2" "$3"
    fi
}

# ---------- Загрузчик ----------
DOWNLOADER=""
detect_downloader() {
    if command -v curl >/dev/null 2>&1; then DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then DOWNLOADER="wget"
    elif command -v uclient-fetch >/dev/null 2>&1; then DOWNLOADER="uclient-fetch"
    else DOWNLOADER=""
    fi
}

ensure_downloader() {
    detect_downloader
    [ -n "$DOWNLOADER" ] && return 0
    info "Ставлю инструмент загрузки"
    $INSTALL_CMD ca-bundle >/dev/null 2>&1
    $INSTALL_CMD libustream-mbedtls >/dev/null 2>&1
    $INSTALL_CMD curl >/dev/null 2>&1 || $INSTALL_CMD wget-ssl >/dev/null 2>&1
    detect_downloader
    [ -n "$DOWNLOADER" ]
}

# Жёсткий лимит времени: если загрузчик завис, процесс убивается сам
run_limited() {   # <секунды> <команда...>
    _lim="$1"; shift
    "$@" < /dev/null &
    _pid=$!
    _n=0
    while kill -0 "$_pid" 2>/dev/null; do
        if [ "$_n" -ge "$_lim" ]; then
            kill -9 "$_pid" 2>/dev/null
            wait "$_pid" 2>/dev/null
            return 124
        fi
        sleep 1
        _n=$((_n + 1))
    done
    wait "$_pid" 2>/dev/null
}

# Пробует все загрузчики по очереди: на части прошивок uclient-fetch
# не умеет редиректы github.com, поэтому одного выбранного мало.
http_get() {
    _f="/tmp/setup-http.$$"
    _p="$_f.part"
    rm -f "$_f" "$_p"
    if command -v curl >/dev/null 2>&1; then
        run_limited 30 curl -fsSL --connect-timeout 8 --max-time 25 \
            -A "Start_setup_OpenWrt" -o "$_p" "$1" 2>/dev/null
        [ -s "$_p" ] && mv -f "$_p" "$_f"
    fi
    if [ ! -s "$_f" ] && command -v wget >/dev/null 2>&1; then
        run_limited 30 wget -q -T 25 -t 1 --header="User-Agent: Start_setup_OpenWrt" -O "$_p" "$1" 2>/dev/null
        [ -s "$_p" ] && mv -f "$_p" "$_f"
    fi
    if [ ! -s "$_f" ] && command -v uclient-fetch >/dev/null 2>&1; then
        run_limited 30 uclient-fetch -q -T 25 --header="User-Agent: Start_setup_OpenWrt" -O "$_p" "$1" 2>/dev/null
        [ -s "$_p" ] && mv -f "$_p" "$_f"
    fi
    if [ -s "$_f" ]; then
        cat "$_f"
        rm -f "$_f" "$_p"
        return 0
    fi
    rm -f "$_f" "$_p"
    return 1
}

fetch_file() {
    rm -f "$2"
    if command -v curl >/dev/null 2>&1; then
        run_limited 90 curl -fsSL --connect-timeout 10 --max-time 60 -o "$2" "$1" 2>/dev/null
        [ -s "$2" ] && { DOWNLOADER="curl"; return 0; }
    fi
    if command -v wget >/dev/null 2>&1; then
        run_limited 90 wget -q -T 60 -t 1 -O "$2" "$1" 2>/dev/null
        [ -s "$2" ] && { DOWNLOADER="wget"; return 0; }
    fi
    if command -v uclient-fetch >/dev/null 2>&1; then
        run_limited 90 uclient-fetch -q -T 60 -O "$2" "$1" 2>/dev/null
        [ -s "$2" ] && { DOWNLOADER="uclient-fetch"; return 0; }
    fi
    if [ "$DOWNLOADER" != "curl" ]; then
        info "Ставлю curl для загрузки"
        $INSTALL_CMD curl >>/tmp/setup-install.log 2>&1 && \
            run_limited 90 curl -fsSL --connect-timeout 10 --max-time 60 -o "$2" "$1" 2>/dev/null && \
            [ -s "$2" ] && { DOWNLOADER="curl"; return 0; }
    fi
    rm -f "$2"
    return 1
}

# github_asset <repo> <префикс имени> <ext> — ссылка на файл из последнего релиза
github_asset() {
    _json=$(http_get "https://api.github.com/repos/$1/releases/latest")
    [ -z "$_json" ] && return 1
    printf '%s' "$_json" | tr ',' '\n' | grep 'browser_download_url' \
        | grep -F "$2" | grep -F ".$3" | head -n 1 | cut -d'"' -f4
}

# ---------- Статус установленных пакетов ----------
INSTALLED=""
load_installed() {
    if [ "$PKG_MGR" = "apk" ]; then
        INSTALLED=$(apk info 2>/dev/null)
    else
        INSTALLED=$(opkg list-installed 2>/dev/null | awk '{print $1}')
    fi
}

is_installed() {
    [ -n "$INSTALLED" ] || return 1
    printf '%s\n' "$INSTALLED" | grep -qx "$1"
}

# ---------- Установка одного пакета ----------
install_pkg() {
    if is_installed "$1"; then
        ok "$1 уже установлен"
        add_result ok "$1"
        return 0
    fi
    info "Ставлю $1"
    if $INSTALL_CMD "$1" >/tmp/setup-install.log 2>&1; then
        ok "$1 установлен"
        add_result ok "$1"
    else
        err "Не удалось установить $1"
        tail -n 3 /tmp/setup-install.log 2>/dev/null | sed 's/^/       /'
        add_result fail "$1"
    fi
}

# ---------- Установка пакета с GitHub Releases ----------
install_github_pkg() {
    _repo="$1"; _pkg="$2"; _fb="$3"

    ensure_downloader || { err "Нет wget/curl"; add_result fail "$_pkg"; return 1; }

    if [ "$PKG_MGR" = "apk" ]; then _ext="apk"; else _ext="ipk"; fi
    _file="/tmp/$_pkg.$_ext"

    # 1) сразу качаем закреплённый релиз по прямой ссылке — API не нужен
    _url=$(release_url "$_repo" "$_pkg" "$_fb" "$_ext")
    info "Скачиваю $_pkg $_fb"
    if ! fetch_file "$_url" "$_file"; then
        # 2) не вышло — только тогда спрашиваем API (с жёстким лимитом времени)
        info "Прямая ссылка не открылась — ищу последний релиз $_pkg"
        _url=$(github_asset "$_repo" "$_pkg" "$_ext")
        [ -z "$_url" ] && _url=$(release_url "$_repo" "$_pkg" "$_fb" "$_ext")
        info "Скачиваю $(basename "$_url")"
        if ! fetch_file "$_url" "$_file"; then
            err "Ошибка скачивания $_pkg"
            rm -f "$_file"
            add_result fail "$_pkg"
            return 1
        fi
    fi

    # для apk нужен ключ подписи пакета
    if [ "$_ext" = "apk" ] && [ ! -s "/etc/apk/keys/$_pkg.rsa.pub" ]; then
        _key="https://github.com/$_repo/releases/download/v$_fb/$_pkg.rsa.pub"
        mkdir -p /etc/apk/keys
        fetch_file "$_key" "/etc/apk/keys/$_pkg.rsa.pub" >/dev/null 2>&1 || \
            warn "Ключ подписи не скачан"
    fi

    _done=0
    if [ "$PKG_MGR" = "apk" ]; then
        apk add $ALLOW_UNTRUSTED "$_file" >/tmp/setup-install.log 2>&1 && _done=1
    else
        opkg install "$_file" >/tmp/setup-install.log 2>&1 && _done=1
        if [ "$_done" = "0" ]; then
            opkg install --force-depends "$_file" >/tmp/setup-install.log 2>&1 && _done=1
        fi
    fi
    rm -f "$_file"

    if [ "$_done" = "1" ]; then
        ok "$_pkg установлен"
        add_result ok "$_pkg"
        return 0
    fi
    err "Не удалось установить $_pkg"
    tail -n 3 /tmp/setup-install.log 2>/dev/null | sed 's/^/       /'
    add_result fail "$_pkg"
    return 1
}

# ---------- Конфиг dnsproxy ----------
apply_dnsproxy_config() {
    info "Применяю конфигурацию dnsproxy"
    cat > /etc/config/dnsproxy << 'EOF'
config dnsproxy 'global'
	option ipv6_disabled '1'
	list listen_addr '127.0.0.1'
	list listen_port '5353'
	option refuse_any '1'
	option upstream_mode 'parallel'
	option enabled '1'

config dnsproxy 'bogus_nxdomain'

config dnsproxy 'cache'
	option cache_optimistic '1'
	option size '65536'
	option enabled '1'
	option min_ttl '60'
	option max_ttl '43200'

config dnsproxy 'dns64'
	option dns64_prefix '64:ff9b::'

config dnsproxy 'edns'

config dnsproxy 'hosts'
	option enabled '0'
	list hosts_files ''

config dnsproxy 'private_rdns'
	option enabled '0'
	list upstream '127.0.0.1:53'

config dnsproxy 'servers'
	list bootstrap '1.1.1.1'
	list bootstrap '9.9.9.9'
	list upstream '[/ru/xn--p1ai/]77.88.8.1'
	list upstream '[/openwrt.org/]1.1.1.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.8'
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.malw.link/dns-query'
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.magicdns.ru/dns-query'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'tls://9.9.9.9'
	list upstream 'https://ee-tll.doh.sb/dns-query'
	list upstream 'https://de-fra.doh.sb/dns-query'
	list upstream 'https://de-dus.doh.sb/dns-query	'
	list upstream 'https://nl-ams.doh.sb/dns-query'
	list fallback '77.88.8.8'
	list fallback '77.88.8.1'

config dnsproxy 'tls'
	option enabled '0'
	option https_port '8443'
	option tls_port '853'
	option quic_port '853'

config profile
	option label 'KOKA'
	option upstream_mode 'parallel'
	list bootstrap '1.1.1.1'
	list bootstrap '9.9.9.9'
	list fallback '77.88.8.8'
	list fallback '77.88.8.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.1'
	list upstream '[/openwrt.org/]1.1.1.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.8'
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.malw.link/dns-query'
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.magicdns.ru/dns-query'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'tls://9.9.9.9'
	list upstream 'https://ee-tll.doh.sb/dns-query'
	list upstream 'https://de-fra.doh.sb/dns-query'
	list upstream 'https://de-dus.doh.sb/dns-query	'
	list upstream 'https://nl-ams.doh.sb/dns-query'
EOF
    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci -q delete dhcp.@dnsmasq[0].server
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
    uci commit dhcp

    if [ -x /etc/init.d/dnsproxy ]; then
        /etc/init.d/dnsproxy enable 2>/dev/null
        /etc/init.d/dnsproxy restart 2>/dev/null
    fi
    if [ -x /etc/init.d/dnsmasq ]; then
        /etc/init.d/dnsmasq restart 2>/dev/null
    fi

    ok "Конфиг dnsproxy применён (127.0.0.1:5353)"
    add_result ok "Конфиг dnsproxy"
}

install_dnsproxy() {
    step "DNS Proxy"
    install_pkg dnsproxy
    install_github_pkg "$DNSPROXY_REPO" "$DNSPROXY_PKG" "$DNSPROXY_FALLBACK"
    /etc/init.d/rpcd restart 2>/dev/null
    rm -rf /tmp/luci-indexcache* 2>/dev/null
    apply_dnsproxy_config
}

install_zapret() {
    step "Zapret Manager"
    ensure_downloader || { err "Нет wget/curl"; add_result fail "Zapret Manager"; return 1; }
    _tmp=/tmp/zapret-install.sh
    info "Скачиваю установщик"
    if fetch_file "https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/ZapretManager_LuCI.sh" "$_tmp" \
        && sh "$_tmp"; then
        ok "Zapret Manager установлен"
        add_result ok "Zapret Manager"
    else
        err "Ошибка установки Zapret Manager"
        add_result fail "Zapret Manager"
    fi
    rm -f "$_tmp"
}

# Выбрать имя файла из JSON-листинга GitHub: <json> <вхождение> [исключить]
_pick_asset() {
    if [ -n "$3" ]; then
        printf '%s' "$1" | tr ',' '\n' | grep '"name"' | grep -F "$2" \
            | grep -v -F "$3" | head -n 1 | cut -d'"' -f4
    else
        printf '%s' "$1" | tr ',' '\n' | grep '"name"' | grep -F "$2" \
            | head -n 1 | cut -d'"' -f4
    fi
}

install_internet_detector() {
    step "Internet Detector"
    ensure_downloader || { err "Нет wget/curl"; add_result fail "Internet Detector"; return 1; }

    if [ "$PKG_MGR" = "apk" ]; then
        _branch="25.12"; _ext="apk"
    else
        _branch="24.10"; _ext="ipk"
    fi

    info "Смотрю последние сборки ($_branch)"
    _list=$(http_get "https://api.github.com/repos/gSpotx2f/packages-openwrt/contents/$_branch")
    _core=$(_pick_asset "$_list" "internet-detector" "luci-")
    _luci=$(_pick_asset "$_list" "luci-app-internet-detector")
    _ru=$(_pick_asset "$_list" "luci-i18n-internet-detector-ru")

    if [ -z "$_core" ]; then
        warn "Не нашёл файлы в API — беру версию 1.7.4-r2"
        if [ "$_ext" = "apk" ]; then
            _core="internet-detector-1.7.4-r2.apk"
            _luci="luci-app-internet-detector-1.7.4-r2.apk"
            _ru="luci-i18n-internet-detector-ru-1.7.4-r2.apk"
        else
            _core="internet-detector_1.7.4-r2_all.ipk"
            _luci="luci-app-internet-detector_1.7.4-r2_all.ipk"
            _ru="luci-i18n-internet-detector-ru_1.7.4-r2_all.ipk"
        fi
    fi

    _base="https://github.com/gSpotx2f/packages-openwrt/raw/master/$_branch"
    _fail=0
    for _f in "$_core" "$_luci" "$_ru"; do
        [ -z "$_f" ] && continue
        info "Ставлю $_f"
        if fetch_file "$_base/$_f" "/tmp/$_f" \
            && $INSTALL_CMD $ALLOW_UNTRUSTED "/tmp/$_f" >/tmp/setup-install.log 2>&1; then
            ok "$_f установлен"
        else
            err "Ошибка: $_f"
            _fail=1
        fi
        rm -f "/tmp/$_f"
    done

    if [ -x /etc/init.d/internet-detector ]; then
        /etc/init.d/internet-detector enable 2>/dev/null
        /etc/init.d/internet-detector restart 2>/dev/null
    fi
    /etc/init.d/rpcd restart 2>/dev/null

    if [ "$_fail" = "0" ]; then
        ok "Internet Detector установлен"
        add_result ok "Internet Detector"
    else
        add_result fail "Internet Detector"
    fi
}

install_koka_theme() {
    step "Тема Koka Modern"
    install_github_pkg "$KOKA_REPO" "$KOKA_PKG" "$KOKA_FALLBACK" || return 1

    # Пакет сам регистрирует и включает тему; подстрахуемся, если LuCI не обновился
    if uci -q get luci.main >/dev/null 2>&1; then
        uci -q get luci.themes.Koka >/dev/null 2>&1 || \
            uci set luci.themes.Koka='/luci-static/koka'
        uci set luci.main.mediaurlbase='/luci-static/koka'
        uci commit luci
    fi
    /etc/init.d/rpcd restart 2>/dev/null
    rm -rf /tmp/luci-indexcache* 2>/dev/null

    ok "Тема Koka установлена и включена — обнови страницу LuCI (F5)"
}

ask_zerotier_id() {
    [ -n "$ZEROTIER_NET_ID" ] && return 0
    echo ""
    printf '%bВведите Network ID ZeroTier (Enter — пропустить):%b ' "$C_CYN" "$C_RST"
    read -r ZEROTIER_NET_ID
}

install_zerotier() {
    step "ZeroTier"

    if ! $INSTALL_CMD $ALLOW_UNTRUSTED zerotier luci-app-zerotier luci-i18n-zerotier-ru >/dev/null 2>&1; then
        $INSTALL_CMD $ALLOW_UNTRUSTED zerotier luci-app-zerotier >/dev/null 2>&1 || \
        $INSTALL_CMD $ALLOW_UNTRUSTED zerotier >/dev/null 2>&1 || true
    fi

    load_installed
    if ! is_installed zerotier; then
        err "ZeroTier не установлен"
        add_result fail "ZeroTier"
        return 1
    fi
    ok "Пакеты ZeroTier установлены"

    ask_zerotier_id
    if [ -n "$ZEROTIER_NET_ID" ]; then
        info "Настраиваю сеть $ZEROTIER_NET_ID"
        uci set zerotier.openwrt_network=zerotier
        uci set zerotier.openwrt_network.enabled='1'
        uci -q delete zerotier.openwrt_network.join
        uci add_list zerotier.openwrt_network.join="$ZEROTIER_NET_ID"
        uci commit zerotier
    else
        warn "Network ID не введён — подключение к сети пропущено"
    fi

    if [ -x /etc/init.d/zerotier ]; then
        /etc/init.d/zerotier enable 2>/dev/null
        /etc/init.d/zerotier restart 2>/dev/null
    fi

    info "Жду появления интерфейса (3 сек)"
    sleep 3

    # ищем реальный интерфейс ztXXXXX
    ZT_IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^zt/ {print $2}' | head -n 1)

    if [ -n "$ZT_IFACE" ]; then
        info "Нашёл интерфейс $ZT_IFACE — привязываю к сети"
        uci set network.zerotier=interface
        uci set network.zerotier.proto='none'
        uci set network.zerotier.device="$ZT_IFACE"

        if ! uci show firewall 2>/dev/null | grep -q "name='zerotier'"; then
            uci add firewall zone >/dev/null
            uci set firewall.@zone[-1].name='zerotier'
            uci set firewall.@zone[-1].input='ACCEPT'
            uci set firewall.@zone[-1].output='ACCEPT'
            uci set firewall.@zone[-1].forward='ACCEPT'
            uci set firewall.@zone[-1].masq='1'
            uci add_list firewall.@zone[-1].network='zerotier'
            uci commit firewall
        fi

        uci commit network
        /etc/init.d/network restart >/dev/null 2>&1
        /etc/init.d/firewall restart >/dev/null 2>&1
        ok "ZeroTier привязан к интерфейсу $ZT_IFACE"
    else
        warn "Интерфейс zt* не появился — проверь интернет и перезагрузи роутер"
    fi

    info "Не забудь авторизовать роутер: https://my.zerotier.com"
    add_result ok "ZeroTier"
}

fix_apk_luci() {
    step "Фикс APK в LuCI"
    if [ -f /usr/libexec/package-manager-call ]; then
        sed -i 's/action="add"/action="add --allow-untrusted"/g' /usr/libexec/package-manager-call
        ok "Фикс применён — локальные пакеты ставятся из LuCI"
        add_result ok "Фикс APK в LuCI"
    else
        warn "Файл не найден — похоже, это не OpenWrt 25.12"
        add_result fail "Фикс APK в LuCI"
    fi
}

disable_ipv6() {
    step "Отключение IPv6"
    uci set network.lan.ipv6='0'
    uci set network.wan.ipv6='0'
    uci set network.lan.delegate='0'
    uci -q delete dhcp.lan.dhcpv6
    uci -q delete dhcp.lan.ra
    uci -q delete dhcp.lan.ra_slaac
    uci -q delete network.globals.ula_prefix
    uci set dhcp.@dnsmasq[0].filter_aaaa='1'
    uci commit

    if [ -x /etc/init.d/odhcpd ]; then
        /etc/init.d/odhcpd disable 2>/dev/null
        /etc/init.d/odhcpd stop 2>/dev/null
    fi
    /etc/init.d/network restart >/dev/null 2>&1
    /etc/init.d/dnsmasq restart >/dev/null 2>&1

    ok "IPv6 отключён"
    add_result ok "Отключение IPv6"
}

# ---------- Запуск компонентов ----------
run_feature() {
    case "$1" in
        dnsproxy)           install_dnsproxy ;;
        dnsproxy-config)    apply_dnsproxy_config ;;
        zapret)             install_zapret ;;
        internet-detector)  install_internet_detector ;;
        luci-theme-koka)    install_koka_theme ;;
        zerotier)           install_zerotier ;;
        fix-apk)            fix_apk_luci ;;
        ipv6-off)           disable_ipv6 ;;
        *)                  err "Неизвестный компонент: $1" ;;
    esac
}

install_all() {
    step "Режим «Установить всё»"

    ask_zerotier_id
    step "Обновляю списки пакетов ($PKG_MGR)"
    if $UPDATE_CMD >/tmp/setup-update.log 2>&1; then
        ok "Списки обновлены"
    else
        warn "Не удалось обновить списки — продолжаю"
    fi
    load_installed

    step "Базовые пакеты"
    while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        install_pkg "$pkg"
    done <<EOF
$PACKAGES
EOF

    install_dnsproxy
    install_zapret
    install_internet_detector
    install_koka_theme
    install_zerotier
    fix_apk_luci
    disable_ipv6
}

# ---------- Меню ----------
draw_menu() {
    [ -t 1 ] && clear 2>/dev/null
    printf '%b============================================================%b\n' "$C_BLU" "$C_RST"
    printf '%b  Start_setup_OpenWrt %s%b\n' "$C_BLD" "$APP_VER" "$C_RST"
    printf '%b  OpenWrt %s  |  %s  |  %s%b\n' "$C_DIM" "$RELEASE" "$ARCH" "$PKG_MGR" "$C_RST"
    printf '%b============================================================%b\n' "$C_BLU" "$C_RST"
    printf '%b  [+] уже установлено   [ ] не установлено%b\n\n' "$C_DIM" "$C_RST"

    printf '%b  БАЗОВЫЕ ПАКЕТЫ%b\n' "$C_CYN" "$C_RST"
    _i=1
    while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        if is_installed "$pkg"; then _pc="$C_GRN"; _mark="+"; else _pc="$C_DIM"; _mark=" "; fi
        printf '  %b[%s]%b %2d) %-25s %b%s%b\n' "$_pc" "$_mark" "$C_RST" "$_i" "$pkg" "$C_DIM" "$desc" "$C_RST"
        _i=$((_i + 1))
    done <<EOF
$PACKAGES
EOF

    printf '\n%b  КОМПОНЕНТЫ%b\n' "$C_CYN" "$C_RST"
    _i=$FEAT_START
    while IFS='|' read -r key desc pkg; do
        [ -z "$key" ] && continue
        if [ -n "$pkg" ] && is_installed "$pkg"; then _pc="$C_GRN"; _mark="+"; else _pc="$C_DIM"; _mark=" "; fi
        printf '  %b[%s]%b %2d) %-25s %b%s%b\n' "$_pc" "$_mark" "$C_RST" "$_i" "$key" "$C_DIM" "$desc" "$C_RST"
        _i=$((_i + 1))
    done <<EOF
$FEATURES
EOF

    echo ""
    line
    printf '  %b0%b) Установить всё\n' "$C_GRN" "$C_RST"
    printf '  %bq%b) Выход\n' "$C_RED" "$C_RST"
    line
    printf '%b  Можно выбрать несколько: 1 4 7, диапазон 2-5 или 0 — всё%b\n' "$C_DIM" "$C_RST"
}

usage() {
    cat <<EOF
Start_setup_OpenWrt $APP_VER

  sh $0            интерактивное меню
  sh $0 1 4 9      выбранные пункты
  sh $0 2-5        диапазон пунктов
  sh $0 --all      установить всё
EOF
}

# разворачивает "1 2-4,7" в " 1 2 3 4 7", а 0/all — в ALL
expand_selection() {
    _out=""
    for _tok in $(printf '%s' "$1" | tr ',' ' '); do
        case "$_tok" in
            a|A|all|ALL|0)
                _out="ALL"; break ;;
            *-*)
                _a=${_tok%%-*}; _b=${_tok##*-}
                case "$_a" in ''|*[!0-9]*) err "Пропускаю: $_tok"; continue ;; esac
                case "$_b" in ''|*[!0-9]*) err "Пропускаю: $_tok"; continue ;; esac
                if [ "$_a" -gt "$_b" ]; then _t="$_a"; _a="$_b"; _b="$_t"; fi
                while [ "$_a" -le "$_b" ]; do
                    _out="$_out $_a"
                    _a=$((_a + 1))
                done ;;
            *)
                case "$_tok" in *[!0-9]*) err "Пропускаю: $_tok"; continue ;; esac
                _out="$_out $_tok" ;;
        esac
    done
    printf '%s' "$_out"
}

install_base_by_num() {
    _n=1
    while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        if [ "$_n" -eq "$1" ]; then
            install_pkg "$pkg"
            return 0
        fi
        _n=$((_n + 1))
    done <<EOF
$PACKAGES
EOF
}

feature_key_by_num() {
    _n=$FEAT_START
    while IFS='|' read -r key desc pkg; do
        [ -z "$key" ] && continue
        if [ "$_n" -eq "$1" ]; then
            printf '%s' "$key"
            return 0
        fi
        _n=$((_n + 1))
    done <<EOF
$FEATURES
EOF
}

# ---------- Главный сценарий ----------
choice=""
if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -a|--all) choice="0" ;;
        *) choice="$*" ;;
    esac
else
    load_installed
    draw_menu
    printf '%bВыбор:%b ' "$C_BLD" "$C_RST"
    read -r choice
fi

case "$choice" in
    "") echo "Выход."; exit 0 ;;
    q|Q|quit|exit) echo "Выход."; exit 0 ;;
esac

SELECTION=$(expand_selection "$choice")
if [ -z "$SELECTION" ]; then
    err "Ничего не выбрано"
    exit 1
fi

if [ "$SELECTION" = "ALL" ]; then
    install_all
else
    # обновление списков не нужно, если выбран только готовый конфиг dnsproxy
    need_update=1
    [ "$SELECTION" = " $((FEAT_START + 1))" ] && need_update=0

    if [ "$need_update" = "1" ]; then
        step "Обновляю списки пакетов ($PKG_MGR)"
        if $UPDATE_CMD >/tmp/setup-update.log 2>&1; then
            ok "Списки обновлены"
        else
            warn "Не удалось обновить списки — продолжаю"
        fi
        load_installed
    fi

    for num in $SELECTION; do
        if [ "$num" -ge 1 ] && [ "$num" -le "$BASE_COUNT" ]; then
            install_base_by_num "$num"
        elif [ "$num" -ge "$FEAT_START" ] && [ "$num" -le "$MAX_NUM" ]; then
            run_feature "$(feature_key_by_num "$num")"
        else
            err "Пункта $num нет (доступно 1-$MAX_NUM)"
        fi
    done
fi

# ---------- Итог ----------
echo ""
line
printf '%b  Итог%b\n' "$C_BLD" "$C_RST"
printf '%b\n' "$SUM_LINES"
echo ""
if [ "$SUM_FAIL" -eq 0 ]; then
    printf '%b  Готово: успешно %s, ошибок нет%b\n' "$C_GRN" "$SUM_OK" "$C_RST"
else
    printf '%b  Успешно: %s   С ошибками: %s%b\n' "$C_YEL" "$SUM_OK" "$SUM_FAIL" "$C_RST"
fi
line
