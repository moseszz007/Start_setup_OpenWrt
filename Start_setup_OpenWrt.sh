#!/bin/sh

# ============================================
# Установщик пакетов и утилит для OpenWrt
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Глобальная переменная для Network ID ZeroTier
ZEROTIER_NET_ID=""

# ---------- Определение пакетного менеджера ----------
if command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
    UPDATE_CMD="apk update"
    INSTALL_CMD="apk add"
    ALLOW_UNTRUSTED="--allow-untrusted"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
    UPDATE_CMD="opkg update"
    INSTALL_CMD="opkg install"
    ALLOW_UNTRUSTED=""
else
    echo -e "${RED}Ошибка: ни opkg, ни apk не найдены!${NC}"
    exit 1
fi

# ---------- Определение версии OpenWrt ----------
RELEASE="24.10"
if [ -f /etc/openwrt_release ]; then
    . /etc/openwrt_release
    case "$DISTRIB_RELEASE" in
        25.*) RELEASE="25.12" ;;
        24.*) RELEASE="24.10" ;;
    esac
fi

# ---------- Обычные пакеты ----------
PACKAGES="
nano|Текстовый редактор nano
unzip|Распаковка ZIP-архивов
ttyd|Веб-терминал (ttyd)
luci-i18n-base-ru|Русский язык для LuCI (базовый)
luci-app-ttyd|LuCI-приложение для ttyd
luci-i18n-ttyd-ru|Русский язык для luci-app-ttyd
luci-app-filemanager|Файловый менеджер в LuCI
luci-i18n-filemanager-ru|Русский язык для файлового менеджера
"

# ---------- dnsproxy ----------
DNSPROXY_PKG_NAME="luci-app-dnsproxy"
if [ "$RELEASE" = "25.12" ]; then
    DNSPROXY_URL="https://raw.githubusercontent.com/fantastic-packages/releases/25.12/packages/aarch64_cortex-a53/luci/luci-app-dnsproxy-26.250.33416~c43835f.apk"
    DNSPROXY_FILE="/tmp/luci-app-dnsproxy.apk"
else
    DNSPROXY_URL="https://raw.githubusercontent.com/fantastic-packages/releases/archive/24.10/packages/aarch64_generic/luci/luci-app-dnsproxy_26.250.33416~c43835f_all.ipk"
    DNSPROXY_FILE="/tmp/luci-app-dnsproxy.ipk"
fi

clear
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        Менеджер установки пакетов OpenWrt        ${NC}"
echo -e "${CYAN}        Менеджер: $PKG_MGR  |  Версия: $RELEASE          ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Автоматический подсчет номеров пунктов меню
TOTAL_PACKAGES_COUNT=0
for pkg in $(echo "$PACKAGES" | awk -F'|' 'NF>1 {print $1}'); do
    TOTAL_PACKAGES_COUNT=$((TOTAL_PACKAGES_COUNT + 1))
done

DNSPROXY_NUM=$((TOTAL_PACKAGES_COUNT + 1))
CFG_DNSPROXY_NUM=$((TOTAL_PACKAGES_COUNT + 2))
ZAPRET_NUM=$((TOTAL_PACKAGES_COUNT + 3))
SPLIFY_NUM=$((TOTAL_PACKAGES_COUNT + 4))
INETDET_NUM=$((TOTAL_PACKAGES_COUNT + 5))
THEME_NUM=$((TOTAL_PACKAGES_COUNT + 6))
ZEROTIER_NUM=$((TOTAL_PACKAGES_COUNT + 7))
FIXAPK_NUM=$((TOTAL_PACKAGES_COUNT + 8))
IPV6_NUM=$((TOTAL_PACKAGES_COUNT + 9))

# Отрисовка меню
echo -e "${CYAN}--- Базовые пакеты и локализация ---${NC}"
i=1
echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
    [ -z "$pkg" ] && continue
    printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$i" "$pkg" "$desc"
    i=$((i + 1))
done

