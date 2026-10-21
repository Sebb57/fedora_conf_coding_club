### Première installation (en root)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh) init
```

L'utilisateur cible est détecté automatiquement (`SUDO_USER`, sinon le premier compte UID ≥ 1000).
Pour le forcer :
```bash
TARGET_USER=alice bash <(curl -fsSL https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh) init
```

### Mise à jour
Depuis le terminal de l'utilisateur (pas de mot de passe demandé) :
```bash
update-conf
```

Chaque mise à jour récupère la dernière version du script sur `main` et la réapplique entièrement
(paquets, zsh, VS Code…), donc tous les PC restent identiques.
Les réglages perso du shell vont dans `~/.zshrc.local` (`~/.zshrc` est écrasé à chaque mise à jour).

Logs : `/var/log/coding-club.log`
