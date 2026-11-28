# Start_setup_OpenWrt 2.0

Установщик пакетов и утилит для OpenWrt (24.10 / 25.12, `opkg` и `apk`).

## Запуск

```sh
sh <(wget -O - https://raw.githubusercontent.com/moseszz007/Start_setup_OpenWrt/refs/heads/main/Start_setup_OpenWrt.sh)
```

Без интерактивного меню:

```sh
sh Start_setup_OpenWrt.sh --all      # установить всё
sh Start_setup_OpenWrt.sh 1 4 9      # выбранные пункты
sh Start_setup_OpenWrt.sh 2-5        # диапазон пунктов
sh Start_setup_OpenWrt.sh --help     # справка
```

## Что умеет

- Определяет `opkg`/`apk` и версию прошивки, показывает их в шапке меню.
- Помечает в меню уже установленные пакеты (`[+]` / `[ ]`).
- Принимает несколько пунктов сразу, диапазоны и запятые.
- Короткий итог в конце: что установилось, что упало.
- В тихом режиме пишет логи установки в `/tmp/setup-install.log` и показывает
  последние строки только при ошибке.
- Сам ставит `wget`/`curl`/`ca-bundle`, если на роутере нет загрузчика.

## Мои пакеты

Версии закреплены в скрипте: пакет качается напрямую по ссылке на релиз
(`.ipk` для opkg, `.apk` + ключ подписи для apk), без запроса к GitHub API.
API используется только если прямая ссылка не открылась.

- **luci-theme-koka** — [luci-theme-koka](https://github.com/moseszz007/luci-theme-koka):
  самостоятельная тема Koka Modern (свой движок, дашборд и иконки).
  `luci-theme-footstrap` не нужен и не устанавливается. Отдельный пункт меню
  и установка в режиме «Установить всё».
- **luci-app-dnsproxy** — [luci-app-dnsproxy](https://github.com/moseszz007/luci-app-dnsproxy):
  мой UI вместо сторонней сборки, вместе с демоном `dnsproxy` и готовым конфигом
  (dnsmasq переключается на `127.0.0.1#5353`).
- **luci-app-zerotier** — [luci-app-zerotier](https://github.com/moseszz007/luci-app-zerotier):
  панель ZeroTier в LuCI (VPN → ZeroTier): статус узла, сети, пиры,
  join/leave, флаги сетей и кнопка доступа к веб-интерфейсу через ZeroTier.

## Пункты меню

1–8. Базовые пакеты: `nano`, `unzip`, `ttyd` + LuCI, файловый менеджер, русификация.
9. DNS Proxy — демон, мой UI и готовый конфиг.
10. Только конфиг DNS Proxy.
11. Zapret Manager.
12. Internet Detector с русификатором.
13. Тема Koka Modern.
14. ZeroTier: демон + моя панель LuCI + мастер настройки (см. ниже).
15. Фикс APK в LuCI (25.12).
16. Отключение IPv6.

## Мастер ZeroTier (пункт 14)

Ставит демон `zerotier` из фида и `luci-app-zerotier` из GitHub Releases, затем
спрашивает:

1. **Network ID** — 16 hex-символов; если сеть уже есть в конфиге, предлагается
   она (Enter — оставить), пустой ввод — пропустить.
2. **Запускать при загрузке** (по умолчанию да) — выставляет
   `zerotier.global.enabled` и `init.d/zerotier enable`.
3. **Открыть LuCI через ZeroTier** (по умолчанию да) — создаёт правило
   фаервола `Allow-LuCI-ZeroTier` (TCP 80/443 на интерфейсе `zt*`) и применяет
   его, после чего печатает адрес вида `http://10.x.x.x/`.

Сеть пишется в актуальной схеме `zerotier >= 1.14` (`config network` +
`option id`), а не в устаревшую `openwrt_network/join` — именно из-за неё
старый мастер не подключал сеть. Отдельный netifd-интерфейс больше не
создаётся: ZeroTier поднимает `ztXXXXXXXX` сам, а адрес выдаёт контроллер
(скрипт ждёт его до 30 секунд).
