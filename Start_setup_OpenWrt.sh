#!/bin/sh

# ============================================
# Установщик пакетов OpenWrt
# + dnsproxy + Zapret + Splify2 + Internet Detector
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

# ---------- luci-app-dnsproxy ----------
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
echo -e "${BLUE}   Установщик пакетов OpenWrt${NC}"
echo -e "${BLUE}   $PKG_MGR | $RELEASE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

i=1
echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
    [ -z "$pkg" ] && continue
    printf "${YELLOW}%2d${NC}) %-28s - %s\n" "$i" "$pkg" "$desc"
    i=$((i + 1))
done

# dnsproxy
printf "${YELLOW}%2d${NC}) %-28s - %s\n" "$i" "$DNSPROXY_PKG_NAME" "LuCI DNS Proxy + автоконфиг"
DNSPROXY_NUM=$i
i=$((i + 1))

# Zapret Manager
printf "${YELLOW}%2d${NC}) %-28s - %s\n" "$i" "Zapret Manager" "Установка Zapret Manager (LuCI)"
ZAPRET_NUM=$i
i=$((i + 1))

# Splify2
printf "${YELLOW}%2d${NC}) %-28s - %s\n" "$i" "Splify2" "Установка Splify2"
SPLIFY_NUM=$i
i=$((i + 1))

