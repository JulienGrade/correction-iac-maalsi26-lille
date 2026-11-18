# Nginx dans Minikube

Ce scénario déploie Nginx dans un cluster Kubernetes local. Le Deployment maintient un Pod en fonctionnement ; le Service lui donne un point d’accès stable dans le cluster. Le fichier [`nginx.yaml`](nginx.yaml) conserve ces deux ressources pour pouvoir les recréer.

## Préparer le poste

Installer Minikube et démarrer Docker Desktop en mode conteneurs Linux sur macOS ou Windows. Toutes les commandes de ce dossier se lancent dans le **terminal du poste hôte**, pas dans la VM Ubuntu des ateliers précédents.

Le profil Minikube `infra-si` isole ce cluster des autres profils :

```text
minikube start -p infra-si --driver=docker
minikube -p infra-si kubectl -- get nodes
```

Le nœud `infra-si` doit être `Ready`. La forme `minikube ... kubectl --` permet d’utiliser `kubectl` sans installation séparée.

## Déployer Nginx avec les commandes de l’atelier

```text
minikube -p infra-si kubectl -- create deployment nginx --image=nginx:1.28-alpine
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
minikube -p infra-si kubectl -- expose deployment nginx --port=80
minikube -p infra-si kubectl -- get pods,services
```

Le déploiement doit réussir, avec un Pod `1/1 Running` et un Service `nginx` de type `ClusterIP` sur le port 80. L’adresse `ClusterIP` est interne au cluster.

Depuis la racine du dépôt, on peut également appliquer la configuration versionnée :

```text
minikube -p infra-si kubectl -- apply -f ateliers/a5-nginx-minikube/nginx.yaml
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
minikube -p infra-si kubectl -- get pods,services
```

Si les ressources ont déjà été créées avec les commandes précédentes, `apply` peut répondre `unchanged` ou les mettre à jour. Sur un nouveau cluster, il les crée.

## Vérifier depuis le navigateur

Dans un terminal du poste hôte, lancer et **laisser cette commande active** :

```text
minikube -p infra-si kubectl -- port-forward service/nginx 8090:80
```

Ouvrir ensuite `http://127.0.0.1:8090` dans le navigateur du même poste. La page **Welcome to nginx!** doit s’afficher. Arrêter le transfert avec `Ctrl + C`.

## Observer le remplacement d’un Pod

Afficher le nom actuel du Pod :

```text
minikube -p infra-si kubectl -- get pods
```

Remplacer `<NOM_DU_POD>` par le nom réellement affiché, puis lancer :

```text
minikube -p infra-si kubectl -- delete pod <NOM_DU_POD>
minikube -p infra-si kubectl -- get pods
```

Le Pod supprimé disparaît et un nouveau Pod prend sa place. Attendre quelques secondes et relancer `get pods` si le nouveau Pod n’est pas encore `1/1 Running`.

Lors de notre vérification, `nginx-5544cc46b7-9pd5p` a été supprimé et `nginx-5544cc46b7-24gts` l’a remplacé en état `1/1 Running`. Les suffixes changent à chaque exécution. L’application du manifeste a ensuite donné un Pod `nginx-54cdc5445b-n2scz`, également `1/1 Running`.

## Nettoyer

Arrêter le `port-forward` avec `Ctrl + C` s’il fonctionne encore, puis supprimer **uniquement ce profil de laboratoire** :

```text
minikube delete -p infra-si
```

Cette commande détruit le cluster `infra-si` et les ressources qu’il contient. Le manifeste `nginx.yaml` permet de les recréer ; les autres profils Minikube, Docker Desktop et les fichiers du dépôt ne sont pas supprimés.