# Focus Follow Mouse (macOS)

Přepíná aktivní okno při přejetí kurzorem (bez nutnosti klikat).

## Stažení projektu přes terminál

Potřebuješ [Git](https://git-scm.com/). V terminálu:

```bash
git clone https://github.com/pangery/FocusFollowMouse.git
cd FocusFollowMouse
```

Pak pokračuj sestavením (sekce níže).

**Bez Gitu:** na stránce repozitáře na GitHubu tlačítko **Code → Download ZIP**, rozbal složku a v terminálu do ní přejdi (`cd` na rozbalenou cestu).

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
