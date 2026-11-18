# Nginx géré par OpenTofu

Le fichier [`tofu-nginx/main.tf`](tofu-nginx/main.tf) décrit une image Nginx, un conteneur Docker et l’URL locale du service. OpenTofu permet d’examiner les changements avant de les appliquer, puis de retirer les ressources avec un plan de destruction relu de la même façon.

## Préparer le poste

Installer OpenTofu et démarrer le moteur Docker. Sur macOS, le cours propose `brew install opentofu` ; sur Windows, `winget install --exact --id=OpenTofu.Tofu`. Vérifier dans le terminal utilisé :

```text
tofu version
docker version
```

`docker version` doit afficher un **Client** et un **Server**. Depuis la racine du dépôt, entrer dans le dossier du projet :

```text
cd ateliers/b1-nginx-opentofu/tofu-nginx
```

Le fournisseur Docker est fixé à la version **3.9.0** dans `main.tf`. La version **3.6.1** indiquée dans le support a échoué à la vérification de signature avec OpenTofu 1.11.2 sur notre Mac (`authentication signature from unknown issuer`). La version 3.9.0 s’est installée avec une signature reconnue. Conserver le fichier `.terraform.lock.hcl` dans Git pour retrouver cette sélection.

## Indiquer le contexte Docker si nécessaire

Sur notre installation macOS, la commande `docker` utilisait le contexte `desktop-linux` et le socket `~/.docker/run/docker.sock`. Le fournisseur OpenTofu essayait par défaut `/var/run/docker.sock`, ce qui faisait échouer `tofu apply` alors que `docker version` fonctionnait.

Dans **le même terminal que les commandes OpenTofu**, sélectionner le contexte Docker Desktop :

```bash
# Terminal macOS
export DOCKER_CONTEXT=desktop-linux
```

Dans **PowerShell sous Windows**, si Docker Desktop utilise aussi `desktop-linux` :

```powershell
$env:DOCKER_CONTEXT = "desktop-linux"
```

Vérifier le nom réel avec `docker context show` et l’utiliser s’il diffère. Cette variable ne vaut que pour la session du terminal ; la définir à nouveau après l’ouverture d’un autre terminal. Elle évite de placer un chemin de socket propre à une machine dans `main.tf`.

## Examiner puis appliquer

Depuis `tofu-nginx` :

```text
tofu init
tofu fmt
tofu validate
tofu plan -out=nginx.tfplan
tofu show nginx.tfplan
```

Le plan doit annoncer **2 créations, 0 modification, 0 suppression** : l’image `nginx:1.28-alpine` et le conteneur `infra-si-nginx`, publié uniquement sur `127.0.0.1:8080`. Relire le plan avant de lancer :

```text
tofu apply nginx.tfplan
tofu output nginx_url
docker ps --filter name=infra-si-nginx
tofu state list
tofu plan
```

La sortie doit donner `http://127.0.0.1:8080`. Cette URL doit afficher la page **Welcome to nginx!** dans le navigateur. `tofu state list` doit montrer `docker_image.nginx` et `docker_container.nginx`. Un second `tofu plan` doit indiquer **No changes**.

Si l’application échoue, diagnostiquer l’erreur avant de réutiliser un plan enregistré. Après une correction, produire et relire un nouveau plan.

## Retirer les ressources

Préparer et relire le plan de destruction :

```text
tofu plan -destroy -out=nginx-destroy.tfplan
tofu show nginx-destroy.tfplan
```

Le résumé attendu est **0 création, 0 modification, 2 suppressions**, limité aux ressources de ce dossier. Après cette vérification :

```text
tofu apply nginx-destroy.tfplan
docker ps -a --filter name=infra-si-nginx
docker image ls nginx:1.28-alpine
tofu state list
```

Le conteneur doit avoir disparu et l’état ne doit plus lister de ressource. L’image reste dans le cache Docker grâce à `keep_locally = true`.

Conserver le fichier d’état local tant que des ressources sont gérées ; ne jamais le supprimer pour « nettoyer » une infrastructure encore active. Les fichiers `terraform.tfstate`, `.terraform/` et `*.tfplan` restent hors du dépôt public. `main.tf` et `.terraform.lock.hcl` sont versionnés.