echo ""
echo -e "${CYAN}--- Дополнительные компоненты ---${NC}"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$DNSPROXY_NUM" "luci-app-dnsproxy" "DNS Proxy с готовым конфигом"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$CFG_DNSPROXY_NUM" "Конфиг dnsproxy (только)" "Применить готовый конфиг DNS Proxy"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$ZAPRET_NUM" "Zapret Manager" "Управление обходом блокировок"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$SPLIFY_NUM" "Splify2" "Инструмент маршрутизации трафика"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$INETDET_NUM" "Internet Detector" "Детектор подключения с русификатором"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$THEME_NUM" "LuCI Theme Footstrap" "Установка современной темы оформления"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$ZEROTIER_NUM" "ZeroTier" "VPN-сеть для доступа к роутеру"

echo ""
echo -e "${CYAN}--- Система и сеть ---${NC}"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$FIXAPK_NUM" "Фикс APK в LuCI" "Разрешить установку локальных пакетов"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$IPV6_NUM" "Отключение IPv6" "Полное отключение протокола IPv6"

echo ""
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e " ${GREEN} 0${NC}) Установить абсолютно ВСЕ компоненты"
echo -e " ${RED} q${NC}) Выход"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo ""

printf "Введите номер пункта (или несколько через пробел): "
read -r choice

case "$choice" in
    q|Q|exit) echo "Выход."; exit 0 ;;
esac

# ---------- Обновление (только если нужно) ----------
if [ "$choice" != "$CFG_DNSPROXY_NUM" ]; then
    echo ""
    echo -e "${BLUE}>>> Обновление списка пакетов ($PKG_MGR)...${NC}"
    $UPDATE_CMD || {
        echo -e "${RED}Ошибка обновления списков пакетов!${NC}"
        exit 1
    }
fi

# ---------- Функции установки ----------
install_pkg() {
    echo -e "${GREEN}>>> Устанавливаю: $1${NC}"
    $INSTALL_CMD "$1" || echo -e "${RED}Не удалось установить $1${NC}"
}