# Internet Detector
printf "${YELLOW}%2d${NC}) %-28s - %s\n" "$i" "Internet Detector" "Детектор интернета + русская локаль"
INETDET_NUM=$i

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
    $INSTALL_CMD "$1" || echo -e "${RED}Не удалось установить $1${NC}"
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
	list upstream '[/openwrt.org/]1.1.1.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.8'
	list upstream '[/a-vrv.akamaized.net/abercrombie.com/adidas.com/adobe.com/ai-chat.bsg.brave.com/ai.com/aircanada.com/akc.org/alphacoders.com/alza.hu/amazfitwatchfaces.com/amplitude.com/analog.com/andrevi.ch/ansys.com/anthropic.com/api.jetbrains.ai/api.themoviedb.org/app.zerossl.com/arc.net/arduino.cc/assets.heroku.com/atlassian.com/att.com/augmentcode.com/autodesk.com/bell-sw.com/bestbuy.com/bitdefender.com/bitnami.com/blinkshot.io/bosch.com/boschaftermarket.com/boschautoparts.com/brawlstarsgame.com/broadcom.com/broncosportforum.com/btod.com/buanzo.org/buf.build/builds.parsec.app/buymeacoffee.com/canva.com/canva.dev/capacitorjs.com/carrefouruae.com/cats.com/cdn.web-platform.io/cdromance.org/cdw.com/chaos.com/chat.com/chat.openai.com.cdn.cloudflare.net/chatgpt.com/cisco.com/cisecurity.org/citrix.com/clamav.net/clashofclans.com/clashroyaleapp.com/claude.ai/clevelandclinic.org/clickup.com/clip.opus.pro/code.gist.build/codeium.com/coingate.com/community.sophos.com/connect.ngrok-agent.com/contabo.com/copilot.microsoft.com/corsair.com/cpu-monkey.com/credly.com/crunchyroll.com/cvedetails.com/daemon-tools.cc/data-cdn.mbamupdates.com/data.cline.bot/deepl.com/deezer.com/dell.com/dellcdn.com/designer.microsoft.com/developer.nvidia.com/devexpress.com/diabrowser.com/digitalcontent.sky/disctech.com/disneyplus.com/docs.liquibase.com/document360.com/document360.io/download3.omnissa.com/ducati.com/dyson.com/easydmarc.com/editorx.com/elevenlabs.io/eneba.com/etsy.com/exchanger.bits.media/expandrive.com/extremetech.com/f1.com/fast.com/filebin.net/files.manus.cdn/flir.com/flir.eu/flourish.studio/fluke.com/flukenetworks.com/flyertalk.com/footballapi.pulselive.com/force-user-content.com/force.com/formula1.com/forum.netgate.com/framer.com/freeimages.com/fxnetworks.com/g2a.com/gamestop.com/gaming.amazon.com/geforcenow.com/gemini.google.com/genspark.ai/geolocation.onetrust.com/getoutline.com/gfn.am/ghostrc.game.idtech.services/global.fncstatic.com/global.platform.seconddinnertech.com/glpals.com/gofundme.com/gpsonextra.net/gpu-monkey.com/gql.twitch.tv/grafana.com/graylog.org/grizzlysms.com/grok.com/groq.com/groupon.com/guilded.gg/habr.com/hashicorp.com/haydaygame.com/hbomax.com/hc-ping.com/hchk.io/healthline.com/herokucdn.com/hollisterco.com/home-connect.com/home.by.me/hostinger.com/hotels.com/housebrand.com/htmhell.dev/hume.ai/hybrid-analysis.com/ibm.com/iherb.com/ikea.com/image.tmdb.org/imgur.com/indeed.com/install.launcher.omniverse.nvidia.com/intel.com/intel.de/intel.nl/intelix.sophos.com/intuit.com/intuitibits.com/itninja.com/jamf.com/jetbrains.com/jetbrains.space/kaleido.ai/keysight.com/kinogo.la/klarna.com/kmail-lists.com/lambdalabs.com/langdock.com/ldoceonline.com/legalshield.com/lgeapi.com/lgthinq.com/lidarr.audio/lifehacker.com/lightning.ai/lookerstudio.google.com/mailerlite.com/mailinator.com/manus.im/manybooks.net/marvelsnap.com/mattermost.com/max.com/medicalnewstoday.com/metopera.org/middlewareinventory.com/mintmobile.com/miracleptr.wordpress.com/mixcloud.com/mongodb.com/monoprice.com/mouser.com/mouser.fi/mssg.me/myheritage.com/myjetbrains.com/myparallels.com/myqrcode.com/nba.com/neo4j.com/netacad.com/netapp.com/netflix.ca/netflix.com/netflix.net/netflixinvestor.com/netflixtechblog.com/netlify.com/new.abb.com/newark.com/news.google.com/newsroom.porsche.com/nfl.com/nflxext.com/nflximg.com/nflximg.net/nflxsearch.net/nflxso.net/nflxvideo.net/ngrok.com/nike.com/nitropdf.com/nordaccount.com/nordcdn.com/nordvpn.com/notion-emojis.s3-us-west-2.amazonaws.com/notion-static.com/notion.com/notion.new/notion.site/notion.so/ntp.msn.com/nxp.com/oaistatic.com/oaiusercontent.com/ocstore.com/omnissa.com/onfastspring.com/onshape.com/openai.com/openh264.org/openrouter.ai/oracle.com/paddle.com/paddlestatus.com/pandasecurity.com/parallels.cn/parallels.com/parallels.net/parallelsaccess.com/paritydeals.com/pcgamesn.com/pcmag.com/penguin.com/penguinrandomhouse.com/pexels.com/pingdom.com/pkgs.tailscale.com/platform.activestate.com/plugshare.com/posthog.com/premierleague.com/primevideo.com/proactivebackend-pa.googleapis.com/production-openaicom-storage.azureedge.net/profitwell.com/prowlarr.com/public.parsec.app/qt.io/qualcomm.com/quicknode.com/qwant.com/reactflow.dev/recraft.ai/redis.io/redislabs.com/remna.st/remove.bg/research.net/reve.art/salesforce-experience.com/salesforce-hub.com/salesforce-scrt.com/salesforce-setup.com/salesforce-sites.com/salesforce.com/salesforceiq.com/salesforceliveagent.com/sdxcentral.com/semrush.com/sentry.dev/sentry.io/sephora.com/servarr.com/sfdcopens.com/shinyhardware.co.uk/shop.gameloft.com/singlekey-id.com/site.com/siteground.com/sketchup.com/sky.com/skycdp.com/smartbear.co/smartbear.com/smartdeploy.com/snapgene.com/snort.org/snyk.io/solarwinds.com/sonara.ai/sora.com/spacelift.io/spiceworks.com/spitfireaudio.com/spotify.com/squadbustersgame.com/squareup.com/strava.com/suggestqueries.google.com/supercell.com/support.anydesk.com/support.xerox.com/surveymonkey.com/swagger.io/swapd.co/synoforum.com/tableau.com/talosintelligence.com/teamviewer.com/techbargains.com/telemetr.io/tempmail.plus/terraform.io/theaudiodb.com/themoviedb.org/ti.com/tidal.com/timberland.de/tmdb-image-prod.b-cdn.net/tmdb.com/tmdb.org/toolbox.app/torrenteditor.com/trae.ai/trailblazer.me/trailhead.com/transferwise.com/tria.ge/truthsocial.com/tsmc.com/tutanota.com/typing.com/uaudio.com/uizard.io/unscreen.com/upwork.com/usher.ttvnw.net/v.vrv.co/vagrantcloud.com/veeam.com/vmware.com/vod-fy.crunchyrollcdn.com/volkswagen-classic-parts.com/vyos.io/w.atwiki.jp/walmart.com/watchguard.com/watermarkremover.io/wbgames.com/weather.com/webnames.ca/weebly.com/widgetapp.stream/wikidot.com/windsurf.com/wise.com/wpengine.com/wunderground.com/www3.corsair.com/x.ai/xiaomi.eu/xsts.auth.xboxlive.com/xtracloud.net/yeggi.com/youtrack.cloud/zapier.com/zedge.net/]https://xbox-dns.ru/dns-query'
	list upstream '[/ru/xn--p1ai/]77.88.8.1'
	list upstream 'sdns://AQAAAAAAAAAADjIwOC42Ny4yMjAuMjIwILc1EUAgbyJdPivYItf9aR6hwzzI1maNDL4Ev6vKQ_t5GzIuZG5zY3J5cHQtY2VydC5vcGVuZG5zLmNvbQ'
	list upstream 'sdns://AQMAAAAAAAAADDkuOS45Ljk6ODQ0MyBnyEe4yHWM0SAkVUO-dWdG3zTfHYTAC4xHA2jfgh2GPhkyLmRuc2NyeXB0LWNlcnQucXVhZDkubmV0'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'https://8.8.8.8/dns-query'
	list upstream 'https://doh.opendns.com/dns-query'
	list upstream 'quic://dns.quad9.net:853'
	list upstream 'https://freedns.controld.com/p0'
	list upstream 'https://1.1.1.1/dns-query'
	list upstream 'tls://one.one.one.one'
	list upstream 'quic://p0.freedns.controld.com'
	list fallback '77.88.8.1'
	list fallback '77.88.8.8'

