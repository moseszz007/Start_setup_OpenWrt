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

HTTPS_DNS_PROXY_NUM=$((TOTAL_PACKAGES_COUNT + 1))
CFG_HTTPS_PROXY_NUM=$((TOTAL_PACKAGES_COUNT + 2))
ZAPRET_NUM=$((TOTAL_PACKAGES_COUNT + 3))
SPLIFY_NUM=$((TOTAL_PACKAGES_COUNT + 4))
INETDET_NUM=$((TOTAL_PACKAGES_COUNT + 5))
ZEROTIER_NUM=$((TOTAL_PACKAGES_COUNT + 6))
FIXAPK_NUM=$((TOTAL_PACKAGES_COUNT + 7))
IPV6_NUM=$((TOTAL_PACKAGES_COUNT + 8))

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
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$HTTPS_DNS_PROXY_NUM" "https-dns-proxy" "DNS-over-HTTPS с поддержкой LuCI"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$CFG_HTTPS_PROXY_NUM" "Конфиг https-dns-proxy (только)" "Применить расширенный конфиг и список серверов"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$ZAPRET_NUM" "Zapret Manager" "Управление обходом блокировок"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$SPLIFY_NUM" "Splify2" "Инструмент маршрутизации трафика"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$INETDET_NUM" "Internet Detector" "Детектор подключения с русификатором"
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
if [ "$choice" != "$CFG_HTTPS_PROXY_NUM" ]; then
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