apply_dnsproxy_config() {
    echo -e "${GREEN}>>> Применяю конфигурацию dnsproxy...${NC}"
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
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.dagami.ru/dns-query'
	list upstream 'sdns://AQAAAAAAAAAADjIwOC42Ny4yMjAuMjIwILc1EUAgbyJdPivYItf9aR6hwzzI1maNDL4Ev6vKQ_t5GzIuZG5zY3J5cHQtY2VydC5vcGVuZG5zLmNvbQ'
	list upstream 'sdns://AQMAAAAAAAAADDkuOS45Ljk6ODQ0MyBnyEe4yHWM0SAkVUO-dWdG3zTfHYTAC4xHA2jfgh2GPhkyLmRuc2NyeXB0LWNlcnQucXVhZDkubmV0'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'https://8.8.8.8/dns-query'
	list upstream 'https://doh.opendns.com/dns-query'
	list upstream 'quic://dns.quad9.net:853'
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
	list upstream '[/ru/xn--p1ai/]77.88.8.1'
	list upstream '[/openwrt.org/]1.1.1.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.8'
	list upstream '[/37signals.com/aave.com/access.broadcom.com/adobe.io/affinity.studio/ai.google.dev/aicode.googleapis.com/aida.googleapis.com/aisandbox-pa.googleapis.com/aistudio.google.com/aitestkitchen.withgoogle.com/alkalicore-pa.clients6.google.com/alkalimakersuite-pa.clients6.google.com/amd.com/analog.com/anthropic.com/antigravity-pa.googleapis.com/antigravity-unleash.goog/antigravity.google/antigravity.googleapis.com/api-sg-central.trae.ai/api.cdnlibs.org/api.fitbit.com/api.groq.com/api.home-connect.com/api.imgur.com/api.jetbrains.ai/api.radarr.video/api.trae.ai/api.workos.com/api16-normal-alisg.mchost.guru/api2.cursor.sh/api3.cursor.sh/api4.cursor.sh/api5.cursor.sh/apis.google.com/app.zerossl.com/appcatalyst.pa.googleapis.com/arduino.cc/arkoselabs.com/arrow.com/assistant-s3-pa.googleapis.com/astockcdn.net/atlassian.com/audacy.com/auth.xboxlive.com/authenticate.cursor.sh/authenticator.cursor.sh/autodesk.com/autodesk.net/avast.com/avast.ru/aybest.xyz/badoo.app/badoo.com/badoocdn.com/bard.google.com/basecamp.com/basecampapi.com/behance.net/bestbuy.com/bike-components.de/bike24.com/blogs.sap.com/brave.com/buf.build/build.nvidia.com/builds.parsec.app/bumble.com/buymeacoffee.com/camelai.com/canva-apps.com/canva.com/canva.dev/capcut.com/cdn.web-platform.io/cerebras.ai/cgtrader.com/chaos.com/chatgpt.com/chatgpt.site/chess.com/cici.com/ciscobinary.openh264.org/claude.ai/claude.com/claudemcpclient.com/claudeusercontent.com/clickup.com/cms-images.mmst.eu/codeium.com/community.sap.com/consent.trustarc.com/console.groq.com/console.neon.tech/controlplane.tailscale.com/copilot.microsoft.com/coreweave.com/corsair.com/crunchyroll.com/cummins.com/cursor-cdn.com/cursor.com/cursorvm.com/daily-cloudcode-pa.googleapis.com/datastudio.google.com/deepl.app/deepl.com/deepmind.com/deepmind.google/deezer.com/dell.com/dellcdn.com/deniko.xyz/designer.microsoft.com/designify.com/developer.nvidia.com/developerprofiles-pa.googleapis.com/digikey.com/digikeyassets.com/dl.teamviewer.com/dnsspeedtest.online/dola.com/download.teamviewer.com/download.todesktop.com/dr.miromind.ai/dtm8.dinamicagenerale.com/dyson.com/dyson.de/dyson.se/ecosia.org/ecs.office.com/edgeservices.bing.com/efsanetv.xyz/elevenlabs.io/elevenmusic.io/elevenreader.io/elgato.com/elmastvnet.xyz/eneba.com/enscape3d.com/etsy.com/eu.posthog.com/euro.com.pl/evike.com/eyyo.xyz/f00.esfr.pl/files-s2pb.pbsync.com/files.manuscdn.com/fitbit-pa.googleapis.com/fitbit.google.com/fitbitvestibuleshim-pa.googleapis.com/flow.google/flow.google.com/flowmusic.app/fmhy.net/formula1.com/framer.com/freakhosting.com/g2a.com/game8.co/game8.co.jp/game8.jp/gamestop.com/geller-pa.googleapis.com/gemini.google/gemini.google.com/geminiweb-pa.clients.google.com/geminiweb-pa.clients6.google.com/generativeai.google/generativelanguage.googleapis.com/genspark.ai/geolocation.onetrust.com/gql.twitch.tv/grok.com/grok.x.com/gssv-play-prod.xboxlive.com/guidedhacking.com/guilded.gg/hapi.hentaicdn.org/hume.ai/ikea.com/images.contentstack.io/img.modivo.cloud/inceptionlabs.ai/indeed.com/intel.com/intel.de/intel.se/iperf3serverlist.net/jetbrains.com/jetbrains.space/jules.google/jules.google.com/kaleido.ai/knowledge.broadcom.com/labs.google/labs.google.com/labstailwind.pa.googleapis.com/last.fm/lego.com/linear.app/linguee.com/lookerstudio.google.com/m3u.in/madmapper.com/make.com/makersuite.google.com/makita.ca/makita.cl/makita.co.nz/makita.com.au/makita.com.kh/makita.com.tw/makita.sk/makita.ua/makitalatinamerica.com/malwarebytes.com/manus.im/manybooks.net/marketplace.cursorapi.com/mediaexpert.pl/mediamarkt.pl/meta.ai/microcenter.com/microchip.com/minicircuits.com/miro.com/misterfpga.org/modivo.pl/mongodb.com/monica.im/mouser.com/myjetbrains.com/n8n.cloud/naukimg.com/naukri.com/ndi.tv/ndi.video/netapp.com/ngc.nvidia.com/notebook-pa.googleapis.com/notebook.google/notebook.google.com/notebooklm-pa.googleapis.com/notebooklm.google/notebooklm.google.com/notion.com/notion.so/o.pki.goog/oaistatic.com/oaiusercontent.com/octanorm.com/octanorm.expo.shop/old.yummyani.me/opal.google/opal.google.com/opal.withgoogle.com/openai.com/opencode.ai/openrouter.ai/oracle.com/padi.com/pandasecurity.com/panic.com/pcmag.com/people-pa.clients6.google.com/pi.ai/platform.parallel.ai/play.date/playground.google/powertoolsuk.co.uk/ppkas.com/pr0gramm.com/proactivebackend-pa.googleapis.com/profile.broadcom.com/promods.net/prowlarr.servarr.com/pump.fun/qoder.com/qualtrics.com/qwant.com/remove.bg/repo42.cursor.sh/res.cloudinary.com/reve.art/reve.com/rewards.bing.com/robinfrontend-pa.googleapis.com/romsgames.net/scdn.co/scribd.com/scribdassets.com/se.com/securitytrails.com/signaler-pa.clients6.google.com/singlekey-id.com/sketchup.com/slack-core.com/slack-edge.com/slack.com/slackb.com/spotify.com/spotify.dev/squareup.com/stitch.withgoogle.com/strava.com/superpharm.eu/superpharm.pl/support.broadcom.com/sydney.bing.com/tableau.com/ti.com/titlestorage.xboxlive.com/tokenharbor.ai/trae-api-sg.mchost.guru/tria.ge/trimble.com/trueachievements.com/truthsocial.com/tuta.com/uainvest.com.ua/ultimaker.com/unscreen.com/us-asia.gcpp.cursor.sh/us-eu.gcpp.cursor.sh/us-only.gcpp.cursor.sh/users.wix.com/usher.ttvnw.net/vipvera.com/w-x.co/waa-pa.clients6.google.com/wbagora.com/wbgames.com/weather.com/web.archive.org/webchannel-alkalimakersuite-pa.clients6.google.com/weborama.nl/whimsical.com/windguru.cz/windsurf.com/wise.com/ws.audioscrobbler.com/wund.com/wunderground.com/wxug.com/x.ai/xboxdesignlab.xbox.com/xerox.com/xiaomi.eu/yeggi.com/yupp.ai/zapier-deployment.com/zapier.com/]https://dns.dagami.ru/dns-query'
	list upstream 'sdns://AQAAAAAAAAAADjIwOC42Ny4yMjAuMjIwILc1EUAgbyJdPivYItf9aR6hwzzI1maNDL4Ev6vKQ_t5GzIuZG5zY3J5cHQtY2VydC5vcGVuZG5zLmNvbQ'
	list upstream 'sdns://AQMAAAAAAAAADDkuOS45Ljk6ODQ0MyBnyEe4yHWM0SAkVUO-dWdG3zTfHYTAC4xHA2jfgh2GPhkyLmRuc2NyeXB0LWNlcnQucXVhZDkubmV0'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'https://8.8.8.8/dns-query'
	list upstream 'https://doh.opendns.com/dns-query'
	
	list fallback '77.88.8.8'
	list fallback '77.88.8.1'
EOF

    echo -e "${GREEN}>>> Настраиваю dnsmasq (127.0.0.1#5353)...${NC}"
    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci -q delete dhcp.@dnsmasq[0].server
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
    uci commit dhcp

    /etc/init.d/dnsproxy enable 2>/dev/null
    /etc/init.d/dnsproxy restart 2>/dev/null
    /etc/init.d/dnsmasq restart
    echo -e "${GREEN}>>> Конфигурация dnsproxy успешно применена${NC}"
}

