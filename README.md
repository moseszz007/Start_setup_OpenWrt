Для запуска скрипта 
```
sh <(wget -O - https://raw.githubusercontent.com/moseszz007/Start_setup_OpenWrt/refs/heads/main/Start_setup_OpenWrt.sh)
```

## Что устанавливается из моих репозиториев

- **LuCI Theme Koka** — [luci-theme-koka](https://github.com/moseszz007/luci-theme-koka):
  отдельный пункт меню и установка в режиме «Установить всё». Перед темой
  автоматически ставится движок `luci-theme-footstrap`.
- **luci-app-dnsproxy** — [luci-app-dnsproxy](https://github.com/moseszz007/luci-app-dnsproxy):
  вместо сторонней сборки, вместе с демоном `dnsproxy` и готовым конфигом.

Версии пакетов берутся из последних GitHub Releases (`.ipk` для opkg,
`.apk` + ключ подписи для apk).

