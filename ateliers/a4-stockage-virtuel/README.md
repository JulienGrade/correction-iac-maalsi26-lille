# Ajouter un disque de données à Ubuntu

Cet atelier réutilise la VM Ubuntu préparée en [A2](../a2-vm-linux-conteneur-web/) et connectée au poste hôte en [A3](../a3-reseau-vm/). Un second disque virtuel est partitionné, formaté en ext4 et monté dans Ubuntu. Un fichier témoin permet de vérifier que les données restent présentes après démontage et redémarrage.

Le fichier VDI et les données qu’il contient restent sur le poste hôte. Ils ne font pas partie du dépôt Git.

## Ajouter le disque dans VirtualBox

Éteindre la VM. Dans **Configuration → Stockage**, ajouter un **nouveau disque dur** au contrôleur SATA :

| Réglage | Valeur |
| --- | --- |
| Nom | `lab-data.vdi` |
| Type | VDI |
| Taille virtuelle | 2 Gio |
| Allocation | Dynamique, sans préallocation complète |

Vérifier que le contrôleur SATA contient toujours le disque système `UbuntuDev_1.vdi` de 20 Gio, ainsi que le nouveau `lab-data.vdi` de 2 Gio. La création du disque se fait dans l’interface VirtualBox sur macOS comme sur Windows.

## Identifier le disque dans Ubuntu

Démarrer la VM et lancer **dans Ubuntu** :

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Sur notre VM, `/dev/sda` est le disque système de 20 Go, avec les partitions Ubuntu, et `/dev/sdb` est le nouveau disque vide de 2 Go. **Vérifier ces noms sur chaque VM avant la suite : ils peuvent être différents.**

Le partitionnement et le formatage écrivent sur le disque choisi. Une erreur de périphérique peut détruire les données du disque système.

## Partitionner et formater

Ouvrir `fdisk` sur le **disque de 2 Go vérifié avec `lsblk`** :

```bash
sudo fdisk /dev/sdb
```

Dans `fdisk`, saisir `g` pour préparer une table GPT, puis `n` et accepter les valeurs par défaut pour créer une partition occupant le disque. Saisir `p` et contrôler que le récapitulatif indique bien `/dev/sdb`, 2 Gio, GPT et `/dev/sdb1`. Saisir ensuite `w` pour écrire la table sur le disque.

Vérifier la partition **avant de la formater** :

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

`/dev/sdb1` doit faire environ 2 Go et ne présenter ni système de fichiers ni montage. La commande suivante crée ext4 et **efface tout contenu éventuel de cette partition** :

```bash
sudo mkfs.ext4 /dev/sdb1
```

## Monter et retrouver un fichier

Dans Ubuntu :

```bash
sudo mkdir -p /mnt/lab-data
sudo mount /dev/sdb1 /mnt/lab-data
findmnt /mnt/lab-data
echo "Disque de test" | sudo tee /mnt/lab-data/temoin.txt
sudo umount /mnt/lab-data
sudo mount /dev/sdb1 /mnt/lab-data
cat /mnt/lab-data/temoin.txt
```

`findmnt` doit montrer `/dev/sdb1` monté en ext4 sur `/mnt/lab-data`. Après démontage et remontage, `cat` doit afficher `Disque de test`.

## Conserver le montage après redémarrage

Relever l’UUID propre à **la partition de données** :

```bash
sudo blkid /dev/sdb1
```

Faire une copie de `/etc/fstab`, puis y ajouter **une seule ligne** en remplaçant `<UUID_DE_LA_PARTITION>` par l’UUID obtenu avec `blkid` :

```bash
sudo cp /etc/fstab /etc/fstab.bak
sudo nano /etc/fstab
```

```text
UUID=<UUID_DE_LA_PARTITION> /mnt/lab-data ext4 defaults,nofail 0 2
```

L’UUID est préférable au nom `/dev/sdb1`, qui peut changer si d’autres disques sont ajoutés. L’option `nofail` laisse Ubuntu démarrer si ce disque de travail est absent. Conserver les entrées existantes de `/etc/fstab`.

Vérifier la syntaxe et tester le montage **avant tout redémarrage** :

```bash
sudo findmnt --verify
sudo systemctl daemon-reload
sudo umount /mnt/lab-data
sudo mount -a
findmnt /mnt/lab-data
cat /mnt/lab-data/temoin.txt
```

`findmnt --verify` ne doit signaler aucune erreur de syntaxe. `mount -a` doit remonter le disque et le témoin doit rester lisible. On peut ensuite redémarrer la VM avec `sudo reboot`, puis relancer `findmnt /mnt/lab-data` et `cat /mnt/lab-data/temoin.txt` sans montage manuel.

Sur notre VM, ces deux vérifications ont réussi après redémarrage.

## Nettoyer ou conserver

Le disque peut rester attaché à la VM avec son montage permanent. Pour revenir à l’état précédent, retirer **uniquement sa ligne** de `/etc/fstab`, lancer `sudo systemctl daemon-reload`, puis `sudo umount /mnt/lab-data`. Éteindre la VM avant de détacher `lab-data.vdi` dans VirtualBox.

**Détacher le VDI ne supprime pas son contenu. Supprimer le fichier `lab-data.vdi` détruit les données enregistrées dessus.** Ne toucher ni au disque système `UbuntuDev_1.vdi` ni à ses entrées dans `/etc/fstab`.