#!/bin/bash
# Устанавливает гритер в /etc/xdg/quickshell/greeter (откуда его запускает greetd)
# и добавляет polkit-правило для кнопок питания.
# Запускать из терминала: ./deploy.sh (спросит пароль sudo).
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)"
dst="/etc/xdg/quickshell/greeter"

sudo install -d -m 755 -o greeter -g greeter "$dst"
sudo install -m 755 -o greeter -g greeter "$src/launch.sh" "$dst/launch.sh"
sudo install -m 644 -o greeter -g greeter "$src/shell.qml" "$dst/shell.qml"
sudo install -d -m 755 /etc/polkit-1/rules.d
sudo install -m 644 -o root -g root "$src/50-greeter.rules" /etc/polkit-1/rules.d/50-greeter.rules
sudo systemctl restart polkit 2>/dev/null || true

echo "Готово: файлы установлены в $dst"
echo
echo "Чтобы включить гритер вместо SDDM:"
echo "  sudo systemctl disable sddm"
echo "  sudo systemctl enable greetd"
echo "  reboot"
echo
echo "Если после перезагрузки вход не сработает: Ctrl+Alt+F3, войти как zrtt и вернуть SDDM:"
echo "  sudo systemctl disable greetd"
echo "  sudo systemctl enable --now sddm"
echo "  логи: /var/lib/greeter/quickshell.log и journalctl -u greetd -b"