install_dnsproxy() {
    echo -e "${GREEN}>>> Скачиваю luci-app-dnsproxy...${NC}"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$DNSPROXY_FILE" "$DNSPROXY_URL" || { echo -e "${RED}Ошибка скачивания${NC}"; return 1; }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$DNSPROXY_FILE" "$DNSPROXY_URL" || { echo -e "${RED}Ошибка скачивания${NC}"; return 1; }
    else
        echo -e "${RED}Нет wget и curl${NC}"
        return 1
    fi

    echo -e "${GREEN}>>> Устанавливаю luci-app-dnsproxy...${NC}"
    if [ "$PKG_MGR" = "apk" ]; then
        apk add $ALLOW_UNTRUSTED "$DNSPROXY_FILE" || echo -e "${RED}Ошибка установки${NC}"
    else
        opkg install $ALLOW_UNTRUSTED "$DNSPROXY_FILE" || echo -e "${RED}Ошибка установки${NC}"
    fi
    rm -f "$DNSPROXY_FILE"

    apply_dnsproxy_config
}

install_zapret() {
    echo -e "${GREEN}>>> Устанавливаю Zapret Manager...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi
    sh <(wget -qO - https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/ZapretManager_LuCI.sh) || {
        echo -e "${RED}Ошибка установки Zapret Manager${NC}"
        return 1
    }
    echo -e "${GREEN}>>> Zapret Manager установлен${NC}"
}