config dnsproxy 'tls'
	option enabled '0'
	option https_port '8443'
	option tls_port '853'
	option quic_port '853'

config profile 'default'
	option label 'KOKA'
	list bootstrap '9.9.9.9'
	list bootstrap '1.1.1.1'
	option upstream_mode 'parallel'
	list fallback '77.88.8.1'
	list fallback '77.88.8.8'
	list upstream '[/openwrt.org/]1.1.1.1'
	list upstream '[/ru/xn--p1ai/]77.88.8.8'
	list upstream '[/a-vrv.akamaized.net/abercrombie.com/adidas.com/adobe.com/ai-chat.bsg.brave.com/ai.com/aircanada.com/akc.org/alphacoders.com/alza.hu/amazfitwatchfaces.com/amplitude.com/analog.com/andrevi.ch/ansys.com/anthropic.com/api.jetbrains.ai/api.themoviedb.org/app.zerossl.com/arc.net/arduino.cc/assets.heroku.com/atlassian.com/att.com/augmentcode.com/autodesk.com/bell-sw.com/bestbuy.com/bitdefender.com/bitnami.com/blinkshot.io/bosch.com/boschaftermarket.com/boschautoparts.com/brawlstarsgame.com/broadcom.com/broncosportforum.com/btod.com/buanzo.org/buf.build/builds.parsec.app/buymeacoffee.com/canva.com/canva.dev/capacitorjs.com/carrefouruae.com/cats.com/cdn.web-platform.io/cdromance.org/cdw.com/chaos.com/chat.com/chat.openai.com.cdn.cloudflare.net/chatgpt.com/cisco.com/cisecurity.org/citrix.com/clamav.net/clashofclans.com/clashroyaleapp.com/claude.ai/clevelandclinic.org/clickup.com/clip.opus.pro/code.gist.build/codeium.com/coingate.com/community.sophos.com/connect.ngrok-agent.com/contabo.com/copilot.microsoft.com/corsair.com/cpu-monkey.com/credly.com/crunchyroll.com/cvedetails.com/daemon-tools.cc/data-cdn.mbamupdates.com/data.cline.bot/deepl.com/deezer.com/dell.com/dellcdn.com/designer.microsoft.com/developer.nvidia.com/devexpress.com/diabrowser.com/digitalcontent.sky/disctech.com/disneyplus.com/docs.liquibase.com/document360.com/document360.io/download3.omnissa.com/ducati.com/dyson.com/easydmarc.com/editorx.com/elevenlabs.io/eneba.com/etsy.com/exchanger.bits.media/expandrive.com/extremetech.com/f1.com/fast.com/filebin.net/files.manus.cdn/flir.com/flir.eu/flourish.studio/fluke.com/flukenetworks.com/flyertalk.com/footballapi.pulselive.com/force-user-content.com/force.com/formula1.com/forum.netgate.com/framer.com/freeimages.com/fxnetworks.com/g2a.com/gamestop.com/gaming.amazon.com/geforcenow.com/gemini.google.com/genspark.ai/geolocation.onetrust.com/getoutline.com/gfn.am/ghostrc.game.idtech.services/global.fncstatic.com/global.platform.seconddinnertech.com/glpals.com/gofundme.com/gpsonextra.net/gpu-monkey.com/gql.twitch.tv/grafana.com/graylog.org/grizzlysms.com/grok.com/groq.com/groupon.com/guilded.gg/habr.com/hashicorp.com/haydaygame.com/hbomax.com/hc-ping.com/hchk.io/healthline.com/herokucdn.com/hollisterco.com/home-connect.com/home.by.me/hostinger.com/hotels.com/housebrand.com/htmhell.dev/hume.ai/hybrid-analysis.com/ibm.com/iherb.com/ikea.com/image.tmdb.org/imgur.com/indeed.com/install.launcher.omniverse.nvidia.com/intel.com/intel.de/intel.nl/intelix.sophos.com/intuit.com/intuitibits.com/itninja.com/jamf.com/jetbrains.com/jetbrains.space/kaleido.ai/keysight.com/kinogo.la/klarna.com/kmail-lists.com/lambdalabs.com/langdock.com/ldoceonline.com/legalshield.com/lgeapi.com/lgthinq.com/lidarr.audio/lifehacker.com/lightning.ai/lookerstudio.google.com/mailerlite.com/mailinator.com/manus.im/manybooks.net/marvelsnap.com/mattermost.com/max.com/medicalnewstoday.com/metopera.org/middlewareinventory.com/mintmobile.com/miracleptr.wordpress.com/mixcloud.com/mongodb.com/monoprice.com/mouser.com/mouser.fi/mssg.me/myheritage.com/myjetbrains.com/myparallels.com/myqrcode.com/nba.com/neo4j.com/netacad.com/netapp.com/netflix.ca/netflix.com/netflix.net/netflixinvestor.com/netflixtechblog.com/netlify.com/new.abb.com/newark.com/news.google.com/newsroom.porsche.com/nfl.com/nflxext.com/nflximg.com/nflximg.net/nflxsearch.net/nflxso.net/nflxvideo.net/ngrok.com/nike.com/nitropdf.com/nordaccount.com/nordcdn.com/nordvpn.com/notion-emojis.s3-us-west-2.amazonaws.com/notion-static.com/notion.com/notion.new/notion.site/notion.so/ntp.msn.com/nxp.com/oaistatic.com/oaiusercontent.com/ocstore.com/omnissa.com/onfastspring.com/onshape.com/openai.com/openh264.org/openrouter.ai/oracle.com/paddle.com/paddlestatus.com/pandasecurity.com/parallels.cn/parallels.com/parallels.net/parallelsaccess.com/paritydeals.com/pcgamesn.com/pcmag.com/penguin.com/penguinrandomhouse.com/pexels.com/pingdom.com/pkgs.tailscale.com/platform.activestate.com/plugshare.com/posthog.com/premierleague.com/primevideo.com/proactivebackend-pa.googleapis.com/production-openaicom-storage.azureedge.net/profitwell.com/prowlarr.com/public.parsec.app/qt.io/qualcomm.com/quicknode.com/qwant.com/reactflow.dev/recraft.ai/redis.io/redislabs.com/remna.st/remove.bg/research.net/reve.art/salesforce-experience.com/salesforce-hub.com/salesforce-scrt.com/salesforce-setup.com/salesforce-sites.com/salesforce.com/salesforceiq.com/salesforceliveagent.com/sdxcentral.com/semrush.com/sentry.dev/sentry.io/sephora.com/servarr.com/sfdcopens.com/shinyhardware.co.uk/shop.gameloft.com/singlekey-id.com/site.com/siteground.com/sketchup.com/sky.com/skycdp.com/smartbear.co/smartbear.com/smartdeploy.com/snapgene.com/snort.org/snyk.io/solarwinds.com/sonara.ai/sora.com/spacelift.io/spiceworks.com/spitfireaudio.com/spotify.com/squadbustersgame.com/squareup.com/strava.com/suggestqueries.google.com/supercell.com/support.anydesk.com/support.xerox.com/surveymonkey.com/swagger.io/swapd.co/synoforum.com/tableau.com/talosintelligence.com/teamviewer.com/techbargains.com/telemetr.io/tempmail.plus/terraform.io/theaudiodb.com/themoviedb.org/ti.com/tidal.com/timberland.de/tmdb-image-prod.b-cdn.net/tmdb.com/tmdb.org/toolbox.app/torrenteditor.com/trae.ai/trailblazer.me/trailhead.com/transferwise.com/tria.ge/truthsocial.com/tsmc.com/tutanota.com/typing.com/uaudio.com/uizard.io/unscreen.com/upwork.com/usher.ttvnw.net/v.vrv.co/vagrantcloud.com/veeam.com/vmware.com/vod-fy.crunchyrollcdn.com/volkswagen-classic-parts.com/vyos.io/w.atwiki.jp/walmart.com/watchguard.com/watermarkremover.io/wbgames.com/weather.com/webnames.ca/weebly.com/widgetapp.stream/wikidot.com/windsurf.com/wise.com/wpengine.com/wunderground.com/www3.corsair.com/x.ai/xiaomi.eu/xsts.auth.xboxlive.com/xtracloud.net/yeggi.com/youtrack.cloud/zapier.com/zedge.net/]https://xbox-dns.ru/dns-query'
	list upstream '[/ru/xn--p1ai/]77.88.8.1'
	list upstream 'sdns://AQAAAAAAAAAADjIwOC42Ny4yMjAuMjIwILc1EUAgbyJdPivYItf9aR6hwzzI1maNDL4Ev6vKQ_t5GzIuZG5zY3J5cHQtY2VydC5vcGVuZG5zLmNvbQ'
	list upstream 'sdns://AQMAAAAAAAAADDkuOS45Ljk6ODQ0MyBnyEe4yHWM0SAkVUO-dWdG3zTfHYTAC4xHA2jfgh2GPhkyLmRuc2NyeXB0LWNlcnQucXVhZDkubmV0'
	list upstream 'https://9.9.9.9/dns-query'
	list upstream 'https://8.8.8.8/dns-query'
	list upstream 'https://doh.opendns.com/dns-query'
	list upstream 'quic://dns.quad9.net:853'
	list upstream 'https://freedns.controld.com/p0'
	list upstream 'https://1.1.1.1/dns-query'
	list upstream 'tls://one.one.one.one'
	list upstream 'quic://p0.freedns.controld.com'

