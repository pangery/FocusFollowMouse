# Focus Follow Mouse (macOS)

Přepíná aktivní okno při přejetí kurzorem (bez nutnosti klikat).

## Sestavení

```bash
swift build -c release
```

Spuštění: `.build/release/FocusFollowMouse`

## Autostart po přihlášení

```bash
./scripts/install-launch-agent.sh
```

Binárka se zkopíruje do `~/Library/Application Support/FocusFollowMouse/` a zaregistruje se Launch Agent (`RunAtLoad`).

Odinstalace:

```bash
./scripts/uninstall-launch-agent.sh
```

V **Soukromí a zabezpečení → Dostupnost** musí být povolená příslušná binárka.

## Nasazení na GitHub

```bash
cd ~/FocusFollowMouse
git add -A && git commit -m "Initial commit"
gh auth login -h github.com   # pokud ještě nemáš platný token
gh repo create FocusFollowMouse --private --source=. --remote=origin --push
```

Nebo vytvoř prázdný repozitář na [github.com/new](https://github.com/new) a:

```bash
git remote add origin https://github.com/TVOJEJMENO/FocusFollowMouse.git
git push -u origin main
```
