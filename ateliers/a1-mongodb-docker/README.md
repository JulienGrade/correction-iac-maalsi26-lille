# MongoDB avec Docker

Ce dossier lance une instance locale de MongoDB 7 avec Docker Compose. Les données sont placées dans un volume nommé : on peut donc remplacer le conteneur et retrouver les documents enregistrés.

## Avant de commencer

Docker Desktop doit être installé et démarré, avec les conteneurs Linux activés. Les commandes ci-dessous fonctionnent dans Terminal sur macOS et dans PowerShell sur Windows.

Le fichier de configuration se trouve dans [`mongo-local/compose.yaml`](mongo-local/compose.yaml). Il publie MongoDB uniquement sur `127.0.0.1:27017`. Les identifiants `root` et `example` sont réservés à cet exemple local.

## Démarrer MongoDB

Depuis la racine du dépôt, ouvrir un terminal dans le dossier du service :

```text
cd ateliers/a1-mongodb-docker/mongo-local
```

Vérifier la configuration, démarrer le service et contrôler son état :

```text
docker compose config --quiet
docker compose up -d
docker compose ps
```

La première commande ne produit aucune sortie si la configuration est valide. La dernière doit afficher `mongo` avec l’état `Up` et le port `127.0.0.1:27017->27017/tcp`.

## Écrire et relire un document

Ouvrir le shell MongoDB dans le conteneur :

```text
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

Si MongoDB vient de démarrer et n’accepte pas encore la connexion, attendre quelques secondes puis relancer cette commande.

À l’invite `mongosh`, saisir :

```javascript
use support

db.tickets.updateOne(
  { code: "T-101" },
  { $set: { sujet: "Acces au portail" } },
  { upsert: true }
)

db.tickets.findOne({ code: "T-101" })
```

La lecture doit retourner un document contenant `code: 'T-101'` et `sujet: 'Acces au portail'`. Quitter ensuite `mongosh` avec `exit`.

## Vérifier que les données persistent

Toujours depuis `mongo-local`, remplacer le conteneur puis rouvrir `mongosh` :

```text
docker compose down
docker compose up -d
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

Dans `mongosh` :

```javascript
use support
db.tickets.findOne({ code: "T-101" })
```

Le document `T-101` doit être retrouvé. Ce résultat confirme que les données ont été conservées dans le volume malgré la suppression du premier conteneur.

## Arrêter le service

Quitter `mongosh` avec `exit`, puis lancer depuis `mongo-local` :

```text
docker compose down
```

Cette commande arrête le service et conserve le volume de données pour une prochaine exécution. **`docker compose down -v` supprime aussi le volume et les documents qu’il contient** : ne l’utiliser que pour remettre volontairement l’exercice à zéro.