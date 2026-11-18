# Relier la VM au poste hôte

La VM Ubuntu conserve sa première carte en NAT pour accéder au réseau extérieur. Une seconde carte, sur un réseau privé hôte, permet au Mac ou au PC Windows de joindre directement Ubuntu. La configuration Netplan utilisée dans la VM est conservée dans [`60-lab.yaml`](60-lab.yaml).

Cet atelier réutilise la VM créée dans [A2](../a2-vm-linux-conteneur-web/).

## Préparer le réseau dans VirtualBox

Éteindre la VM avant de modifier ses cartes. Laisser **Adapter 1 en NAT**, puis activer **Adapter 2** sur un réseau privé hôte.

Sur macOS avec VirtualBox 7.2, choisir **Host-Only Network**. Le réseau utilisé ici s’appelle `a3-prive`, avec le masque `255.255.255.0`. Son adresse côté Mac est `192.168.56.1` et sa plage DHCP va de `192.168.56.2` à `192.168.56.10`.

Sur Windows, créer ou sélectionner un réseau privé hôte dans le gestionnaire réseau de VirtualBox, puis vérifier l’adresse de l’adaptateur virtuel avec `ipconfig` dans PowerShell. Selon la version de VirtualBox, le choix de la carte peut s’appeler **Host-Only Adapter** ou **Host-Only Network**. Donner à l’hôte une adresse du réseau `192.168.56.0/24`, par exemple `192.168.56.1`.

L’adresse fixe `192.168.56.20` choisie pour Ubuntu doit rester libre et hors de la plage DHCP. Adapter les adresses du fichier Netplan si le réseau privé choisi est différent.

## Configurer Ubuntu

Démarrer la VM. Dans Ubuntu, repérer les interfaces et les fichiers Netplan existants :

```bash
ip -br link
ls -la /etc/netplan
```

Dans notre VM, `enp0s3` est la carte NAT et `enp0s8` est la carte privée. Le fichier `50-cloud-init.yaml` configure déjà `enp0s3` en DHCP. Ne pas redéfinir cette interface dans un second fichier.

Reproduire le contenu de [`60-lab.yaml`](60-lab.yaml) dans `/etc/netplan/60-lab.yaml` **dans la VM**. Si la seconde interface porte un autre nom, le remplacer dans le fichier. Vérifier puis essayer la configuration :

```bash
sudo chmod 600 /etc/netplan/60-lab.yaml
sudo netplan generate
sudo netplan try
```

Effectuer `netplan try` depuis la **console VirtualBox**. Avant d’accepter, vérifier dans un autre terminal connecté à la VM :

```bash
ip -br addr
ip route
```

`enp0s8` doit avoir `192.168.56.20/24`. La route par défaut doit rester sur `enp0s3`, via la passerelle NAT. Confirmer dans la console VirtualBox avant la fin du délai. En cas de problème, laisser le délai expirer pour revenir à la configuration précédente.

## Vérifier les flux

Dans la VM :

```bash
getent hosts ubuntu.com
```

La commande doit retourner une adresse : la résolution DNS fonctionne toujours après l’ajout de la carte privée.

Depuis un **terminal de l’hôte**, vérifier d’abord l’accès à la VM :

| Test | Terminal macOS | PowerShell Windows |
| --- | --- | --- |
| ICMP | `ping -c 3 192.168.56.20` | `ping -n 3 192.168.56.20` |
| SSH | `ssh <utilisateur>@192.168.56.20` | `ssh <utilisateur>@192.168.56.20` |

Remplacer `<utilisateur>` par le compte créé dans Ubuntu. Si le ping est bloqué, tester aussi SSH : une absence de réponse ICMP ne suffit pas à conclure que le réseau est inaccessible.

Pour tester HTTP, lancer temporairement Nginx **dans la VM** :

```bash
sudo docker run -d --name web-vm -p 8088:80 nginx:1.28-alpine
```

Puis, depuis **l’hôte** :

```text
http://192.168.56.20:8088
```

L’URL doit afficher la page Nginx dans un navigateur. Dans un terminal macOS, `curl -I http://192.168.56.20:8088` doit répondre `HTTP/1.1 200 OK`. Dans PowerShell, utiliser `curl.exe -I http://192.168.56.20:8088`.

Sur notre installation, les vérifications ont montré `10.0.2.15/24` sur la carte NAT, `192.168.56.20/24` sur la carte privée, une route par défaut via `10.0.2.2`, trois réponses au ping depuis le Mac, une connexion SSH directe et une réponse HTTP `200 OK`.

## Nettoyer

Supprimer le conteneur de vérification **dans la VM** :

```bash
sudo docker rm -f web-vm
```

Conserver les deux cartes réseau, le fichier Netplan et la VM : ils seront réutilisés pour l’atelier de stockage A4.