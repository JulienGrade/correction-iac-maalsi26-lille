# Nginx avec Puppet

J’ai réutilisé la VM Ubuntu Server préparée dans l’atelier A2. Puppet s’exécute directement dans cette VM avec `puppet apply` : `site.pp` charge le module `web_nginx`, qui installe Nginx, crée une page et maintient le service actif.

Le port 80 de la VM doit être libre avant l’application. Le conteneur Nginx utilisé précédemment publiait le port 8088, il ne gênait donc pas cet essai.

## Refaire l’atelier

Sur le poste Mac ou Windows, copier ce dossier dans la VM. Depuis la racine du dépôt :

```bash
scp -r ateliers/b3-puppet-nginx julien@192.168.56.20:~/
```

L’adresse est celle de ma VM ; elle est à adapter si le réseau privé diffère. Sur Windows, cette commande peut être lancée dans PowerShell ou dans un terminal WSL disposant de `scp`.

Dans un terminal **connecté à la VM Ubuntu** :

```bash
sudo apt update
sudo apt install puppet-agent
puppet --version
cd ~/b3-puppet-nginx
puppet parser validate site.pp modules/web_nginx/manifests/init.pp
sudo puppet apply --modulepath="$PWD/modules" --noop site.pp
sudo puppet apply --modulepath="$PWD/modules" site.pp
systemctl is-active nginx
curl -fsS http://127.0.0.1/puppet.html
```

Le mode `--noop` annonce les modifications sans les effectuer. Après l’application, le service doit être `active` et la page doit afficher `Configuration geree avec Puppet`.

Sur Ubuntu 24.04, `puppet-agent` provient du dépôt Universe. Si le paquet est introuvable, il faut vérifier que ce dépôt est activé, puis relancer `sudo apt update`.

## Ce que j’ai observé

Dans ma VM, `puppet --version` a affiché `8.4.0`. La première application a installé Nginx et créé la page. La seconde a affiché seulement `Applied catalog`, sans changement : les ressources étaient déjà dans l’état demandé.

J’ai ensuite remplacé temporairement le contenu de `/var/www/html/puppet.html` par `Page modifiee manuellement`. À l’application suivante, Puppet a signalé `content changed`. Un nouvel appel HTTP a affiché à nouveau `Configuration geree avec Puppet`. Le fichier déployé a donc été remis en conformité avec le manifeste.

Pour libérer le port 80 après l’atelier, on peut arrêter le service dans la VM avec `sudo systemctl stop nginx`. Cela ne supprime ni le paquet ni les fichiers. Une nouvelle application du manifeste le redémarrera.