install_splify() {
    echo -e "${GREEN}>>> Устанавливаю Splify2...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi
    sh -c "$(wget -qO- https://gitlab.com/xyzmean/splify2/-/raw/main/install.sh)" || {
        echo -e "${RED}Ошибка установки Splify2${NC}"
        return 1
    }
    echo -e "${GREEN}>>> Splify2 установлен${NC}"
}

install_internet_detector() {
    echo -e "${GREEN}>>> Устанавливаю Internet Detector (авто-определение версии)...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi

    if [ "$RELEASE" = "25.12" ] || [ "$PKG_MGR" = "apk" ]; then
        BRANCH="25.12"
        EXT="apk"
    else
        BRANCH="24.10"
        EXT="ipk"
    fi

    echo -e "${BLUE}>>> Сканирую репозиторий GitHub ($BRANCH)...${NC}"
    WEB_URL="https://github.com/gSpotx2f/packages-openwrt/tree/master/$BRANCH"
    
    HTML_CONTENT=$(wget -qO- --header="User-Agent: Mozilla/5.0" "$WEB_URL")

    if [ "$EXT" = "apk" ]; then
        FILE_CORE=$(echo "$HTML_CONTENT" | grep -oE "internet-detector-[0-9\.-]+-r[0-9]+\.apk" | head -n 1)
        FILE_LUCI=$(echo "$HTML_CONTENT" | grep -oE "luci-app-internet-detector-[0-9\.-]+-r[0-9]+\.apk" | head -n 1)
        FILE_RU=$(echo "$HTML_CONTENT" | grep -oE "luci-i18n-internet-detector-ru-[0-9\.-]+-r[0-9]+\.apk" | head -n 1)
    else
        FILE_CORE=$(echo "$HTML_CONTENT" | grep -oE "internet-detector_[0-9\.-]_[a-z0-9_]+\.ipk" | head -n 1)
        [ -z "$FILE_CORE" ] && FILE_CORE=$(echo "$HTML_CONTENT" | grep -oE "internet-detector_[0-9\.-]+_[a-zA-Z0-9_-]+\.ipk" | head -n 1)
        
        FILE_LUCI=$(echo "$HTML_CONTENT" | grep -oE "luci-app-internet-detector_[0-9\.-]+_[a-zA-Z0-9_-]+\.ipk" | head -n 1)
        FILE_RU=$(echo "$HTML_CONTENT" | grep -oE "luci-i18n-internet-detector-ru_[0-9\.-]+_[a-zA-Z0-9_-]+\.ipk" | head -n 1)
    fi

    if [ -z "$FILE_CORE" ]; then
        echo -e "${YELLOW}Не удалось автоматически найти имена через веб-страницу, используем r2 по умолчанию...${NC}"
        if [ "$EXT" = "apk" ]; then
            FILE_CORE="internet-detector-1.7.4-r2.apk"
            FILE_LUCI="luci-app-internet-detector-1.7.4-r2.apk"
            FILE_RU="luci-i18n-internet-detector-ru-1.7.4-r2.apk"
        else
            FILE_CORE="internet-detector_1.7.4-r2_all.ipk"
            FILE_LUCI="luci-app-internet-detector_1.7.4-r2_all.ipk"
            FILE_RU="luci-i18n-internet-detector-ru_1.7.4-r2_all.ipk"
        fi
    fi

    RAW_BASE="https://github.com/gSpotx2f/packages-openwrt/raw/master/$BRANCH"

    echo -e "${GREEN}>>> Скачиваю и устанавливаю: $FILE_CORE${NC}"
    wget --no-check-certificate -O "/tmp/$FILE_CORE" "$RAW_BASE/$FILE_CORE" || { echo -e "${RED}Ошибка скачивания Core${NC}"; return 1; }
    $INSTALL_CMD $ALLOW_UNTRUSTED "/tmp/$FILE_CORE"
    rm -f "/tmp/$FILE_CORE"

    service internet-detector start 2>/dev/null
    service internet-detector enable 2>/dev/null

    echo -e "${GREEN}>>> Скачиваю и устанавливаю: $FILE_LUCI${NC}"
    wget --no-check-certificate -O "/tmp/$FILE_LUCI" "$RAW_BASE/$FILE_LUCI" || { echo -e "${RED}Ошибка скачивания LuCI App${NC}"; return 1; }
    $INSTALL_CMD $ALLOW_UNTRUSTED "/tmp/$FILE_LUCI"
    rm -f "/tmp/$FILE_LUCI"

    service rpcd restart 2>/dev/null

    echo -e "${GREEN}>>> Скачиваю и устанавливаю: $FILE_RU${NC}"
    wget --no-check-certificate -O "/tmp/$FILE_RU" "$RAW_BASE/$FILE_RU" || { echo -e "${RED}Ошибка скачивания локализации${NC}"; return 1; }
    $INSTALL_CMD $ALLOW_UNTRUSTED "/tmp/$FILE_RU"
    rm -f "/tmp/$FILE_RU"

    echo -e "${GREEN}>>> Internet Detector успешно установлен!${NC}"
}

