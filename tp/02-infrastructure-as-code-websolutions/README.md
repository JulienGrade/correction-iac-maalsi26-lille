# WebSolutions Inc. — infrastructure et livraison

Ce TP fait tourner une petite API Node.js avec PostgreSQL derrière Nginx. OpenTofu décrit les conteneurs, le réseau et le volume de données ; Ansible maintient la configuration de la VM. GitHub Actions teste l’application et produit une image identifiée par le commit. Le déploiement sur la VM se lance depuis le poste qui peut y accéder.

## Ressources

Voici les documents que j’ai utilisés pour construire et vérifier le TP :

- [OpenTofu : planifier les changements](https://opentofu.org/docs/v1.11/cli/commands/plan/) et [comprendre les variables](https://opentofu.org/docs/v1.11/language/values/variables/) ;
- [Docker : utiliser un contexte distant](https://docs.docker.com/engine/manage-resources/contexts/) et [accéder au moteur par SSH](https://docs.docker.com/engine/security/protect-access/) ;
- [Ansible : vérifier un playbook avec `--check` et `--diff`](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html) ;
- [GitHub Actions : partager un artefact entre étapes de livraison](https://docs.github.com/en/actions/tutorials/store-and-share-data) ;
- [GitHub CLI : attendre un run](https://cli.github.com/manual/gh_run_watch) et [télécharger son artefact](https://cli.github.com/manual/gh_run_download).

## Ce qui tourne dans le laboratoire

Sur la VM Ubuntu, `websolutions-web` écoute sur `192.168.56.20:8081`. Il transmet les requêtes à `websolutions-api`, qui interroge `websolutions-db`. L’API et PostgreSQL ne publient pas de port sur l’hôte. Le réseau Docker `websolutions-net` relie les trois conteneurs ; `websolutions-db-data` conserve les données PostgreSQL.

La machine utilisée ici est un Mac Intel. La cible est une VM Ubuntu 24.04 sous VirtualBox, accessible par SSH à `julien@192.168.56.20`. Adaptez l’adresse, le nom d’utilisateur et le chemin de configuration à votre propre VM.

Sous Windows, utilisez une VM Ubuntu joignable depuis le poste, Docker Desktop et WSL2 pour les commandes OpenTofu, Ansible, `gh` et le script Bash. Vérifiez d’abord depuis WSL2 que `ssh utilisateur@adresse-de-la-vm` fonctionne : l’adresse host-only de cet exemple dépend de la configuration VirtualBox et peut être différente chez vous.

## Les fichiers

- `app/` contient l’API, ses trois tests et son Dockerfile.
- `infra/` décrit le réseau, les images, les conteneurs, le volume et les sorties OpenTofu.
- `ansible/` contient l’inventaire, le playbook et la configuration Nginx attendue.
- `.github/workflows/websolutions-ci.yml`, à la racine du dépôt, teste et archive l’image.
- `deploy-successful-run.sh` relie un run GitHub réussi au déploiement local et à la vérification HTTP.

Les fichiers `terraform.tfvars`, `release.auto.tfvars`, les plans et l’état OpenTofu restent sur le poste et hors de Git. Ne publiez pas le mot de passe PostgreSQL ou un fichier d’état. Le fichier `.terraform.lock.hcl`, lui, est versionné.

## Préparer la cible

Installez Docker Engine et SSH dans la VM. Depuis le poste de contrôle, vérifiez la connexion SSH, puis créez le contexte Docker :

```bash
docker context create websolutions-vm \
  --docker "host=ssh://julien@192.168.56.20"
docker --context websolutions-vm info --format '{{.ServerVersion}}'
```

Au premier démarrage, le fichier Nginx doit déjà exister **sur la VM** avant la création du conteneur web, car OpenTofu monte son dossier dans ce conteneur. Depuis la racine du dépôt, copiez la configuration, puis installez-la dans son dossier :

```bash
scp tp/02-infrastructure-as-code-websolutions/ansible/files/websolutions.conf \
  julien@192.168.56.20:~/websolutions.conf
ssh julien@192.168.56.20 \
  'sudo install -d -m 0755 /home/julien/websolutions/nginx-conf && sudo install -m 0644 ~/websolutions.conf /home/julien/websolutions/nginx-conf/default.conf'
```

Sur un autre poste, remplacez aussi le chemin `/home/julien/...` dans les variables OpenTofu et dans le playbook Ansible. Une fois le conteneur web lancé, Ansible devient la source de vérité pour ce fichier.

## Premier provisionnement

Dans le dossier `tp/02-infrastructure-as-code-websolutions/infra`, créez `terraform.tfvars` à partir de `terraform.tfvars.example`. Renseignez votre contexte Docker, l’image API disponible **sur la VM**, l’adresse de la VM, le dossier Nginx et un mot de passe PostgreSQL local. Pour préparer l’image API sur cette VM, depuis la racine du dépôt :

```bash
docker --context websolutions-vm build -t websolutions-api:1.0.0 \
  ./tp/02-infrastructure-as-code-websolutions/app
docker --context websolutions-vm run --rm websolutions-api:1.0.0 npm test
docker --context websolutions-vm image inspect \
  --format '{{.Id}}' websolutions-api:1.0.0
```

Reportez l’identifiant `sha256:...` obtenu dans `api_image_id`. Depuis `infra`, vérifiez puis appliquez le plan :

```bash
tofu init
tofu fmt -check
tofu validate
tofu plan -out=infra.tfplan
tofu show infra.tfplan
tofu apply infra.tfplan
tofu output
tofu plan
```

Relisez toujours le plan avant l’application. Sur ce laboratoire, le premier plan créait sept ressources : trois conteneurs, deux images, un réseau et un volume. Le plan suivant ne prévoyait aucun changement.

## Maintenir la configuration

Depuis la racine du dépôt, lancez Ansible sur la VM :

```bash
ansible-playbook \
  -i tp/02-infrastructure-as-code-websolutions/ansible/inventory.ini \
  tp/02-infrastructure-as-code-websolutions/ansible/configure.yml -K
```

Une seconde exécution doit afficher `changed=0`. Nous avons aussi modifié temporairement `proxy_read_timeout` dans le fichier **sur la VM** : `--check --diff` a montré le retour prévu de `6s` vers `5s`, puis l’application du playbook a rétabli `5s`.

```bash
ansible-playbook \
  -i tp/02-infrastructure-as-code-websolutions/ansible/inventory.ini \
  tp/02-infrastructure-as-code-websolutions/ansible/configure.yml \
  -K --check --diff
```

## Livrer une version testée

GitHub Actions construit `websolutions-api:<SHA du commit>`, exécute les tests et ne publie `websolutions-image.tar.gz` que si les tests passent. Le run `44507810414`, déclenché avec `fail_test=true`, a échoué : deux tests réussis, un test de version échoué, aucun artefact livré. La version déjà en service est restée accessible.

Depuis la racine du dépôt, déclenchez ensuite un run normal, relevez **son numéro** dans la réponse de `gh`, puis lancez le script local avec ce numéro :

```bash
gh workflow run websolutions-ci.yml --ref main -f fail_test=false
bash tp/02-infrastructure-as-code-websolutions/deploy-successful-run.sh NUMERO_DU_RUN
```

Le script attend la réussite de la CI, récupère l’image du commit testé, la charge sur la VM, remplace uniquement le conteneur API avec OpenTofu, relance Ansible et contrôle `/health`. Il refuse un plan qui modifierait aussi la base, le réseau ou le volume. Le run GitHub s’exécute sur un runner hébergé ; **le déploiement se fait sur le Mac**, qui peut atteindre la VM privée. Il faut conserver le dossier `infra` et son état local entre les livraisons.

La livraison manuelle du run réussi `44509476386` a déployé le commit `4f35e372c908b50b99c0607cd37a4ceefaafbdca`. Le contrôle obtenu était :

```json
{"status":"ok","database":"ok","version":"4f35e372c908b50b99c0607cd37a4ceefaafbdca"}
```

`tofu plan` a ensuite indiqué `No changes` et Ansible `changed=0`. Le script a également été essayé avec le run en échec : il s’est arrêté avant le déploiement, et `/health` affichait encore ce même commit.

## Revenir à la version précédente

Conservez l’identifiant de l’image précédente et sa version avant chaque livraison. Pour revenir à cette version, remettez ces **deux** valeurs dans `infra/release.auto.tfvars`, puis, depuis `infra`, lancez `tofu plan -out=rollback.tfplan`. Vérifiez que le plan remplace seulement `docker_container.api`, appliquez-le avec `tofu apply rollback.tfplan` et contrôlez `/health`. Le volume PostgreSQL ne doit pas être détruit par ce retour arrière applicatif.

Ce retour arrière concerne l’application. Si une version modifie le schéma de la base, il faut prévoir séparément la compatibilité des migrations et une sauvegarde.

## Ce que montre le TP, et ses limites

Les plans OpenTofu montrent les changements avant application. La deuxième exécution d’Ansible et le plan sans changement montrent que l’état reste stable. Le test en échec bloque la livraison ; le run réussi produit une image identifiée et la route de santé indique la version réellement servie.

Le laboratoire utilise une seule VM et un état OpenTofu local. Pour un environnement partagé ou de production, il faudrait notamment gérer l’état de manière partagée, stocker les secrets dans un gestionnaire adapté, automatiser les sauvegardes et rendre le déploiement plus tolérant à l’interruption momentanée de l’API.

## Arrêter le laboratoire

Le volume `websolutions-db-data` contient la base. Avant tout nettoyage, décidez s’il faut conserver ou sauvegarder ces données. Depuis `infra`, `tofu plan -destroy -out=destroy.tfplan` permet de **prévisualiser** les suppressions ; cette commande seule ne détruit rien. Ne lancez `tofu apply destroy.tfplan` qu’après avoir relu le plan et accepté la suppression du volume et de ses données. Ne supprimez pas les fichiers d’état pour « nettoyer » : ils permettent à OpenTofu de suivre les ressources existantes.