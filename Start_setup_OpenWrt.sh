#!/bin/sh

# ============================================
# Установщик пакетов OpenWrt
# + dnsproxy + Zapret + Splify2 + Internet Detector + Footstrap Theme + IPv6 Disabler
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo -e "${BLUE}Пакетный менеджер: ${GREEN}$PKG_MGR${NC}"
echo -e "${BLUE}Версия OpenWrt:    ${GREEN}$RELEASE${NC}"
echo ""

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
    DNSPROXY_URL="https://fantastic-packages.github.io/releases/25.12/packages/aarch64_cortex-a53/luci/luci-app-dnsproxy-26.250.33416~c43835f.apk"
    DNSPROXY_FILE="/tmp/luci-app-dnsproxy.apk"
else
    DNSPROXY_URL="https://fantastic-packages.github.io/releases/24.10/packages/aarch64_cortex-a53/luci/luci-app-dnsproxy_26.250.33416~c43835f_all.ipk"
    DNSPROXY_FILE="/tmp/luci-app-dnsproxy.ipk"
fi

clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Установщик пакетов OpenWrt${NC}"
echo -e "${BLUE}$PKG_MGR | $RELEASE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Автоматический подсчет номеров пунктов меню
TOTAL_PACKAGES_COUNT=0
for pkg in $(echo "$PACKAGES" | awk -F'|' 'NF>1 {print $1}'); do
    TOTAL_PACKAGES_COUNT=$((TOTAL_PACKAGES_COUNT + 1))
done

DNSPROXY_NUM=$((TOTAL_PACKAGES_COUNT + 1))
ZAPRET_NUM=$((TOTAL_PACKAGES_COUNT + 2))
SPLIFY_NUM=$((TOTAL_PACKAGES_COUNT + 3))
INETDET_NUM=$((TOTAL_PACKAGES_COUNT + 4))
THEME_NUM=$((TOTAL_PACKAGES_COUNT + 5))
IPV6_NUM=$((TOTAL_PACKAGES_COUNT + 6))

# Отрисовка меню
i=1
echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
    [ -z "$pkg" ] && continue
    printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$i" "$pkg" "$desc"
    i=$((i + 1))
done

printf "${YELLOW}\%2d${NC}) %-28s - %s\n" "$DNSPROXY_NUM" "$DNSPROXY_PKG_NAME" "LuCI DNS Proxy + автоконфиг"
printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$ZAPRET_NUM" "Zapret Manager" "Установка Zapret Manager (LuCI)"
printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$SPLIFY_NUM" "Splify2" "Установка Splify2"
printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$INETDET_NUM" "Internet Detector" "Детектор интернета + русская локаль"
printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$THEME_NUM" "LuCI Theme Footstrap" "Установка темы Footstrap"
printf "${YELLOW}%2d${NC}) \%-28s - \%s\n" "$IPV6_NUM" "Отключение IPv6" "Полное отключение IPv6 + фикс APK в LuCI"

echo ""
echo -e "${GREEN} 0${NC}) Установить ВСЕ"
echo -e "${RED} q${NC}) Выход"
echo ""

printf "Выбери номер (или несколько через пробел): "
read -r choice

case "$choice" in
    q|Q|exit) echo "Выход."; exit 0 ;;
esac

# ---------- Обновление ----------
echo ""
echo -e "${BLUE}>>> Обновление списка пакетов ($PKG_MGR)...${NC}"
$UPDATE_CMD || {
    echo -e "${RED}Ошибка обновления!${NC}"
    exit 1
}

# ---------- Функции ----------
install_pkg() {
    echo -e "${GREEN}>>> Устанавливаю: $1${NC}"
    $INSTALL_CMD "$1" \vert{}\vert{} echo -e "${RED}Не удалось установить $1${NC}"
}

install_dnsproxy() {
    echo -e "${GREEN}>>> Скачиваю luci-app-dnsproxy...${NC}"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$DNSPROXY_FILE" "$DNSPROXY_URL" || {
            echo -e "${RED}Не удалось скачать luci-app-dnsproxy${NC}"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$DNSPROXY_FILE" "$DNSPROXY_URL" || {
            echo -e "${RED}Не удалось скачать luci-app-dnsproxy${NC}"
            return 1
        }
    else
        echo -e "${RED}Нет wget и curl${NC}"
        return 1
    fi

    echo -e "${GREEN}>>> Устанавливаю luci-app-dnsproxy...${NC}"
    if [ "$PKG_MGR" = "apk" ]; then
        apk add $ALLOW_UNTRUSTED "$DNSPROXY_FILE" || echo -e "${RED}Ошибка установки luci-app-dnsproxy${NC}"
    else
        opkg install $ALLOW_UNTRUSTED "$DNSPROXY_FILE" || echo -e "${RED}Ошибка установки luci-app-dnsproxy${NC}"
    fi
    rm -f "$DNSPROXY_FILE"

    echo -e "${GREEN}>>> Записываю конфиг /etc/config/dnsproxy...${NC}"
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
	list bootstrap '9.9.9.9'
	list bootstrap '1.1.1.1'