install_theme() {
    echo -e "${GREEN}>>> Устанавливаю тему luci-theme-footstrap...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi
    
    wget -qO- https://raw.githubusercontent.com/VizzleTF/luci-theme-footstrap/main/install.sh | sh || {
        echo -e "${RED}Ошибка установки темы${NC}"
        return 1
    }

    echo -e "${GREEN}>>> Устанавливаю русскую локализацию для темы через $PKG_MGR...${NC}"
    $INSTALL_CMD $ALLOW_UNTRUSTED luci-i18n-footstrap-ru || {
        echo -e "${YELLOW}Не удалось установить локализацию темы через менеджер пакетов (возможно, её нет в репозитории вашей версии прошивки)${NC}"
    }

    echo -e "${GREEN}>>> Тема и локализация обработаны${NC}"
}

install_zerotier() {
    echo -e "${GREEN}>>> Устанавливаю ZeroTier...${NC}"
    $INSTALL_CMD $ALLOW_UNTRUSTED zerotier luci-app-zerotier luci-i18n-zerotier-ru 2>/dev/null || \
    $INSTALL_CMD $ALLOW_UNTRUSTED zerotier luci-app-zerotier 2>/dev/null || \
    $INSTALL_CMD $ALLOW_UNTRUSTED zerotier || {
        echo -e "${RED}Ошибка установки ZeroTier${NC}"
        return 1
    }

    /etc/init.d/zerotier enable
    /etc/init.d/zerotier start

    if [ -z "$ZEROTIER_NET_ID" ]; then
        echo ""
        echo -e "${CYAN}Введите 16-значный ID вашей сети ZeroTier (Network ID):${NC}"
        read -r ZEROTIER_NET_ID
    fi

    if [ -n "$ZEROTIER_NET_ID" ]; then
        echo -e "${GREEN}>>> Подключаюсь к сети ZeroTier: $ZEROTIER_NET_ID${NC}"
        zerotier-cli join "$ZEROTIER_NET_ID"
    else
        echo -e "${YELLOW}Network ID не введен. Вы сможете подключить сеть позже через LuCI или командную строку (zerotier-cli join <ID>).${NC}"
    fi

    echo -e "${GREEN}>>> Настраиваю сетевой интерфейс и фаервол для ZeroTier (доступ к веб-админке и SSH)...${NC}"
    uci set network.zerotier=interface
    uci set network.zerotier.proto='none'
    uci set network.zerotier.device='zt+'
    
    if uci get firewall.@zone[0].name | grep -q "lan"; then
        uci add_list firewall.@zone[0].network='zerotier' 2>/dev/null || true
    fi
    uci commit network
    uci commit firewall

    /etc/init.d/network restart
    /etc/init.d/firewall restart
    echo -e "${GREEN}>>> ZeroTier успешно установлен и настроен!${NC}"
    echo -e "${YELLOW}Не забудьте авторизовать устройство в панели управления ZeroTier (my.zerotier.com).${NC}"
}

