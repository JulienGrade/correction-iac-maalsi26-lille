# La même application avec Docker et Minikube

Ce TP part d’un petit serveur HTTP Node.js. J’ai construit une image, lancé l’application dans un conteneur Docker, puis chargé la même image dans un cluster Minikube. Les fichiers de l’application et le manifeste Kubernetes sont dans `node-docker/`.

## Ressources

Le support de départ est `TP_Docker_et_Minikube.pdf`, pages 2 à 5. Pour comprendre les commandes et les objets utilisés, j’ai consulté ces documentations officielles :

- [Écrire un Dockerfile](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/) : les instructions de construction de l’image.
- [Charger une image dans Minikube](https://minikube.sigs.k8s.io/docs/commands/image/) : la commande `minikube image load`.
- [Accéder à une application avec Minikube](https://minikube.sigs.k8s.io/docs/handbook/accessing/) : le Service `NodePort` et le tunnel maintenu ouvert sur macOS.
- [Les Deployments Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) : la gestion des Pods.
- [Les Services Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/) : l’accès à l’application.
- [Les sondes Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/probes/) : le rôle de `readinessProbe`.

## Essai avec Docker

Node.js n’a pas besoin d’être installé sur le poste : il est fourni par l’image `node:24-alpine`. Avec Docker Desktop démarré, se placer dans `node-docker` :

```bash
docker build -t hello-node:1.0 .
docker run -d --name hello-node -p 127.0.0.1:8080:3000 hello-node:1.0
docker ps --filter name=hello-node
curl -fsS http://127.0.0.1:8080
docker rm -f hello-node
```

Le port 8080 du poste est relié au port 3000 de l’application dans le conteneur. La réponse obtenue était `Hello, Docker and Minikube from Node.js!`. La dernière commande supprime le conteneur de test, mais conserve l’image. Si le port 8080 est occupé, le PDF propose 8081 en adaptant la publication du port et l’URL.

## Essai avec Minikube

Toujours dans `node-docker` :

```bash
minikube start -p intro-docker --driver=docker
minikube -p intro-docker image load hello-node:1.0
minikube -p intro-docker image ls
minikube -p intro-docker kubectl -- apply -f deployment.yaml
minikube -p intro-docker kubectl -- rollout status deployment/hello-node
minikube -p intro-docker kubectl -- get pods,services
minikube -p intro-docker service hello-node --url
```

L’image figurait dans le cluster sous le nom `docker.io/library/hello-node:1.0`. Le Pod était `Running` et `Ready 1/1`. Le Service de type `NodePort` affichait `8080:30007/TCP` : il reçoit sur 8080 et transmet au port 3000 du Pod.

Sur mon Mac, `minikube service --url` a ouvert un tunnel temporaire sur `http://127.0.0.1:58948`. J’ai laissé ce terminal ouvert et testé cette URL depuis un second terminal : elle a renvoyé le même message HTTP que Docker. Le port local du tunnel peut changer à chaque lancement. Si cette commande ne donne pas d’URL utilisable, le PDF propose `minikube -p intro-docker kubectl -- port-forward service/hello-node 8080:8080`.

Avec Docker seul, j’ai publié un port pour accéder au conteneur lancé directement. Avec Kubernetes, le Deployment maintient un Pod dans l’état demandé et le Service donne un point d’accès au Pod. Si le Pod disparaît, le Deployment peut en créer un autre.

## Nettoyage

Après le test, arrêter le tunnel avec `Ctrl+C`, puis, depuis `node-docker` :

```bash
minikube -p intro-docker kubectl -- delete -f deployment.yaml
minikube delete -p intro-docker
```

Ces commandes suppriment les objets Kubernetes et le cluster local de ce TP. Les fichiers du dépôt et l’image `hello-node:1.0` construite dans Docker Desktop restent disponibles. Sur Windows, utiliser Docker Desktop en mode conteneurs Linux ; les commandes peuvent être lancées dans PowerShell ou dans un terminal compatible avec Docker et Minikube.