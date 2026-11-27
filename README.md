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

Версии берутся из последних GitHub Releases (`.ipk` для opkg, `.apk` + ключ
подписи для apk), при недоступности API используется закреплённая версия.

- **luci-theme-koka** — [luci-theme-koka](https://github.com/moseszz007/luci-theme-koka):
  самостоятельная тема Koka Modern (свой движок, дашборд и иконки).
  `luci-theme-footstrap` не нужен и не устанавливается. Отдельный пункт меню
  и установка в режиме «Установить всё».
- **luci-app-dnsproxy** — [luci-app-dnsproxy](https://github.com/moseszz007/luci-app-dnsproxy):
  мой UI вместо сторонней сборки, вместе с демоном `dnsproxy` и готовым конфигом
  (dnsmasq переключается на `127.0.0.1#5353`).

## Пункты меню

1–8. Базовые пакеты: `nano`, `unzip`, `ttyd` + LuCI, файловый менеджер, русификация.
9. DNS Proxy — демон, мой UI и готовый конфиг.
10. Только конфиг DNS Proxy.
11. Zapret Manager.
12. Splify2.
13. Internet Detector с русификатором.
14. Тема Koka Modern.
15. ZeroTier.
16. Фикс APK в LuCI (25.12).
17. Отключение IPv6.
