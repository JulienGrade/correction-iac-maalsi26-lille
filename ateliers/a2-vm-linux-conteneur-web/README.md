# VM Ubuntu et conteneur Nginx

Une VM Ubuntu Server héberge Docker Engine, qui lance à son tour un conteneur Nginx. Cette configuration permet de voir trois réseaux distincts : celui de l’hôte, celui de la VM en NAT et celui du conteneur Docker.

La VM sert aussi de point de départ aux ateliers A3 et A4. Son disque virtuel reste sur la machine qui l’héberge ; il n’est pas versionné dans ce dépôt.

## Créer la VM

Installer VirtualBox sur un poste macOS ou Windows, puis télécharger l’ISO **Ubuntu Server 24.04 LTS AMD64**. Créer la VM avec les paramètres suivants :

| Réglage | Valeur |
| --- | --- |
| Nom dans VirtualBox | `UbuntuDev` ; `UbuntuDev_1` si ce nom est déjà utilisé |
| Système invité | Ubuntu 24.04 LTS, 64 bits |
| Mémoire | 2 Go minimum |
| Processeurs | 2 si l’hôte le permet |
| Disque | Nouveau VDI dynamique de 20 Go |
| Carte réseau 1 | Activée, mode NAT |

Choisir l’installation manuelle d’Ubuntu plutôt que l’installation automatisée de VirtualBox. Dans l’installateur, créer un compte local, laisser le proxy vide si le réseau n’en utilise pas, activer **Install OpenSSH Server** et ne sélectionner aucun paquet dans **Featured Server Snaps**. Après l’installation, retirer l’ISO du lecteur virtuel si Ubuntu le demande avant de redémarrer.

Sur la VM utilisée ici, le nom VirtualBox est `UbuntuDev_1` et le nom du système Ubuntu est `unbuntudev1`. Le nom du compte et son mot de passe sont propres à chaque installation.

## Relever le réseau Ubuntu

Dans le terminal **de la VM** :

```bash
ip -br addr
ip route
```

Avec la carte NAT VirtualBox, nous avons obtenu `10.0.2.15/24` sur `enp0s3` et une route par défaut via `10.0.2.2`. Ces adresses peuvent varier selon la configuration locale.

## Installer Docker dans Ubuntu

Suivre la [procédure officielle d’installation de Docker Engine sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/). Sur cette VM neuve, aucun paquet Docker ou `containerd` en conflit n’était installé.

Toutes les commandes qui suivent s’exécutent **dans Ubuntu**, à la console VirtualBox ou par SSH :

```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Créer `/etc/apt/sources.list.d/docker.sources` avec ce contenu pour Ubuntu 24.04 AMD64 :

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
```

Installer et vérifier le moteur :

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl is-active docker
sudo docker run --rm hello-world
```

Le service doit afficher `active` et le conteneur de test doit afficher `Hello from Docker!`. Les commandes utilisent `sudo` : aucun accès au moteur Docker n’a été accordé au compte utilisateur.

## Accéder à la VM depuis l’hôte

Avec le NAT seul, l’hôte n’accède pas directement à `10.0.2.15`. Dans VirtualBox, ajouter sur la **carte 1** une règle de redirection TCP pour SSH :

| Règle | Adresse hôte | Port hôte | Adresse invitée | Port invité |
| --- | --- | ---: | --- | ---: |
| `ssh` | `127.0.0.1` | `2222` | laisser vide | `22` |

Sur macOS ou dans PowerShell sur Windows, se connecter depuis **l’hôte** avec le nom du compte choisi lors de l’installation :

```text
ssh -p 2222 <utilisateur>@127.0.0.1
```

Les commandes saisies après la connexion SSH s’exécutent dans la VM. La redirection SSH n’écoute que sur la boucle locale de l’hôte.

## Lancer et vérifier Nginx

Dans le terminal **de la VM** :

```bash
sudo docker run -d --name web-vm -p 8088:80 nginx:1.28-alpine
sudo docker ps
sudo docker exec web-vm nginx -t
curl -I http://127.0.0.1:8088
sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-vm
```

Le conteneur doit être `Up`, le test de configuration Nginx doit réussir et la réponse HTTP doit être `200 OK`. Dans notre exécution, le conteneur avait l’adresse Docker `172.17.0.2`, distincte de l’adresse `10.0.2.15` de la VM.

Pour consulter Nginx depuis **l’hôte** en mode NAT, ajouter dans VirtualBox une seconde règle TCP sur la carte 1 :

| Règle | Adresse hôte | Port hôte | Adresse invitée | Port invité |
| --- | --- | ---: | --- | ---: |
| `web` | `127.0.0.1` | `8088` | laisser vide | `8088` |

Dans le terminal **macOS ou PowerShell de l’hôte** :

```text
curl -I http://127.0.0.1:8088
```

La réponse doit aussi être `HTTP/1.1 200 OK`. L’adresse `http://127.0.0.1:8088` affiche la page Nginx dans le navigateur de l’hôte.

## Nettoyer

Dans la VM, arrêter et supprimer le conteneur de test :

```bash
sudo docker rm -f web-vm
```

Cette commande ne supprime ni Docker ni le disque de la VM. Conserver `UbuntuDev_1` pour les ateliers réseau et stockage. Pour arrêter proprement Ubuntu lorsque la VM n’est plus utilisée :

```bash
sudo shutdown -h now
```