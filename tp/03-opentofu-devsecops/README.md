# Plateforme DevSecOps locale avec OpenTofu

Ce TP déploie sur Docker Desktop quatre services reliés par un réseau Docker : Gitea pour les dépôts Git, Jenkins pour l’intégration continue, SonarQube pour l’analyse de code et PostgreSQL pour la base de SonarQube. OpenTofu gère aussi leurs volumes persistants. Gitea utilise sa propre base SQLite.

## Ressources

- [Documentation OpenTofu : initialisation et commandes](https://opentofu.org/docs/cli/commands/)
- [Documentation OpenTofu : plans enregistrés](https://opentofu.org/docs/cli/commands/plan/)
- [Documentation du fournisseur Docker pour OpenTofu](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [Gitea : installation avec Docker](https://docs.gitea.com/installation/install-with-docker/)
- [Jenkins : installation avec Docker](https://www.jenkins.io/doc/book/installing/docker/)
- [SonarQube Community Build : installation avec Docker](https://docs.sonarsource.com/sonarqube-community-build/server-installation/from-docker-image/installation-overview)
- [SonarQube Community Build : prérequis Linux](https://docs.sonarsource.com/sonarqube-community-build/server-installation/pre-installation/linux)

## Prérequis

Il faut Docker Desktop avec les conteneurs Linux, OpenTofu et suffisamment de mémoire pour exécuter les quatre services. Le sujet recommande environ 8 Go pour le moteur Docker. Les ports `3000`, `5432`, `8080` et `9000` doivent être libres.

Sur macOS, le contexte utilisé dans cet atelier est `desktop-linux`. Dans un terminal :

```bash
docker context show
export DOCKER_CONTEXT=desktop-linux
```

Sous Windows avec PowerShell, vérifier le contexte Docker disponible, puis, si son nom est `desktop-linux` :

```powershell
docker context show
$env:DOCKER_CONTEXT = "desktop-linux"
```

SonarQube demande notamment `vm.max_map_count` à `524288` ou plus et `fs.file-max` à `131072` ou plus sur le Linux qui exécute Docker. On peut contrôler les valeurs visibles par les conteneurs avec :

```bash
docker run --rm alpine:3.22 cat /proc/sys/vm/max_map_count /proc/sys/fs/file-max
```

Sur le Docker Desktop utilisé pour ce TP, `vm.max_map_count` était initialement à `262144`. Il a été ajusté ainsi :

```bash
docker run --rm --privileged alpine:3.22 sysctl -w vm.max_map_count=524288
```

La seconde vérification a affiché `524288` et `9223372036854775807`. Après un redémarrage de Docker Desktop, vérifier à nouveau ces valeurs : l’ajustement peut devoir être refait.

## Déploiement

Les fichiers `versions.tf` et `main.tf` décrivent le réseau, les quatre images, les quatre conteneurs et six volumes. La version `3.9.0` du fournisseur Docker est utilisée : l’installation de la version `3.6.1` indiquée dans le sujet échouait ici lors de la vérification de sa signature.

Depuis ce dossier :

```bash
tofu init
tofu fmt
tofu validate
tofu plan -out=devops.tfplan
tofu show devops.tfplan
tofu apply devops.tfplan
docker ps -a --filter name=devops-
```

Le premier plan prévoyait **15 créations, aucune modification et aucune destruction**. L’application du plan a créé ces 15 ressources.

## Accès et vérifications

| Service | Adresse locale | Vérification réalisée |
| --- | --- | --- |
| Gitea | http://localhost:3000 | Installation avec SQLite, création du premier compte et d’un dépôt privé de test |
| Jenkins | http://localhost:8080 | Installation des plugins suggérés, création du compte administrateur et accès au tableau de bord |
| SonarQube | http://localhost:9000 | Connexion après initialisation et changement du mot de passe administrateur |
| PostgreSQL | `127.0.0.1:5432` | Conteneur sain et réponse de `pg_isready` |

Pour récupérer le mot de passe **initial** de Jenkins pendant son installation, sans l’ajouter au dépôt :

```bash
docker exec devops-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Pour contrôler SonarQube et sa base :

```bash
curl -fsS http://localhost:9000/api/system/status
docker exec devops-postgres pg_isready -h 127.0.0.1 -U sonar -d sonar
docker logs --tail 60 devops-sonar
tofu plan
```

L’API de SonarQube a renvoyé `status: UP`, PostgreSQL a accepté les connexions et le nouveau `tofu plan` a indiqué **No changes**. Après un redémarrage du conteneur Gitea, le dépôt de test et son `README.md` étaient toujours présents : les données ont bien été conservées dans le volume.

Les ports publiés sont liés à `127.0.0.1` et sont accessibles depuis le poste local.

## Images utilisées

Les digests relevés avec `docker image inspect` permettent d’identifier précisément les images téléchargées pendant cet essai. Les tags du fichier OpenTofu peuvent pointer vers d’autres versions lors d’un téléchargement ultérieur.

| Image | Digest constaté |
| --- | --- |
| `postgres:16-alpine` | `sha256:81e77a4833487b8132fe4b00bedd39dc3f74b8641e387f19312a48f7de218c2e` |
| `gitea/gitea:1.25` | `sha256:f846d26a4fc389c5806a580a765e00bfdd1fd181e6f2060da98ea2669d914472` |
| `jenkins/jenkins:lts-jdk21` | `sha256:74401de6a6f92e1afe1b02d1c8e3d0c33f263bfb5275dd8813f9150355f2367b` |
| `sonarqube:community` | `sha256:65541accbdb92e27fe770fc6ba99988a3dd5a0c71ffafd67f88abfad366996fa` |

## Arrêt et nettoyage

Pour libérer la mémoire et les ports tout en conservant les données du TP :

```bash
docker stop devops-sonar devops-jenkins devops-gitea devops-postgres
```

Cet arrêt manuel crée un écart avec l’état souhaité par OpenTofu, puisque les conteneurs y sont déclarés démarrés. Pour les relancer sans détruire les volumes :

```bash
docker start devops-postgres devops-gitea devops-jenkins devops-sonar
```

Pour préparer une suppression complète, examiner d’abord le plan :

```bash
tofu plan -destroy -out=devops-destroy.tfplan
tofu show devops-destroy.tfplan
```

**Attention :** ce plan inclut les volumes gérés par OpenTofu et donc les données de Gitea, Jenkins, SonarQube et PostgreSQL. Sauvegarder ce qui doit être conservé avant de l’appliquer.

Le dépôt Git conserve les fichiers `.tf`, ce README et `.terraform.lock.hcl`. Les états OpenTofu, les plans et les mots de passe d’administration restent hors du dépôt.