apply_https_proxy_config() {
    echo -e "${GREEN}>>> Применяю расширенную конфигурацию https-dns-proxy...${NC}"
    
    cat > /etc/config/https-dns-proxy << 'EOF'
config main 'config'
	option dnsmasq_config_update '-'
	option force_dns '0'
	option notrack_dns '1'
	list force_dns_port '53'
	list force_dns_port '853'
	list force_dns_src_interface 'lan'
	option procd_trigger_wan6 '0'
	option heartbeat_domain 'heartbeat.mossdef.org'
	option heartbeat_sleep_timeout '10'
	option heartbeat_wait_timeout '10'
	option user 'nobody'
	option group 'nogroup'
	option listen_addr '127.0.0.1'
	option force_ip_family 'auto'

config splify2_backup 'splify2'
	option splify2_state 'saved'
	list splify2_orig 'config main '\''config'\'''
	list splify2_orig '	option canary_domains_icloud '\''1'\'''
	list splify2_orig '	option canary_domains_mozilla '\''1'\'''
	list splify2_orig '	option dnsmasq_config_update '\''-'\'''
	list splify2_orig '	option force_dns '\''1'\'''
	list splify2_orig '	list force_dns_port '\''53'\'''
	list splify2_orig '	list force_dns_port '\''853'\'''
	list splify2_orig '	list force_dns_src_interface '\''lan'\'''
	list splify2_orig '	option procd_trigger_wan6 '\''0'\'''
	list splify2_orig '	option heartbeat_domain '\''heartbeat.melmac.ca'\'''
	list splify2_orig '	option heartbeat_sleep_timeout '\''10'\'''
	list splify2_orig '	option heartbeat_wait_timeout '\''10'\'''
	list splify2_orig '	option user '\''nobody'\'''
	list splify2_orig '	option group '\''nogroup'\'''
	list splify2_orig '	option listen_addr '\''127.0.0.1'\'''
	list splify2_orig 'config https-dns-proxy'
	list splify2_orig '	option resolver_url '\''https://dns.quad9.net/dns-query'\'''
	list splify2_orig '	option bootstrap_dns '\''9.9.9.9,149.112.112.112,2620:fe::fe,2620:fe::9'\'''
	list splify2_orig '	option listen_port '\''5054'\'''
	list splify2_orig 'config https-dns-proxy'
	list splify2_orig '	option resolver_url '\''https://freedns.controld.com/p0'\'''
	list splify2_orig '	option bootstrap_dns '\''76.76.2.0,2606:1a40::0'\'''
	list splify2_orig '	option listen_port '\''5053'\'''
	list splify2_orig 'config https-dns-proxy'
	list splify2_orig '	option resolver_url '\''https://dns.geohide.ru:444/dns-query'\'''
	list splify2_orig '	option listen_addr '\''127.0.0.1'\'''
	list splify2_orig '	option listen_port '\''5555'\'''
	list splify2_orig 'config https-dns-proxy'
	list splify2_orig '	option resolver_url '\''https://xbox-dns.ru/dns-query'\'''
	list splify2_orig '	option listen_addr '\''127.0.0.1'\'''
	list splify2_orig '	option listen_port '\''5554'\'''

config https-dns-proxy
	option resolver_url 'https://doh.opendns.com/dns-query'
	option bootstrap_dns '208.67.222.222,208.67.220.220,2620:119:35::35,2620:119:53::53'
	option listen_port '5053'

config https-dns-proxy
	option resolver_url 'https://9.9.9.9/dns-query'
	option bootstrap_dns '9.9.9.9'
	option listen_port '5054'

config https-dns-proxy
	option resolver_url 'https://freedns.controld.com/p0'
	option bootstrap_dns '76.76.2.0,2606:1a40::0'
	option listen_port '5055'

config https-dns-proxy
	option resolver_url 'https://dns.magicdns.ru/dns-query'
	option listen_port '5554'
	option listen_addr '127.0.0.1'

config https-dns-proxy
	option resolver_url 'https://dns.dagami.ru/dns-query'
	option listen_port '5555'
	option listen_addr '127.0.0.1'
EOF

    echo -e "${GREEN}>>> Создаю файл /etc/dnsmasq.servers со списком серверов...${NC}"
    cat > /etc/dnsmasq.servers << 'EOF'
server=/37signals.com/127.0.0.1#5554
server=/37signals.com/127.0.0.1#5555
server=/aave.com/127.0.0.1#5554
server=/aave.com/127.0.0.1#5555
server=/access.broadcom.com/127.0.0.1#5554
server=/access.broadcom.com/127.0.0.1#5555
server=/adobe.io/127.0.0.1#5554
server=/adobe.io/127.0.0.1#5555
server=/affinity.studio/127.0.0.1#5554
server=/affinity.studio/127.0.0.1#5555
server=/ai.google.dev/127.0.0.1#5554
server=/ai.google.dev/127.0.0.1#5555
server=/aicode.googleapis.com/127.0.0.1#5554
server=/aicode.googleapis.com/127.0.0.1#5555
server=/aida.googleapis.com/127.0.0.1#5554
server=/aida.googleapis.com/127.0.0.1#5555
server=/aisandbox-pa.googleapis.com/127.0.0.1#5554
server=/aisandbox-pa.googleapis.com/127.0.0.1#5555
server=/aistudio.google.com/127.0.0.1#5554
server=/aistudio.google.com/127.0.0.1#5555
server=/aitestkitchen.withgoogle.com/127.0.0.1#5554
server=/aitestkitchen.withgoogle.com/127.0.0.1#5555
server=/alkalicore-pa.clients6.google.com/127.0.0.1#5554
server=/alkalicore-pa.clients6.google.com/127.0.0.1#5555
server=/alkalimakersuite-pa.clients6.google.com/127.0.0.1#5554
server=/alkalimakersuite-pa.clients6.google.com/127.0.0.1#5555
server=/amd.com/127.0.0.1#5554
server=/amd.com/127.0.0.1#5555
server=/analog.com/127.0.0.1#5554
server=/analog.com/127.0.0.1#5555
server=/anthropic.com/127.0.0.1#5554
server=/anthropic.com/127.0.0.1#5555
server=/antigravity-pa.googleapis.com/127.0.0.1#5554
server=/antigravity-pa.googleapis.com/127.0.0.1#5555
server=/antigravity-unleash.goog/127.0.0.1#5554
server=/antigravity-unleash.goog/127.0.0.1#5555
server=/antigravity.google/127.0.0.1#5554
server=/antigravity.google/127.0.0.1#5555
server=/antigravity.googleapis.com/127.0.0.1#5554
server=/antigravity.googleapis.com/127.0.0.1#5555
server=/api-sg-central.trae.ai/127.0.0.1#5554
server=/api-sg-central.trae.ai/127.0.0.1#5555
server=/api.cdnlibs.org/127.0.0.1#5554
server=/api.cdnlibs.org/127.0.0.1#5555
server=/api.fitbit.com/127.0.0.1#5554
server=/api.fitbit.com/127.0.0.1#5555
server=/api.groq.com/127.0.0.1#5554
server=/api.groq.com/127.0.0.1#5555
server=/api.home-connect.com/127.0.0.1#5554
server=/api.home-connect.com/127.0.0.1#5555
server=/api.imgur.com/127.0.0.1#5554
server=/api.imgur.com/127.0.0.1#5555
server=/api.jetbrains.ai/127.0.0.1#5554
server=/api.jetbrains.ai/127.0.0.1#5555
server=/api.radarr.video/127.0.0.1#5554
server=/api.radarr.video/127.0.0.1#5555
server=/api.trae.ai/127.0.0.1#5554
server=/api.trae.ai/127.0.0.1#5555
server=/api.workos.com/127.0.0.1#5554
server=/api.workos.com/127.0.0.1#5555
server=/api16-normal-alisg.mchost.guru/127.0.0.1#5554
server=/api16-normal-alisg.mchost.guru/127.0.0.1#5555
server=/api2.cursor.sh/127.0.0.1#5554
server=/api2.cursor.sh/127.0.0.1#5555
server=/api3.cursor.sh/127.0.0.1#5554
server=/api3.cursor.sh/127.0.0.1#5555
server=/api4.cursor.sh/127.0.0.1#5554
server=/api4.cursor.sh/127.0.0.1#5555
server=/api5.cursor.sh/127.0.0.1#5554
server=/api5.cursor.sh/127.0.0.1#5555
server=/apis.google.com/127.0.0.1#5554
server=/apis.google.com/127.0.0.1#5555
server=/app.zerossl.com/127.0.0.1#5554
server=/app.zerossl.com/127.0.0.1#5555
server=/appcatalyst.pa.googleapis.com/127.0.0.1#5554
server=/appcatalyst.pa.googleapis.com/127.0.0.1#5555
server=/arduino.cc/127.0.0.1#5554
server=/arduino.cc/127.0.0.1#5555
server=/arkoselabs.com/127.0.0.1#5554
server=/arkoselabs.com/127.0.0.1#5555
server=/arrow.com/127.0.0.1#5554
server=/arrow.com/127.0.0.1#5555
server=/assistant-s3-pa.googleapis.com/127.0.0.1#5554
server=/assistant-s3-pa.googleapis.com/127.0.0.1#5555
server=/astockcdn.net/127.0.0.1#5554
server=/astockcdn.net/127.0.0.1#5555
server=/atlassian.com/127.0.0.1#5554
server=/atlassian.com/127.0.0.1#5555
server=/audacy.com/127.0.0.1#5554
server=/audacy.com/127.0.0.1#5555
server=/auth.xboxlive.com/127.0.0.1#5554
server=/auth.xboxlive.com/127.0.0.1#5555
server=/authenticate.cursor.sh/127.0.0.1#5554
server=/authenticate.cursor.sh/127.0.0.1#5555
server=/authenticator.cursor.sh/127.0.0.1#5554
server=/authenticator.cursor.sh/127.0.0.1#5555
server=/autodesk.com/127.0.0.1#5554
server=/autodesk.com/127.0.0.1#5555
server=/autodesk.net/127.0.0.1#5554
server=/autodesk.net/127.0.0.1#5555
server=/avast.com/127.0.0.1#5554
server=/avast.com/127.0.0.1#5555
server=/avast.ru/127.0.0.1#5554
server=/avast.ru/127.0.0.1#5555
server=/aybest.xyz/127.0.0.1#5554
server=/aybest.xyz/127.0.0.1#5555
server=/badoo.app/127.0.0.1#5554
server=/badoo.app/127.0.0.1#5555
server=/badoo.com/127.0.0.1#5554
server=/badoo.com/127.0.0.1#5555
server=/badoocdn.com/127.0.0.1#5554
server=/badoocdn.com/127.0.0.1#5555
server=/bard.google.com/127.0.0.1#5554
server=/bard.google.com/127.0.0.1#5555
server=/basecamp.com/127.0.0.1#5554
server=/basecamp.com/127.0.0.1#5555
server=/basecampapi.com/127.0.0.1#5554
server=/basecampapi.com/127.0.0.1#5555
server=/behance.net/127.0.0.1#5554
server=/behance.net/127.0.0.1#5555
server=/bestbuy.com/127.0.0.1#5554
server=/bestbuy.com/127.0.0.1#5555
server=/bike-components.de/127.0.0.1#5554
server=/bike-components.de/127.0.0.1#5555
server=/bike24.com/127.0.0.1#5554
server=/bike24.com/127.0.0.1#5555
server=/blogs.sap.com/127.0.0.1#5554
server=/blogs.sap.com/127.0.0.1#5555
server=/brave.com/127.0.0.1#5554
server=/brave.com/127.0.0.1#5555
server=/buf.build/127.0.0.1#5554
server=/buf.build/127.0.0.1#5555
server=/build.nvidia.com/127.0.0.1#5554
server=/build.nvidia.com/127.0.0.1#5555
server=/builds.parsec.app/127.0.0.1#5554
server=/builds.parsec.app/127.0.0.1#5555
server=/bumble.com/127.0.0.1#5554
server=/bumble.com/127.0.0.1#5555
server=/buymeacoffee.com/127.0.0.1#5554
server=/buymeacoffee.com/127.0.0.1#5555
server=/camelai.com/127.0.0.1#5554
server=/camelai.com/127.0.0.1#5555
server=/canva-apps.com/127.0.0.1#5554
server=/canva-apps.com/127.0.0.1#5555
server=/canva.com/127.0.0.1#5554
server=/canva.com/127.0.0.1#5555
server=/canva.dev/127.0.0.1#5554
server=/canva.dev/127.0.0.1#5555
server=/capcut.com/127.0.0.1#5554
server=/capcut.com/127.0.0.1#5555
server=/cdn.web-platform.io/127.0.0.1#5554
server=/cdn.web-platform.io/127.0.0.1#5555
server=/cerebras.ai/127.0.0.1#5554
server=/cerebras.ai/127.0.0.1#5555
server=/cgtrader.com/127.0.0.1#5554
server=/cgtrader.com/127.0.0.1#5555
server=/chaos.com/127.0.0.1#5554
server=/chaos.com/127.0.0.1#5555
server=/chatgpt.com/127.0.0.1#5554
server=/chatgpt.com/127.0.0.1#5555
server=/chatgpt.site/127.0.0.1#5554
server=/chatgpt.site/127.0.0.1#5555
server=/chess.com/127.0.0.1#5554
server=/chess.com/127.0.0.1#5555
server=/cici.com/127.0.0.1#5554
server=/cici.com/127.0.0.1#5555
server=/ciscobinary.openh264.org/127.0.0.1#5554
server=/ciscobinary.openh264.org/127.0.0.1#5555
server=/claude.ai/127.0.0.1#5554
server=/claude.ai/127.0.0.1#5555
server=/claude.com/127.0.0.1#5554
server=/claude.com/127.0.0.1#5555
server=/claudemcpclient.com/127.0.0.1#5554
server=/claudemcpclient.com/127.0.0.1#5555
server=/claudeusercontent.com/127.0.0.1#5554
server=/claudeusercontent.com/127.0.0.1#5555
server=/clickup.com/127.0.0.1#5554
server=/clickup.com/127.0.0.1#5555
server=/cms-images.mmst.eu/127.0.0.1#5554
server=/cms-images.mmst.eu/127.0.0.1#5555
server=/codeium.com/127.0.0.1#5554
server=/codeium.com/127.0.0.1#5555
server=/community.sap.com/127.0.0.1#5554
server=/community.sap.com/127.0.0.1#5555
server=/consent.trustarc.com/127.0.0.1#5554
server=/consent.trustarc.com/127.0.0.1#5555
server=/console.groq.com/127.0.0.1#5554
server=/console.groq.com/127.0.0.1#5555
server=/console.neon.tech/127.0.0.1#5554
server=/console.neon.tech/127.0.0.1#5555
server=/controlplane.tailscale.com/127.0.0.1#5554
server=/controlplane.tailscale.com/127.0.0.1#5555
server=/copilot.microsoft.com/127.0.0.1#5554
server=/copilot.microsoft.com/127.0.0.1#5555
server=/coreweave.com/127.0.0.1#5554
server=/coreweave.com/127.0.0.1#5555
server=/corsair.com/127.0.0.1#5554
server=/corsair.com/127.0.0.1#5555
server=/crunchyroll.com/127.0.0.1#5554
server=/crunchyroll.com/127.0.0.1#5555
server=/cummins.com/127.0.0.1#5554
server=/cummins.com/127.0.0.1#5555
server=/cursor-cdn.com/127.0.0.1#5554
server=/cursor-cdn.com/127.0.0.1#5555
server=/cursor.com/127.0.0.1#5554
server=/cursor.com/127.0.0.1#5555
server=/cursorvm.com/127.0.0.1#5554
server=/cursorvm.com/127.0.0.1#5555
server=/daily-cloudcode-pa.googleapis.com/127.0.0.1#5554
server=/daily-cloudcode-pa.googleapis.com/127.0.0.1#5555
server=/datastudio.google.com/127.0.0.1#5554
server=/datastudio.google.com/127.0.0.1#5555
server=/deepl.app/127.0.0.1#5554
server=/deepl.app/127.0.0.1#5555
server=/deepl.com/127.0.0.1#5554
server=/deepl.com/127.0.0.1#5555
server=/deepmind.com/127.0.0.1#5554
server=/deepmind.com/127.0.0.1#5555
server=/deepmind.google/127.0.0.1#5554
server=/deepmind.google/127.0.0.1#5555
server=/deezer.com/127.0.0.1#5554
server=/deezer.com/127.0.0.1#5555
server=/dell.com/127.0.0.1#5554
server=/dell.com/127.0.0.1#5555
server=/dellcdn.com/127.0.0.1#5554
server=/dellcdn.com/127.0.0.1#5555
server=/deniko.xyz/127.0.0.1#5554
server=/deniko.xyz/127.0.0.1#5555
server=/designer.microsoft.com/127.0.0.1#5554
server=/designer.microsoft.com/127.0.0.1#5555
server=/designify.com/127.0.0.1#5554
server=/designify.com/127.0.0.1#5555
server=/developer.nvidia.com/127.0.0.1#5554
server=/developer.nvidia.com/127.0.0.1#5555
server=/developerprofiles-pa.googleapis.com/127.0.0.1#5554
server=/developerprofiles-pa.googleapis.com/127.0.0.1#5555
server=/digikey.com/127.0.0.1#5554
server=/digikey.com/127.0.0.1#5555
server=/digikeyassets.com/127.0.0.1#5554
server=/digikeyassets.com/127.0.0.1#5555
server=/dl.teamviewer.com/127.0.0.1#5554
server=/dl.teamviewer.com/127.0.0.1#5555
server=/dnsspeedtest.online/127.0.0.1#5554
server=/dnsspeedtest.online/127.0.0.1#5555
server=/dola.com/127.0.0.1#5554
server=/dola.com/127.0.0.1#5555
server=/download.teamviewer.com/127.0.0.1#5554
server=/download.teamviewer.com/127.0.0.1#5555
server=/download.todesktop.com/127.0.0.1#5554
server=/download.todesktop.com/127.0.0.1#5555
server=/dr.miromind.ai/127.0.0.1#5554
server=/dr.miromind.ai/127.0.0.1#5555
server=/dtm8.dinamicagenerale.com/127.0.0.1#5554
server=/dtm8.dinamicagenerale.com/127.0.0.1#5555
server=/dyson.com/127.0.0.1#5554
server=/dyson.com/127.0.0.1#5555
server=/dyson.de/127.0.0.1#5554
server=/dyson.de/127.0.0.1#5555
server=/dyson.se/127.0.0.1#5554
server=/dyson.se/127.0.0.1#5555
server=/ecosia.org/127.0.0.1#5554
server=/ecosia.org/127.0.0.1#5555
server=/ecs.office.com/127.0.0.1#5554
server=/ecs.office.com/127.0.0.1#5555
server=/edgeservices.bing.com/127.0.0.1#5554
server=/edgeservices.bing.com/127.0.0.1#5555
server=/efsanetv.xyz/127.0.0.1#5554
server=/efsanetv.xyz/127.0.0.1#5555
server=/elevenlabs.io/127.0.0.1#5554
server=/elevenlabs.io/127.0.0.1#5555
server=/elevenmusic.io/127.0.0.1#5554
server=/elevenmusic.io/127.0.0.1#5555
server=/elevenreader.io/127.0.0.1#5554
server=/elevenreader.io/127.0.0.1#5555
server=/elgato.com/127.0.0.1#5554
server=/elgato.com/127.0.0.1#5555
server=/elmastvnet.xyz/127.0.0.1#5554
server=/elmastvnet.xyz/127.0.0.1#5555
server=/eneba.com/127.0.0.1#5554
server=/eneba.com/127.0.0.1#5555
server=/enscape3d.com/127.0.0.1#5554
server=/enscape3d.com/127.0.0.1#5555
server=/etsy.com/127.0.0.1#5554
server=/etsy.com/127.0.0.1#5555
server=/eu.posthog.com/127.0.0.1#5554
server=/eu.posthog.com/127.0.0.1#5555
server=/euro.com.pl/127.0.0.1#5554
server=/euro.com.pl/127.0.0.1#5555
server=/evike.com/127.0.0.1#5554
server=/evike.com/127.0.0.1#5555
server=/eyyo.xyz/127.0.0.1#5554
server=/eyyo.xyz/127.0.0.1#5555
server=/f00.esfr.pl/127.0.0.1#5554
server=/f00.esfr.pl/127.0.0.1#5555
server=/files-s2pb.pbsync.com/127.0.0.1#5554
server=/files-s2pb.pbsync.com/127.0.0.1#5555
server=/files.manuscdn.com/127.0.0.1#5554
server=/files.manuscdn.com/127.0.0.1#5555
server=/fitbit-pa.googleapis.com/127.0.0.1#5554
server=/fitbit-pa.googleapis.com/127.0.0.1#5555
server=/fitbit.google.com/127.0.0.1#5554
server=/fitbit.google.com/127.0.0.1#5555
server=/fitbitvestibuleshim-pa.googleapis.com/127.0.0.1#5554
server=/fitbitvestibuleshim-pa.googleapis.com/127.0.0.1#5555
server=/flow.google/127.0.0.1#5554
server=/flow.google/127.0.0.1#5555
server=/flow.google.com/127.0.0.1#5554
server=/flow.google.com/127.0.0.1#5555
server=/flowmusic.app/127.0.0.1#5554
server=/flowmusic.app/127.0.0.1#5555
server=/fmhy.net/127.0.0.1#5554
server=/fmhy.net/127.0.0.1#5555
server=/formula1.com/127.0.0.1#5554
server=/formula1.com/127.0.0.1#5555
server=/framer.com/127.0.0.1#5554
server=/framer.com/127.0.0.1#5555
server=/freakhosting.com/127.0.0.1#5554
server=/freakhosting.com/127.0.0.1#5555
server=/g2a.com/127.0.0.1#5554
server=/g2a.com/127.0.0.1#5555
server=/game8.co/127.0.0.1#5554
server=/game8.co/127.0.0.1#5555
server=/game8.co.jp/127.0.0.1#5554
server=/game8.co.jp/127.0.0.1#5555
server=/game8.jp/127.0.0.1#5554
server=/game8.jp/127.0.0.1#5555
server=/gamestop.com/127.0.0.1#5554
server=/gamestop.com/127.0.0.1#5555
server=/geller-pa.googleapis.com/127.0.0.1#5554
server=/geller-pa.googleapis.com/127.0.0.1#5555
server=/gemini.google/127.0.0.1#5554
server=/gemini.google/127.0.0.1#5555
server=/gemini.google.com/127.0.0.1#5554
server=/gemini.google.com/127.0.0.1#5555
server=/geminiweb-pa.clients.google.com/127.0.0.1#5554
server=/geminiweb-pa.clients.google.com/127.0.0.1#5555
server=/geminiweb-pa.clients6.google.com/127.0.0.1#5554
server=/geminiweb-pa.clients6.google.com/127.0.0.1#5555
server=/generativeai.google/127.0.0.1#5554
server=/generativeai.google/127.0.0.1#5555
server=/generativelanguage.googleapis.com/127.0.0.1#5554
server=/generativelanguage.googleapis.com/127.0.0.1#5555
server=/genspark.ai/127.0.0.1#5554
server=/genspark.ai/127.0.0.1#5555
server=/geolocation.onetrust.com/127.0.0.1#5554
server=/geolocation.onetrust.com/127.0.0.1#5555
server=/gql.twitch.tv/127.0.0.1#5554
server=/gql.twitch.tv/127.0.0.1#5555
server=/grok.com/127.0.0.1#5554
server=/grok.com/127.0.0.1#5555
server=/grok.x.com/127.0.0.1#5554
server=/grok.x.com/127.0.0.1#5555
server=/gssv-play-prod.xboxlive.com/127.0.0.1#5554
server=/gssv-play-prod.xboxlive.com/127.0.0.1#5555
server=/guidedhacking.com/127.0.0.1#5554
server=/guidedhacking.com/127.0.0.1#5555
server=/guilded.gg/127.0.0.1#5554
server=/guilded.gg/127.0.0.1#5555
server=/hapi.hentaicdn.org/127.0.0.1#5554
server=/hapi.hentaicdn.org/127.0.0.1#5555
server=/hume.ai/127.0.0.1#5554
server=/hume.ai/127.0.0.1#5555
server=/ikea.com/127.0.0.1#5554
server=/ikea.com/127.0.0.1#5555
server=/images.contentstack.io/127.0.0.1#5554
server=/images.contentstack.io/127.0.0.1#5555
server=/img.modivo.cloud/127.0.0.1#5554
server=/img.modivo.cloud/127.0.0.1#5555
server=/inceptionlabs.ai/127.0.0.1#5554
server=/inceptionlabs.ai/127.0.0.1#5555
server=/indeed.com/127.0.0.1#5554
server=/indeed.com/127.0.0.1#5555
server=/intel.com/127.0.0.1#5554
server=/intel.com/127.0.0.1#5555
server=/intel.de/127.0.0.1#5554
server=/intel.de/127.0.0.1#5555
server=/intel.se/127.0.0.1#5554
server=/intel.se/127.0.0.1#5555
server=/iperf3serverlist.net/127.0.0.1#5554
server=/iperf3serverlist.net/127.0.0.1#5555
server=/jetbrains.com/127.0.0.1#5554
server=/jetbrains.com/127.0.0.1#5555
server=/jetbrains.space/127.0.0.1#5554
server=/jetbrains.space/127.0.0.1#5555
server=/jules.google/127.0.0.1#5554
server=/jules.google/127.0.0.1#5555
server=/jules.google.com/127.0.0.1#5554
server=/jules.google.com/127.0.0.1#5555
server=/kaleido.ai/127.0.0.1#5554
server=/kaleido.ai/127.0.0.1#5555
server=/knowledge.broadcom.com/127.0.0.1#5554
server=/knowledge.broadcom.com/127.0.0.1#5555
server=/labs.google/127.0.0.1#5554
server=/labs.google/127.0.0.1#5555
server=/labs.google.com/127.0.0.1#5554
server=/labs.google.com/127.0.0.1#5555
server=/labstailwind.pa.googleapis.com/127.0.0.1#5554
server=/labstailwind.pa.googleapis.com/127.0.0.1#5555
server=/last.fm/127.0.0.1#5554
server=/last.fm/127.0.0.1#5555
server=/lego.com/127.0.0.1#5554
server=/lego.com/127.0.0.1#5555
server=/linear.app/127.0.0.1#5554
server=/linear.app/127.0.0.1#5555
server=/linguee.com/127.0.0.1#5554
server=/linguee.com/127.0.0.1#5555
server=/lookerstudio.google.com/127.0.0.1#5554
server=/lookerstudio.google.com/127.0.0.1#5555
server=/m3u.in/127.0.0.1#5554
server=/m3u.in/127.0.0.1#5555
server=/madmapper.com/127.0.0.1#5554
server=/madmapper.com/127.0.0.1#5555
server=/make.com/127.0.0.1#5554
server=/make.com/127.0.0.1#5555
server=/makersuite.google.com/127.0.0.1#5554
server=/makersuite.google.com/127.0.0.1#5555
server=/makita.ca/127.0.0.1#5554
server=/makita.ca/127.0.0.1#5555
server=/makita.cl/127.0.0.1#5554
server=/makita.cl/127.0.0.1#5555
server=/makita.co.nz/127.0.0.1#5554
server=/makita.co.nz/127.0.0.1#5555
server=/makita.com.au/127.0.0.1#5554
server=/makita.com.au/127.0.0.1#5555
server=/makita.com.kh/127.0.0.1#5554
server=/makita.com.kh/127.0.0.1#5555
server=/makita.com.tw/127.0.0.1#5554
server=/makita.com.tw/127.0.0.1#5555
server=/makita.sk/127.0.0.1#5554
server=/makita.sk/127.0.0.1#5555
server=/makita.ua/127.0.0.1#5554
server=/makita.ua/127.0.0.1#5555
server=/makitalatinamerica.com/127.0.0.1#5554
server=/makitalatinamerica.com/127.0.0.1#5555
server=/malwarebytes.com/127.0.0.1#5554
server=/malwarebytes.com/127.0.0.1#5555
server=/manus.im/127.0.0.1#5554
server=/manus.im/127.0.0.1#5555
server=/manybooks.net/127.0.0.1#5554
server=/manybooks.net/127.0.0.1#5555
server=/marketplace.cursorapi.com/127.0.0.1#5554
server=/marketplace.cursorapi.com/127.0.0.1#5555
server=/mediaexpert.pl/127.0.0.1#5554
server=/mediaexpert.pl/127.0.0.1#5555
server=/mediamarkt.pl/127.0.0.1#5554
server=/mediamarkt.pl/127.0.0.1#5555
server=/meta.ai/127.0.0.1#5554
server=/meta.ai/127.0.0.1#5555
server=/microcenter.com/127.0.0.1#5554
server=/microcenter.com/127.0.0.1#5555
server=/microchip.com/127.0.0.1#5554
server=/microchip.com/127.0.0.1#5555
server=/minicircuits.com/127.0.0.1#5554
server=/minicircuits.com/127.0.0.1#5555
server=/miro.com/127.0.0.1#5554
server=/miro.com/127.0.0.1#5555
server=/misterfpga.org/127.0.0.1#5554
server=/misterfpga.org/127.0.0.1#5555
server=/modivo.pl/127.0.0.1#5554
server=/modivo.pl/127.0.0.1#5555
server=/mongodb.com/127.0.0.1#5554
server=/mongodb.com/127.0.0.1#5555
server=/monica.im/127.0.0.1#5554
server=/monica.im/127.0.0.1#5555
server=/mouser.com/127.0.0.1#5554
server=/mouser.com/127.0.0.1#5555
server=/myjetbrains.com/127.0.0.1#5554
server=/myjetbrains.com/127.0.0.1#5555
server=/n8n.cloud/127.0.0.1#5554
server=/n8n.cloud/127.0.0.1#5555
server=/naukimg.com/127.0.0.1#5554
server=/naukimg.com/127.0.0.1#5555
server=/naukri.com/127.0.0.1#5554
server=/naukri.com/127.0.0.1#5555
server=/ndi.tv/127.0.0.1#5554
server=/ndi.tv/127.0.0.1#5555
server=/ndi.video/127.0.0.1#5554
server=/ndi.video/127.0.0.1#5555
server=/netapp.com/127.0.0.1#5554
server=/netapp.com/127.0.0.1#5555
server=/ngc.nvidia.com/127.0.0.1#5554
server=/ngc.nvidia.com/127.0.0.1#5555
server=/notebook-pa.googleapis.com/127.0.0.1#5554
server=/notebook-pa.googleapis.com/127.0.0.1#5555
server=/notebook.google/127.0.0.1#5554
server=/notebook.google/127.0.0.1#5555
server=/notebook.google.com/127.0.0.1#5554
server=/notebook.google.com/127.0.0.1#5555
server=/notebooklm-pa.googleapis.com/127.0.0.1#5554
server=/notebooklm-pa.googleapis.com/127.0.0.1#5555
server=/notebooklm.google/127.0.0.1#5554
server=/notebooklm.google/127.0.0.1#5555
server=/notebooklm.google.com/127.0.0.1#5554
server=/notebooklm.google.com/127.0.0.1#5555
server=/notion.com/127.0.0.1#5554
server=/notion.com/127.0.0.1#5555
server=/notion.so/127.0.0.1#5554
server=/notion.so/127.0.0.1#5555
server=/o.pki.goog/127.0.0.1#5554
server=/o.pki.goog/127.0.0.1#5555
server=/oaistatic.com/127.0.0.1#5554
server=/oaistatic.com/127.0.0.1#5555
server=/oaiusercontent.com/127.0.0.1#5554
server=/oaiusercontent.com/127.0.0.1#5555
server=/octanorm.com/127.0.0.1#5554
server=/octanorm.com/127.0.0.1#5555
server=/octanorm.expo.shop/127.0.0.1#5554
server=/octanorm.expo.shop/127.0.0.1#5555
server=/old.yummyani.me/127.0.0.1#5554
server=/old.yummyani.me/127.0.0.1#5555
server=/opal.google/127.0.0.1#5554
server=/opal.google/127.0.0.1#5555
server=/opal.google.com/127.0.0.1#5554
server=/opal.google.com/127.0.0.1#5555
server=/opal.withgoogle.com/127.0.0.1#5554
server=/opal.withgoogle.com/127.0.0.1#5555
server=/openai.com/127.0.0.1#5554
server=/openai.com/127.0.0.1#5555
server=/opencode.ai/127.0.0.1#5554
server=/opencode.ai/127.0.0.1#5555
server=/openrouter.ai/127.0.0.1#5554
server=/openrouter.ai/127.0.0.1#5555
server=/oracle.com/127.0.0.1#5554
server=/oracle.com/127.0.0.1#5555
server=/padi.com/127.0.0.1#5554
server=/padi.com/127.0.0.1#5555
server=/pandasecurity.com/127.0.0.1#5554
server=/pandasecurity.com/127.0.0.1#5555
server=/panic.com/127.0.0.1#5554
server=/panic.com/127.0.0.1#5555
server=/pcmag.com/127.0.0.1#5554
server=/pcmag.com/127.0.0.1#5555
server=/people-pa.clients6.google.com/127.0.0.1#5554
server=/people-pa.clients6.google.com/127.0.0.1#5555
server=/pi.ai/127.0.0.1#5554
server=/pi.ai/127.0.0.1#5555
server=/platform.parallel.ai/127.0.0.1#5554
server=/platform.parallel.ai/127.0.0.1#5555
server=/play.date/127.0.0.1#5554
server=/play.date/127.0.0.1#5555
server=/playground.google/127.0.0.1#5554
server=/playground.google/127.0.0.1#5555
server=/powertoolsuk.co.uk/127.0.0.1#5554
server=/powertoolsuk.co.uk/127.0.0.1#5555
server=/ppkas.com/127.0.0.1#5554
server=/ppkas.com/127.0.0.1#5555
server=/pr0gramm.com/127.0.0.1#5554
server=/pr0gramm.com/127.0.0.1#5555
server=/proactivebackend-pa.googleapis.com/127.0.0.1#5554
server=/proactivebackend-pa.googleapis.com/127.0.0.1#5555
server=/profile.broadcom.com/127.0.0.1#5554
server=/profile.broadcom.com/127.0.0.1#5555
server=/promods.net/127.0.0.1#5554
server=/promods.net/127.0.0.1#5555
server=/prowlarr.servarr.com/127.0.0.1#5554
server=/prowlarr.servarr.com/127.0.0.1#5555
server=/pump.fun/127.0.0.1#5554
server=/pump.fun/127.0.0.1#5555
server=/qoder.com/127.0.0.1#5554
server=/qoder.com/127.0.0.1#5555
server=/qualtrics.com/127.0.0.1#5554
server=/qualtrics.com/127.0.0.1#5555
server=/qwant.com/127.0.0.1#5554
server=/qwant.com/127.0.0.1#5555
server=/remove.bg/127.0.0.1#5554
server=/remove.bg/127.0.0.1#5555
server=/repo42.cursor.sh/127.0.0.1#5554
server=/repo42.cursor.sh/127.0.0.1#5555
server=/res.cloudinary.com/127.0.0.1#5554
server=/res.cloudinary.com/127.0.0.1#5555
server=/reve.art/127.0.0.1#5554
server=/reve.art/127.0.0.1#5555
server=/reve.com/127.0.0.1#5554
server=/reve.com/127.0.0.1#5555
server=/rewards.bing.com/127.0.0.1#5554
server=/rewards.bing.com/127.0.0.1#5555
server=/robinfrontend-pa.googleapis.com/127.0.0.1#5554
server=/robinfrontend-pa.googleapis.com/127.0.0.1#5555
server=/romsgames.net/127.0.0.1#5554
server=/romsgames.net/127.0.0.1#5555
server=/scdn.co/127.0.0.1#5554
server=/scdn.co/127.0.0.1#5555
server=/scribd.com/127.0.0.1#5554
server=/scribd.com/127.0.0.1#5555
server=/scribdassets.com/127.0.0.1#5554
server=/scribdassets.com/127.0.0.1#5555
server=/se.com/127.0.0.1#5554
server=/se.com/127.0.0.1#5555
server=/securitytrails.com/127.0.0.1#5554
server=/securitytrails.com/127.0.0.1#5555
server=/signaler-pa.clients6.google.com/127.0.0.1#5554
server=/signaler-pa.clients6.google.com/127.0.0.1#5555
server=/singlekey-id.com/127.0.0.1#5554
server=/singlekey-id.com/127.0.0.1#5555
server=/sketchup.com/127.0.0.1#5554
server=/sketchup.com/127.0.0.1#5555
server=/slack-core.com/127.0.0.1#5554
server=/slack-core.com/127.0.0.1#5555
server=/slack-edge.com/127.0.0.1#5554
server=/slack-edge.com/127.0.0.1#5555
server=/slack.com/127.0.0.1#5554
server=/slack.com/127.0.0.1#5555
server=/slackb.com/127.0.0.1#5554
server=/slackb.com/127.0.0.1#5555
server=/spotify.com/127.0.0.1#5554
server=/spotify.com/127.0.0.1#5555
server=/spotify.dev/127.0.0.1#5554
server=/spotify.dev/127.0.0.1#5555
server=/squareup.com/127.0.0.1#5554
server=/squareup.com/127.0.0.1#5555
server=/stitch.withgoogle.com/127.0.0.1#5554
server=/stitch.withgoogle.com/127.0.0.1#5555
server=/strava.com/127.0.0.1#5554
server=/strava.com/127.0.0.1#5555
server=/superpharm.eu/127.0.0.1#5554
server=/superpharm.eu/127.0.0.1#5555
server=/superpharm.pl/127.0.0.1#5554
server=/superpharm.pl/127.0.0.1#5555
server=/support.broadcom.com/127.0.0.1#5554
server=/support.broadcom.com/127.0.0.1#5555
server=/sydney.bing.com/127.0.0.1#5554
server=/sydney.bing.com/127.0.0.1#5555
server=/tableau.com/127.0.0.1#5554
server=/tableau.com/127.0.0.1#5555
server=/ti.com/127.0.0.1#5554
server=/ti.com/127.0.0.1#5555
server=/titlestorage.xboxlive.com/127.0.0.1#5554
server=/titlestorage.xboxlive.com/127.0.0.1#5555
server=/tokenharbor.ai/127.0.0.1#5554
server=/tokenharbor.ai/127.0.0.1#5555
server=/trae-api-sg.mchost.guru/127.0.0.1#5554
server=/trae-api-sg.mchost.guru/127.0.0.1#5555
server=/tria.ge/127.0.0.1#5554
server=/tria.ge/127.0.0.1#5555
server=/trimble.com/127.0.0.1#5554
server=/trimble.com/127.0.0.1#5555
server=/trueachievements.com/127.0.0.1#5554
server=/trueachievements.com/127.0.0.1#5555
server=/truthsocial.com/127.0.0.1#5554
server=/truthsocial.com/127.0.0.1#5555
server=/tuta.com/127.0.0.1#5554
server=/tuta.com/127.0.0.1#5555
server=/uainvest.com.ua/127.0.0.1#5554
server=/uainvest.com.ua/127.0.0.1#5555
server=/ultimaker.com/127.0.0.1#5554
server=/ultimaker.com/127.0.0.1#5555
server=/unscreen.com/127.0.0.1#5554
server=/unscreen.com/127.0.0.1#5555
server=/us-asia.gcpp.cursor.sh/127.0.0.1#5554
server=/us-asia.gcpp.cursor.sh/127.0.0.1#5555
server=/us-eu.gcpp.cursor.sh/127.0.0.1#5554
server=/us-eu.gcpp.cursor.sh/127.0.0.1#5555
server=/us-only.gcpp.cursor.sh/127.0.0.1#5554
server=/us-only.gcpp.cursor.sh/127.0.0.1#5555
server=/users.wix.com/127.0.0.1#5554
server=/users.wix.com/127.0.0.1#5555
server=/usher.ttvnw.net/127.0.0.1#5554
server=/usher.ttvnw.net/127.0.0.1#5555
server=/vipvera.com/127.0.0.1#5554
server=/vipvera.com/127.0.0.1#5555
server=/w-x.co/127.0.0.1#5554
server=/w-x.co/127.0.0.1#5555
server=/waa-pa.clients6.google.com/127.0.0.1#5554
server=/waa-pa.clients6.google.com/127.0.0.1#5555
server=/wbagora.com/127.0.0.1#5554
server=/wbagora.com/127.0.0.1#5555
server=/wbgames.com/127.0.0.1#5554
server=/wbgames.com/127.0.0.1#5555
server=/weather.com/127.0.0.1#5554
server=/weather.com/127.0.0.1#5555
server=/web.archive.org/127.0.0.1#5554
server=/web.archive.org/127.0.0.1#5555
server=/webchannel-alkalimakersuite-pa.clients6.google.com/127.0.0.1#5554
server=/webchannel-alkalimakersuite-pa.clients6.google.com/127.0.0.1#5555
server=/weborama.nl/127.0.0.1#5554
server=/weborama.nl/127.0.0.1#5555
server=/whimsical.com/127.0.0.1#5554
server=/whimsical.com/127.0.0.1#5555
server=/windguru.cz/127.0.0.1#5554
server=/windguru.cz/127.0.0.1#5555
server=/windsurf.com/127.0.0.1#5554
server=/windsurf.com/127.0.0.1#5555
server=/wise.com/127.0.0.1#5554
server=/wise.com/127.0.0.1#5555
server=/ws.audioscrobbler.com/127.0.0.1#5554
server=/ws.audioscrobbler.com/127.0.0.1#5555
server=/wund.com/127.0.0.1#5554
server=/wund.com/127.0.0.1#5555
server=/wunderground.com/127.0.0.1#5554
server=/wunderground.com/127.0.0.1#5555
server=/wxug.com/127.0.0.1#5554
server=/wxug.com/127.0.0.1#5555
server=/x.ai/127.0.0.1#5554
server=/x.ai/127.0.0.1#5555
server=/xboxdesignlab.xbox.com/127.0.0.1#5554
server=/xboxdesignlab.xbox.com/127.0.0.1#5555
server=/xerox.com/127.0.0.1#5554
server=/xerox.com/127.0.0.1#5555
server=/xiaomi.eu/127.0.0.1#5554
server=/xiaomi.eu/127.0.0.1#5555
server=/yeggi.com/127.0.0.1#5554
server=/yeggi.com/127.0.0.1#5555
server=/yupp.ai/127.0.0.1#5554
server=/yupp.ai/127.0.0.1#5555
server=/zapier-deployment.com/127.0.0.1#5554
server=/zapier-deployment.com/127.0.0.1#5555
server=/zapier.com/127.0.0.1#5554
server=/zapier.com/127.0.0.1#5555
EOF

    echo -e "${GREEN}>>> Настраиваю параметры dnsmasq в файле конфигурации dhcp...${NC}"
    # Очищаем старую конфигурацию dnsmasq (первую секцию), чтобы записать актуальные параметры
    uci -q delete dhcp.@dnsmasq[0]
    uci add dhcp dnsmasq
    uci set dhcp.@dnsmasq[0].domainneeded='1'
    uci set dhcp.@dnsmasq[0].localise_queries='1'
    uci set dhcp.@dnsmasq[0].rebind_protection='1'
    uci set dhcp.@dnsmasq[0].local='/lan/'
    uci set dhcp.@dnsmasq[0].domain='lan'
    uci set dhcp.@dnsmasq[0].expandhosts='1'
    uci set dhcp.@dnsmasq[0].authoritative='1'
    uci set dhcp.@dnsmasq[0].readethers='1'
    uci set dhcp.@dnsmasq[0].leasefile='/tmp/dhcp.leases'
    uci set dhcp.@dnsmasq[0].localservice='1'
    uci set dhcp.@dnsmasq[0].ednspacket_max='1232'
    uci set dhcp.@dnsmasq[0].cachesize='1000'
    uci set dhcp.@dnsmasq[0].port='53'
    uci set dhcp.@dnsmasq[0].allservers='1'
    uci set dhcp.@dnsmasq[0].doh_backup_noresolv='1'
    uci add_list dhcp.@dnsmasq[0].doh_backup_server='127.0.0.1#5353'
    uci add_list dhcp.@dnsmasq[0].doh_server='127.0.0.1#5053'
    uci add_list dhcp.@dnsmasq[0].doh_server='127.0.0.1#5054'
    uci add_list dhcp.@dnsmasq[0].doh_server='127.0.0.1#5055'
    uci add_list dhcp.@dnsmasq[0].doh_server='127.0.0.1#5554'
    uci add_list dhcp.@dnsmasq[0].doh_server='127.0.0.1#5555'
    uci set dhcp.@dnsmasq[0].serversfile='/etc/dnsmasq.servers'
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5055'
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5053'
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5054'
    uci add_list dhcp.@dnsmasq[0].server='/.ru/77.88.8.1'
    uci add_list dhcp.@dnsmasq[0].server='/.ru/77.88.8.8'
    uci add_list dhcp.@dnsmasq[0].server='/.xn--p1ai/77.88.8.8'
    uci add_list dhcp.@dnsmasq[0].server='/.xn--p1ai/77.88.8.1'
    uci commit dhcp

    /etc/init.d/https-dns-proxy enable 2>/dev/null
    /etc/init.d/https-dns-proxy restart 2>/dev/null
    /etc/init.d/dnsmasq restart
    echo -e "${GREEN}>>> Конфигурация https-dns-proxy и dnsmasq успешно применена${NC}"
}
