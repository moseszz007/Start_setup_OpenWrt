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
    DNSPROXY_URL="https://fantastic-packages.github.io/releases/25.12/packages/aarch64_cortex-a53/luci/luci-app-dnsproxy-26.250.33416~c43835f.apk"
    DNSPROXY_FILE="/tmp/luci-app-dnsproxy.apk"
else
    DNSPROXY_URL="https://fantastic-packages.github.io/releases/archive/24.10/packages/aarch64_generic/luci/luci-app-dnsproxy_26.250.33416~c43835f_all.ipk"
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
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$DNSPROXY_NUM" "luci-app-dnsproxy" "DNS Proxy с готовым конфигом"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$CFG_DNSPROXY_NUM" "Конфиг dnsproxy (только)" "Применить готовый конфиг DNS Proxy"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$ZAPRET_NUM" "Zapret Manager" "Управление обходом блокировок"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$SPLIFY_NUM" "Splify2" "Инструмент маршрутизации трафика"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$INETDET_NUM" "Internet Detector" "Детектор подключения с русификатором"
printf " ${YELLOW}%2d${NC}) %-28s — %s\n" "$THEME_NUM" "LuCI Theme Footstrap" "Установка современной темы оформления"

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
    echo -e "${GREEN}>>> Устанавливаю Internet Detector...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi

    if [ "$RELEASE" = "25.12" ] || [ "$PKG_MGR" = "apk" ]; then
        wget --no-check-certificate -O /tmp/internet-detector.apk https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/internet-detector-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/internet-detector.apk
        rm -f /tmp/internet-detector.apk

        service internet-detector start
        service internet-detector enable

        wget --no-check-certificate -O /tmp/luci-app-internet-detector.apk https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/luci-app-internet-detector-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/luci-app-internet-detector.apk
        rm -f /tmp/luci-app-internet-detector.apk

        service rpcd restart

        wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru.apk https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/luci-i18n-internet-detector-ru-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/luci-i18n-internet-detector-ru.apk
        rm -f /tmp/luci-i18n-internet-detector-ru.apk
    else
        wget --no-check-certificate -O /tmp/internet-detector.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/internet-detector_1.7.4-r1_all.ipk
        opkg install /tmp/internet-detector.ipk
        rm -f /tmp/internet-detector.ipk

        service internet-detector start
        service internet-detector enable

        wget --no-check-certificate -O /tmp/luci-app-internet-detector.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/luci-app-internet-detector_1.7.4-r1_all.ipk
        opkg install /tmp/luci-app-internet-detector.ipk
        rm -f /tmp/luci-app-internet-detector.ipk

        service rpcd restart

        wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/luci-i18n-internet-detector-ru_1.7.4-r1_all.ipk
        opkg install /tmp/luci-i18n-internet-detector-ru.ipk
        rm -f /tmp/luci-i18n-internet-detector-ru.ipk
    fi
    echo -e "${GREEN}>>> Internet Detector установлен${NC}"
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
    echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        install_pkg "$pkg"
    done
    install_dnsproxy
    install_zapret
    install_splify
    install_internet_detector
    install_theme
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
        if [ "$num" -eq "$INETDET_NUM" ]; then
            install_internet_detector
            continue
        fi
        if [ "$num" -eq "$THEME_NUM" ]; then
            install_theme
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