fix_apk_luci() {
    echo -e "${GREEN}>>> Применяю фикс пакетного менеджера для LuCI...${NC}"
    if [ -f /usr/libexec/package-manager-call ]; then
        sed -i 's/action="add"/action="add --allow-untrusted"/g' /usr/libexec/package-manager-call
        echo -e "${GREEN}>>> Фикс успешно применен${NC}"
    else
        echo -e "${YELLOW}Файл /usr/libexec/package-manager-call не найден (возможно, не версия 25.12)${NC}"
    fi
}

disable_ipv6() {
    echo -e "${GREEN}>>> Отключаю IPv6...${NC}"
    uci set network.lan.ipv6='0'
    uci set network.wan.ipv6='0'
    uci set network.lan.delegate="0"

    uci set dhcp.lan.dhcpv6='disabled'
    uci -q delete dhcp.lan.dhcpv6
    uci -q delete dhcp.lan.ra

    uci -q delete network.globals.ula_prefix

    /etc/init.d/odhcpd disable
    /etc/init.d/odhcpd stop

    uci set dhcp.@dnsmasq[0].filter_aaaa='1'

    uci commit
    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    echo -e "${GREEN}>>> IPv6 успешно отключен${NC}"
}

# ---------- Логика выполнения ----------
if [ "$choice" = "0" ]; then
    echo -e "${YELLOW}>>> Устанавливаю все компоненты и применяю настройки...${NC}"
    
    # Запрос ID сети заранее для пункта "установить всё"
    echo ""
    echo -e "${CYAN}Введите 16-значный ID вашей сети ZeroTier (Network ID) [можно пропустить, нажав Enter]:${NC}"
    read -r ZEROTIER_NET_ID

    echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        install_pkg "$pkg"
    done
    install_dnsproxy
    install_zapret
    install_splify
    install_internet_detector
    install_theme
    install_zerotier
    fix_apk_luci
    disable_ipv6
else
    for num in $choice; do
        case "$num" in
            *[!0-9]*) 
                echo -e "${RED}Неверный выбор: $num${NC}"
                continue 
                ;;
        esac

        if [ "$num" -eq "$DNSPROXY_NUM" ]; then
            install_dnsproxy
            continue
        fi
        if [ "$num" -eq "$CFG_DNSPROXY_NUM" ]; then
            apply_dnsproxy_config
            continue
        fi
        if [ "$num" -eq "$ZAPRET_NUM" ]; then
            install_zapret
            continue
        fi
        if [ "$num" -eq "$SPLIFY_NUM" ]; then
            install_splify
            continue
        fi
        if [ "$num" -eq "$INETDET_NUM" ];        then
            install_internet_detector
            continue
        fi
        if [ "$num" -eq "$THEME_NUM" ]; then
            install_theme
            continue
        fi
        if [ "$num" -eq "$ZEROTIER_NUM" ]; then
            install_zerotier
            continue
        fi
        if [ "$num" -eq "$FIXAPK_NUM" ]; then
            fix_apk_luci
            continue
        fi
        if [ "$num" -eq "$IPV6_NUM" ]; then
            disable_ipv6
            continue
        fi

        i=1
        echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
            [ -z "$pkg" ] && continue
            if [ "$i" -eq "$num" ]; then
                install_pkg "$pkg"
            fi
            i=$((i + 1))
        done
    done
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}  Все задачи выполнены!${NC}"
echo -e "${BLUE}==================================================${NC}"