config profile 'preset_cloudflare'
	option label 'Preset: Cloudflare DoH'
	list bootstrap '1.1.1.1:53'
	list bootstrap '1.0.0.1:53'
	list upstream 'https://cloudflare-dns.com/dns-query'
	list fallback 'https://dns.quad9.net/dns-query'
	option upstream_mode 'load_balance'

config profile 'preset_quad9'
	option label 'Preset: Quad9 DoH'
	list bootstrap '9.9.9.9:53'
	list bootstrap '149.112.112.112:53'
	list upstream 'https://dns.quad9.net/dns-query'
	list fallback 'https://cloudflare-dns.com/dns-query'
	option upstream_mode 'load_balance'

config profile 'preset_google'
	option label 'Preset: Google DoH'
	list bootstrap '8.8.8.8:53'
	list bootstrap '8.8.4.4:53'
	list upstream 'https://dns.google/dns-query'
	list fallback 'https://cloudflare-dns.com/dns-query'
	option upstream_mode 'load_balance'

config profile 'preset_fast_mixed'
	option label 'Preset: Fast mixed DoH'
	list bootstrap '1.1.1.1:53'
	list bootstrap '9.9.9.9:53'
	list bootstrap '8.8.8.8:53'
	list upstream 'https://cloudflare-dns.com/dns-query'
	list upstream 'https://dns.quad9.net/dns-query'
	list fallback 'https://dns.google/dns-query'
	option upstream_mode 'parallel'
