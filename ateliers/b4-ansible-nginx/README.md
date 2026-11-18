# Nginx avec Ansible

Cette fois, Ansible tourne sur mon Mac et configure la VM Ubuntu à distance par SSH. Le fichier `inventory.ini` indique quelle machine joindre ; `web.yml` décrit le paquet, la page et le service attendus.

## Refaire l’atelier

La cible doit avoir SSH et Python 3, ainsi qu’un compte autorisé à utiliser `sudo`. J’ai réutilisé la VM des ateliers précédents. Avant Ansible, j’ai vérifié son empreinte SSH depuis sa console, puis configuré une connexion par clé depuis le Mac.

Sur Windows, la machine de contrôle peut être un environnement Linux sous WSL, à condition qu’il puisse joindre la VM. La clé SSH doit être configurée dans cet environnement. L’adresse et le compte dans `inventory.ini` sont ceux de ma VM ; il faut les adapter à sa propre installation. Si le réseau privé n’est pas accessible, la redirection de port SSH du NAT VirtualBox peut être utilisée en renseignant `ansible_host` et `ansible_port`.

Depuis la racine du dépôt, sur la machine de contrôle :

```bash
ansible -i ateliers/b4-ansible-nginx/inventory.ini targets -m ansible.builtin.ping
ansible-playbook -i ateliers/b4-ansible-nginx/inventory.ini ateliers/b4-ansible-nginx/web.yml --syntax-check
ansible-playbook -i ateliers/b4-ansible-nginx/inventory.ini ateliers/b4-ansible-nginx/web.yml -K
ansible-playbook -i ateliers/b4-ansible-nginx/inventory.ini ateliers/b4-ansible-nginx/web.yml -K
ansible-playbook -i ateliers/b4-ansible-nginx/inventory.ini ateliers/b4-ansible-nginx/web.yml -K --check --diff
```

`-K` demande le mot de passe sudo du compte de la VM, pas le mot de passe SSH. Le contrôle final se fait depuis un poste qui peut joindre la VM :

```bash
curl -fsS http://192.168.56.20/ansible.html
```

La page doit afficher `Configuration geree avec Ansible`.

## Résultat obtenu

Le module `ping` a répondu `pong`. Nginx était déjà installé et actif depuis l’atelier Puppet : à la première exécution, seule la création de `ansible.html` a été signalée comme changement (`changed=1`, `failed=0`). La seconde exécution et le contrôle `--check --diff` ont donné `changed=0`. Une tâche `ok` a vérifié que l’état demandé était déjà présent ; une tâche `changed` a effectivement modifié la cible.

Ansible a aussi affiché un avertissement indiquant qu’il a découvert Python dans `/usr/bin/python3.12`. Cela n’a pas empêché l’exécution des modules.

## Par rapport à Puppet

Dans `web.yml`, Ansible exécute les tâches dans l’ordre écrit : installer le paquet, copier la page, puis assurer le service. Dans le manifeste Puppet de B3, les relations `require` expriment que le fichier et le service dépendent du paquet.

Pour cet atelier, Puppet tournait directement **dans la VM** avec `puppet apply`. Ansible tournait **sur le Mac** et atteignait la VM par SSH. Dans les deux cas, j’ai vérifié le service et le contenu de la page, puis relancé l’outil pour constater qu’il n’y avait plus de changement.

Si je dois libérer le port 80 de la VM, `sudo systemctl stop nginx` arrête le service sans effacer le paquet ni les pages. Rejouer Puppet ou Ansible avec cette configuration le redémarrera.