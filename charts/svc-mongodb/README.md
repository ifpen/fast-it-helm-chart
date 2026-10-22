# svc-mongodb

Déploie une base **MongoDB gérée par le [MongoDB Community Operator](https://github.com/mongodb/mongodb-kubernetes-operator)**, une interface d'administration **Mongo Express**, un job d'initialisation de la base applicative et, en option, la supervision Prometheus. Il est utilisé par le meta-chart [`webapp`](../webapp) sous l'alias `mongodb`.

## Prérequis

- Le **MongoDB Community Operator** installé dans le cluster (CRD `mongodbcommunity.mongodbcommunity.mongodb.com`) et autorisé à gérer le namespace de la release.
- Le **Prometheus Operator** (CRD `servicemonitors.monitoring.coreos.com`) si `monit.enabled` est à `true`, ce qui est le cas par défaut.

## Ce qui est déployé

Deux préfixes de nom coexistent :

- `<cluster>` vaut `<release>-mongo` : la base et ce qui s'y rattache. Il dépend **uniquement du nom de release**, pas de `nameOverride` ni de `fullnameOverride`.
- `<fullname>` vaut `<release>-svc-mongodb` (ou `<release>-mongodb` sous `webapp`, ou `fullnameOverride`) : Mongo Express.

### Base MongoDB

| Ressource | Nom | Condition |
|---|---|---|
| MongoDBCommunity | `<cluster>` | toujours |
| Secret du mot de passe administrateur | `<cluster>` | `cluster.database.createSecret: true` |
| Job d'initialisation | `<cluster>-init-db` | **première installation uniquement** |
| ConfigMap du script d'initialisation | `<cluster>-init-script` | `cluster.init.createConfigmap: true` |
| ConfigMap / Secret d'environnement du job | `<cluster>-init-env` / `<cluster>-init-env-sec` | `cluster.init.env.*` |
| ServiceAccounts de l'opérateur | `mongodb-kubernetes-appdb`, `mongodb-kubernetes-database-pods`, `mongodb-kubernetes-ops-manager` | toujours |
| Role + RoleBinding | `mongodb-kubernetes-appdb` | toujours |

La ressource MongoDBCommunity décrit un **replica set à 1 membre**, MongoDB `cluster.version`, authentification SCRAM, avec un utilisateur `cluster.database.user` dans la base `admin`. Ses rôles : `clusterAdmin`, `userAdminAnyDatabase`, `readWriteAnyDatabase`, `dbAdminAnyDatabase`, plus `readWrite` et `dbAdmin` sur la base `<cluster>`.

L'opérateur crée les pods MongoDB et le Service **`<cluster>-svc`** (port **27017**), qui sert de point de connexion.

Le **job d'initialisation** (image `mongo:7.0.25`) attend que le primaire réponde, puis exécute `init.js`. Ce script crée la base `<cluster>` avec une collection `__init__`, et un utilisateur `cluster.database.user` ayant le rôle `readWrite` sur cette base.

### Mongo Express

| Ressource | Nom | Condition |
|---|---|---|
| Deployment Mongo Express | `<fullname>` | toujours |
| Service | `<fullname>` | toujours |
| ConfigMap (authentification basique + variables) | `<cluster>-mongoexpress-env` | `mongoExpress.env.config.createConfigMap: true` |
| Secret (mot de passe + chaîne de connexion) | `<cluster>-mongoexpress-env-sec` | `mongoExpress.env.secret.createSecret: true` |
| ServiceAccount | `<fullname>` | `serviceAccount.create: true` |
| Ingress | `<fullname>` | `ingress.enabled: true` (**activé par défaut**) |
| HorizontalPodAutoscaler | `<fullname>` | `autoscaling.enabled: true` |

Mongo Express est protégé par une authentification basique (`mongoExpress.username` / `mongoExpress.password`) et se connecte à la base avec l'utilisateur administrateur, via `mongodb+srv://…@<cluster>-svc.<namespace>.svc.<global.clusterDomain>`.

### Supervision

| Ressource | Nom | Condition |
|---|---|---|
| Secret des identifiants Prometheus | `<cluster>-prom-pass` | `monit.enabled` et `monit.createSecret` |
| ServiceMonitor | `<cluster>-sm` | `monit.enabled: true` |

L'endpoint Prometheus de MongoDB est activé sur la ressource MongoDBCommunity et protégé par `monit.promUsername` / `monit.promPassword`.

## Configuration

### Base de données

| Clé | Défaut | Description |
|---|---|---|
| `cluster.version` | `7.0.25` | Version de MongoDB. |
| `cluster.featureCompatibilityVersion` | `7.0` | |
| `cluster.additionalMongodConfig` | `{}` | Configuration `mongod` supplémentaire. |
| `cluster.database.user` | `db-user` | Utilisateur administrateur. |
| `cluster.database.password` | `CHANGEME123!` | **À changer.** |
| `cluster.database.createSecret` | `true` | Crée le Secret `<cluster>` (clé `password`). Mettre `false` pour fournir un Secret existant portant ce nom. |
| `cluster.init.createConfigmap` | `true` | Crée le script `init.js`. |
| `cluster.init.env.config.values` / `cluster.init.env.secret.values` | `{}` | Variables supplémentaires du job d'initialisation. |
| `global.clusterDomain` | `cluster.local` | Domaine DNS interne du cluster. |

### Mongo Express

| Clé | Défaut | Description |
|---|---|---|
| `image.repository` | `docker.io/mongo-express` | |
| `image.tag` | `""` | Vide : `appVersion` du chart (`1`). |
| `mongoExpress.username` | `mongo-express-user` | Identifiant de l'authentification basique. |
| `mongoExpress.password` | `CHANGEM3PLE4SE!!` | **À changer.** |
| `mongoExpress.env.config.values` / `mongoExpress.env.secret.values` | `{}` | Variables `ME_CONFIG_*` supplémentaires. |
| `service.port` | `8081` | Port du Service et du conteneur. |
| `resources.requests` | `cpu: 100m`, `memory: 256Mi` | |
| `resources.limits` | `cpu: 500m`, `memory: 512Mi` | |
| `livenessProbe` / `readinessProbe` | `GET /status`, délai initial 60 s | |

### Exposition de Mongo Express

| Clé | Défaut | Description |
|---|---|---|
| `ingress.enabled` | `true` | |
| `ingress.auto` | `true` | Hôte `<fullname><suffixe>.<domaine>`. |
| `global.domain` | `example.com` | **À surcharger** (ou utiliser `ingress.autoTld`). |
| `global.environment` | `""` | Suffixe `-<environnement>` de l'hôte (aucun pour `prod`, voir `global.environmentsWithoutSuffix`). |
| `ingress.autoNameSuffix` | `""` | Suffixe explicite, prioritaire sur `global.environment`. |

Les autres clés (`ingress.className`, `annotations`, `hosts`, `tls`) et les clés de pod (`serviceAccount`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `volumes`, `volumeMounts`, `nodeSelector`, `tolerations`, `affinity`, `autoscaling`) fonctionnent comme dans [`webcomponent`](../webcomponent/README.md).

### Supervision

| Clé | Défaut | Description |
|---|---|---|
| `monit.enabled` | `true` | Active l'endpoint Prometheus et le ServiceMonitor. |
| `monit.createSecret` | `true` | Crée le Secret `<cluster>-prom-pass`. |
| `monit.promUsername` / `monit.promPassword` | `promUsername` / `promPassword` | **À changer.** |

## Points d'attention

- **Une seule release par namespace.** Les ServiceAccounts, le Role et le RoleBinding `mongodb-kubernetes-*` ont des noms fixes : une deuxième release dans le même namespace échoue, car Helm refuse d'adopter des ressources appartenant à une autre release.
- **Le job d'initialisation ne s'exécute qu'à l'installation** (`.Release.IsInstall`). Un changement d'utilisateur ou de mot de passe après coup n'est pas répercuté par le job.
- **Mongo Express est exposé par défaut**, sur `global.domain` qui vaut `example.com`. Pensez à surcharger le domaine, ou désactivez l'Ingress.
- Le nombre de membres du replica set est fixé à 1 dans le template.
- `monit.promPassword` est inséré sans guillemets dans le Secret : évitez les caractères spéciaux YAML (`:`, `#`, `{`…) ou fournissez votre propre Secret avec `monit.createSecret: false`.
- **Changez tous les mots de passe par défaut** avant un usage en production.