EOF

    echo -e "${GREEN}>>> Настраиваю dnsmasq (127.0.0.1#5353)...${NC}"
    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci -q delete dhcp.@dnsmasq[0].server
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
    uci commit dhcp

    echo -e "${GREEN}>>> Включаю и запускаю dnsproxy + dnsmasq...${NC}"
    /etc/init.d/dnsproxy enable 2>/dev/null
    /etc/init.d/dnsproxy restart 2>/dev/null
    /etc/init.d/dnsmasq restart

    echo -e "${GREEN}>>> Конфиг dnsproxy применён${NC}"
}

install_zapret() {
    echo -e "${GREEN}>>> Устанавливаю Zapret Manager...${NC}"
    if ! command -v wget >/dev/null 2>&1; then
        $INSTALL_CMD wget || return 1
    fi
    sh <(wget -qO - https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/ZapretManager_LuCI.sh) || {
        echo -e "${RED}Ошибка при установке Zapret Manager${NC}"
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
        echo -e "${RED}Ошибка при установке Splify2${NC}"
        return 1
    }
    echo -e "${GREEN}>>> Splify2 установлен${NC}"
}

install_internet_detector() {
    echo -e "${GREEN}>>> Устанавливаю Internet Detector...${NC}"

    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${YELLOW}wget не найден, устанавливаю...${NC}"
        $INSTALL_CMD wget || {
            echo -e "${RED}Не удалось установить wget${NC}"
            return 1
        }
    fi

    if [ "$RELEASE" = "25.12" ] || [ "$PKG_MGR" = "apk" ]; then
        # ===== 25.12 / apk =====
        echo -e "${BLUE}Режим: 25.12 (apk)${NC}"

        wget --no-check-certificate -O /tmp/internet-detector-1.7.4-r1.apk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/internet-detector-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/internet-detector-1.7.4-r1.apk
        rm -f /tmp/internet-detector-1.7.4-r1.apk

        service internet-detector start
        service internet-detector enable

        wget --no-check-certificate -O /tmp/luci-app-internet-detector-1.7.4-r1.apk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/luci-app-internet-detector-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/luci-app-internet-detector-1.7.4-r1.apk
        rm -f /tmp/luci-app-internet-detector-1.7.4-r1.apk

        service rpcd restart

        wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru-1.7.4-r1.apk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/25.12/luci-i18n-internet-detector-ru-1.7.4-r1.apk
        apk --allow-untrusted add /tmp/luci-i18n-internet-detector-ru-1.7.4-r1.apk
        rm -f /tmp/luci-i18n-internet-detector-ru-1.7.4-r1.apk

    else
        # ===== 24.10 / opkg =====
        echo -e "${BLUE}Режим: 24.10 (opkg)${NC}"

        wget --no-check-certificate -O /tmp/internet-detector_1.7.4-r1_all.ipk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/internet-detector_1.7.4-r1_all.ipk
        opkg install /tmp/internet-detector_1.7.4-r1_all.ipk
        rm -f /tmp/internet-detector_1.7.4-r1_all.ipk

        service internet-detector start
        service internet-detector enable

        wget --no-check-certificate -O /tmp/luci-app-internet-detector_1.7.4-r1_all.ipk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/luci-app-internet-detector_1.7.4-r1_all.ipk
        opkg install /tmp/luci-app-internet-detector_1.7.4-r1_all.ipk
        rm -f /tmp/luci-app-internet-detector_1.7.4-r1_all.ipk

        service rpcd restart

        wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru_1.7.4-r1_all.ipk \
            https://github.com/gSpotx2f/packages-openwrt/raw/master/24.10/luci-i18n-internet-detector-ru_1.7.4-r1_all.ipk
        opkg install /tmp/luci-i18n-internet-detector-ru_1.7.4-r1_all.ipk
        rm -f /tmp/luci-i18n-internet-detector-ru_1.7.4-r1_all.ipk
    fi

    echo -e "${GREEN}>>> Internet Detector установлен${NC}"
}

# ---------- Установка ----------
if [ "$choice" = "0" ]; then
    echo -e "${YELLOW}Устанавливаю все пакеты...${NC}"
    echo "$PACKAGES" | while IFS='|' read -r pkg desc; do
        [ -z "$pkg" ] && continue
        install_pkg "$pkg"
    done
    install_dnsproxy
    install_zapret
    install_splify
    install_internet_detector
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
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Готово!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Полезные команды:"
echo "  /etc/init.d/dnsproxy status"
echo "  /etc/init.d/zapret status"
echo "  /etc/init.d/internet-detector status"
echo "  logread | grep -E 'dnsproxy|zapret|internet-detector'"
