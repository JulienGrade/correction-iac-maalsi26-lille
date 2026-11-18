# Un catalogue avec PostgreSQL et Redis

Cet atelier déploie une petite API Node.js avec OpenTofu. PostgreSQL conserve les produits et Redis met en cache la réponse de `/products` pendant 30 secondes. Les trois services communiquent sur un réseau Docker dédié ; seul le port de l’API est accessible depuis le poste, sur `127.0.0.1:3000`.

## Pour le lancer

Il faut Docker en fonctionnement et OpenTofu installé. Sur Windows, les commandes ci-dessous peuvent être lancées dans un terminal Ubuntu sous WSL avec l’intégration Docker Desktop activée. Pour les appels HTTP dans PowerShell, utiliser `curl.exe` à la place de `curl`.

Se placer dans le dossier `tofu-catalogue`, puis construire l’image de l’API :

```bash
docker build -t infra-si-catalogue-api:lab ./api
docker image inspect --format '{{.Id}}' infra-si-catalogue-api:lab
```

Copier l’identifiant `sha256:...` obtenu dans un fichier `terraform.tfvars`, en prenant `terraform.tfvars.example` comme modèle. Renseigner également `db_password` avec un mot de passe réservé à cet environnement local. Ce fichier et l’état OpenTofu ne doivent pas être publiés : l’état contient aussi la valeur sensible.

Sur mon Mac, le fournisseur Docker a besoin du contexte utilisé par Docker Desktop :

```bash
export DOCKER_CONTEXT=desktop-linux
```

Sous PowerShell, l’équivalent est `$env:DOCKER_CONTEXT = "desktop-linux"`. Vérifier le contexte disponible avec `docker context ls` si son nom diffère.

```bash
tofu init
tofu fmt
tofu validate
tofu plan -out=catalogue.tfplan
tofu show catalogue.tfplan
tofu apply catalogue.tfplan
tofu output api_url
```

Le plan initial crée huit ressources : un réseau, deux volumes, deux images et trois conteneurs. L’API est ensuite accessible sur `http://127.0.0.1:3000`.

J’utilise la version `3.9.0` du fournisseur `kreuzwerker/docker` : avec OpenTofu 1.11.2, l’installation de la version `3.6.1` indiquée dans le support échouait sur la vérification de sa signature.

## Ce que j’ai vérifié

```bash
curl -fsS http://127.0.0.1:3000/health
curl -fsS http://127.0.0.1:3000/products
curl -fsS http://127.0.0.1:3000/products
```

La santé de l’API a renvoyé `{"database":"ok","redis":"ok"}`. Le premier appel à `/products` a renvoyé **Clavier** et **Souris** avec `"source":"postgresql"` ; le second, lancé moins de 30 secondes après, a renvoyé les mêmes produits avec `"source":"redis"`. Après expiration du cache, la source est redevenue PostgreSQL.

J’ai ajouté **Ecran** dans PostgreSQL, puis redémarré le conteneur de base :

```bash
docker exec infra-si-catalogue-db psql -U catalogue -d catalogue -c "INSERT INTO products VALUES (3, 'Ecran') ON CONFLICT DO NOTHING;"
docker restart infra-si-catalogue-db
```

Après expiration du cache, `/products` affichait toujours les trois produits depuis PostgreSQL. Le redémarrage confirme que les données résistent à l’arrêt et à la reprise du même conteneur. Remplacer ce conteneur tout en réutilisant son volume vérifierait en plus que les données ne dépendent pas du conteneur lui-même.

`docker logs infra-si-catalogue-api` n’a affiché aucune ligne pendant mon essai : l’application ne journalise pas ces requêtes. Le champ `source` des réponses HTTP permet de constater le passage par le cache.

## Nettoyer et reconstruire

Avant de supprimer la pile, examiner le plan :

```bash
tofu plan -destroy -out=catalogue-destroy.tfplan
tofu show catalogue-destroy.tfplan
tofu apply catalogue-destroy.tfplan
docker ps -a --filter name=infra-si-catalogue
```

**La destruction supprime aussi les deux volumes et toutes leurs données.** Elle ne supprime ni les fichiers du projet ni l’image de l’API construite séparément.

J’ai reconstruit la pile après ce nettoyage. `/products` a alors renvoyé **Clavier** et **Souris** depuis PostgreSQL, sans **Ecran** : l’application démarre bien sur de nouveaux volumes.