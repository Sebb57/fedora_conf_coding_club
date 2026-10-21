### Première installation
Depuis le compte utilisateur créé à l'installation de Fedora :
```bash
curl -fsSL https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh | sudo bash -s -- init
```
(Déjà en root, par ex. après `su -` : même commande sans `sudo`.)

L'utilisateur cible est détecté automatiquement (`SUDO_USER`, sinon le premier compte UID ≥ 1000).
Pour le forcer :
```bash
curl -fsSL https://raw.githubusercontent.com/Sebb57/fedora_conf_coding_club/main/install.sh | sudo TARGET_USER=alice bash -s -- init
```

> Ne pas utiliser `sudo bash <(curl …)` : sudo ferme le descripteur `/dev/fd/63`
> et bash échoue avec `/dev/fd/63: No such file or directory`.

### Mise à jour
Depuis le terminal de l'utilisateur (pas de mot de passe demandé) :
```bash
update-conf
```

Chaque mise à jour récupère la dernière version du script sur `main` et la réapplique entièrement
(paquets, zsh, VS Code…), donc tous les PC restent identiques.
Les réglages perso du shell vont dans `~/.zshrc.local` (`~/.zshrc` est écrasé à chaque mise à jour).

Logs : `/var/log/coding-club.log`
