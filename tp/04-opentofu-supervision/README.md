# Supervision locale avec OpenTofu

Ce TP déploie une application Node.js et une plateforme de supervision locale. Prometheus collecte le compteur de requêtes HTTP, Alloy transmet le journal de l’application à Loki et Grafana permet de consulter les deux sources.

## Ressources

- [OpenTofu : commandes et déroulement d’un déploiement](https://opentofu.org/docs/cli/commands/)
- [Fournisseur Docker pour OpenTofu](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [Prometheus : prise en main](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [Prometheus : configuration des cibles](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Loki : exemple de configuration avec stockage local](https://grafana.com/docs/loki/latest/configure/examples/configuration-examples/)
- [Alloy : lecture des journaux d’un fichier](https://grafana.com/docs/alloy/latest/monitor/monitor-logs-from-file/)
- [Grafana : configurer Prometheus](https://grafana.com/docs/grafana/latest/datasources/prometheus/configure/)
- [Grafana : configurer Loki](https://grafana.com/docs/grafana/latest/datasources/loki/configure/)
- [Grafana : créer un tableau de bord](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/create-dashboard/)

## Services

| Service | Rôle | Adresse sur le poste |
| --- | --- | --- |
| Application Node.js | Réponses HTTP, compteur et journal | http://localhost:8080 |
| Prometheus | Collecte des métriques | http://localhost:9090 |
| Grafana | Consultation des métriques et journaux | http://localhost:3000 |
| Loki | Stockage des journaux | http://localhost:3100 |
| Alloy | Lecture du journal et envoi à Loki | Aucun port publié |

Les cinq conteneurs communiquent sur le réseau Docker `monitoring-net`. Le volume `monitoring-app_logs` est partagé entre Node.js, qui écrit le fichier `/logs/http.log`, et Alloy, qui le lit. Les autres volumes conservent les données de Prometheus, Grafana, Loki et Alloy.

## Prérequis et déploiement

Docker Desktop doit fonctionner en mode conteneurs Linux et OpenTofu doit être installé. Les ports `3000`, `8080`, `9090` et `3100` doivent être disponibles. La plateforme DevSecOps du TP précédent a été arrêtée pour libérer notamment le port `3000` et la mémoire.

Sur le Mac utilisé pour ce TP, le contexte Docker est `desktop-linux` :

```bash
docker context show
export DOCKER_CONTEXT=desktop-linux
```

Sous Windows avec PowerShell, si le contexte disponible porte aussi ce nom :

```powershell
docker context show
$env:DOCKER_CONTEXT = "desktop-linux"
```

Depuis ce dossier :

```bash
tofu init
tofu fmt
tofu validate
tofu plan -out=monitoring.tfplan
tofu show monitoring.tfplan
tofu apply monitoring.tfplan
docker ps -a --filter name=monitoring-
```

Le plan prévoyait **16 créations, aucune modification et aucune destruction** : cinq images, cinq conteneurs, cinq volumes et un réseau. L’application du plan a créé les 16 ressources. Les cinq conteneurs ont ensuite été observés à l’état `Up`.

Les fichiers `app.js`, `prometheus.yml`, `loki.yaml` et `config.alloy` sont montés dans les conteneurs depuis ce dossier. Celui-ci doit donc être accessible au moteur Docker.

## Vérifier les métriques

L’application expose son compteur à `/metrics`. Cette route n’incrémente pas le compteur ; une requête vers `/` ou une autre route l’incrémente et écrit une ligne dans le journal.

```bash
curl -fsS http://localhost:8080/
curl -fsS http://localhost:8080/metrics
```

Prometheus collecte la cible `node:8080` toutes les cinq secondes. La cible peut être consultée sur http://localhost:9090/targets ou avec :

```bash
curl -fsS 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22node%22%7D'
```

Le résultat observé pour `up{job="node"}` est `1`. Dans Grafana Explore, les requêtes `up{job="node"}` et `http_requests_total` affichent des données. Un panneau **Requêtes HTTP totales** a été ajouté au tableau de bord **Supervision Node.js**.

## Vérifier les journaux

Loki répond `ready` sur http://localhost:3100/ready. Lors de la première vérification, cette route renvoyait temporairement `503` pendant le démarrage ; une vérification ultérieure a renvoyé `200 OK`.

Dans Grafana, les deux sources de données ont été ajoutées et testées :

| Source | URL à saisir dans Grafana |
| --- | --- |
| Prometheus | `http://prometheus:9090` |
| Loki | `http://loki:3100` |

Ces noms sont résolus sur le réseau Docker commun. Dans **Explore**, la requête Loki `{job="node"}` affiche les journaux de l’application sur une période récente.

La vérification a produit deux premières réponses `200`, puis une réponse `200` et une réponse `404` :

```bash
curl -fsS http://localhost:8080/
curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8080/inconnue
curl -fsS http://localhost:8080/metrics
docker exec monitoring-node tail -n 5 /logs/http.log
```

Après ces quatre requêtes, `http_requests_total` valait `4`. Le journal contenait quatre lignes correspondantes, dont `{"path":"/inconnue","status":404}`. Les nouvelles lignes ont également été retrouvées dans Grafana avec `{job="node"}`.

En cas de journal absent dans Grafana, vérifier successivement le fichier produit par Node.js, Alloy et Loki :

```bash
docker exec monitoring-node tail -n 5 /logs/http.log
docker logs --tail 60 monitoring-alloy
docker logs --tail 60 monitoring-loki
```

## État et nettoyage

Un nouveau `tofu plan` après les vérifications a indiqué qu’aucun changement n’était nécessaire.

Pour arrêter temporairement les conteneurs en conservant les volumes :

```bash
docker stop monitoring-node monitoring-prometheus monitoring-grafana monitoring-loki monitoring-alloy
```

Un arrêt manuel crée un écart avec la configuration OpenTofu, qui attend des conteneurs démarrés. Pour les relancer :

```bash
docker start monitoring-node monitoring-prometheus monitoring-grafana monitoring-loki monitoring-alloy
```

Avant une suppression complète, examiner le plan de destruction :

```bash
tofu plan -destroy -out=monitoring-destroy.tfplan
tofu show monitoring-destroy.tfplan
```

Ce plan inclut les volumes et leurs données, notamment le tableau de bord Grafana et les journaux. Sauvegarder ce qui doit être conservé avant de l’appliquer.

Le dépôt Git contient les fichiers de configuration, le code de l’application, ce README et `.terraform.lock.hcl`. Les états OpenTofu, les plans enregistrés et les mots de passe restent hors du dépôt.