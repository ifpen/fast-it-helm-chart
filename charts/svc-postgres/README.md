# svc-postgres

Déploie une base **PostgreSQL gérée par [CloudNativePG](https://cloudnative-pg.io/)** et une interface d'administration **pgAdmin 4** préconfigurée pour s'y connecter. Il est utilisé par le meta-chart [`webapp`](../webapp) sous l'alias `postgres`.

## Prérequis

- L'**opérateur CloudNativePG** installé dans le cluster (CRD `clusters.postgresql.cnpg.io`).
- Le **Prometheus Operator** (CRD `podmonitors.monitoring.coreos.com`) si `cluster.monitoring.enabled` est à `true`, ce qui est le cas par défaut.
- Un Secret contenant `servers.json` pour pgAdmin : voir les points d'attention. Le chart `webapp` le crée automatiquement.

## Ce qui est déployé

`<fullname>` vaut `<release>-svc-postgres` (ou `<release>-postgres` sous `webapp`, ou `fullnameOverride`).

### Base PostgreSQL

| Ressource | Nom | Condition |
|---|---|---|
| Cluster CloudNativePG | `<fullname>-cluster` | toujours |
| Secret des identifiants du propriétaire | `database.secret` | `cluster.createSecret: true` |
| PodMonitor | `<fullname>-cluster-podmon` | `cluster.monitoring.enabled: true` |

Le Cluster est initialisé (`bootstrap.initdb`) avec la base `database.name`, appartenant à l'utilisateur `database.owner`, dont le mot de passe est lu dans le Secret `database.secret` (clés `username` et `password`).

L'opérateur crée ensuite les pods PostgreSQL, leurs volumes et les Services d'accès. Les applications se connectent au Service **`<fullname>-cluster-rw`** (primaire, lecture-écriture) sur le port **5432**.

### pgAdmin

| Ressource | Nom | Condition |
|---|---|---|
| Deployment pgAdmin | `<fullname>` | toujours |
| Service | `<fullname>` | toujours |
| ConfigMap (`PGADMIN_DEFAULT_EMAIL` + variables) | `<fullname>-config` | `env.config.createConfigMap: true` |
| Secret (`PGADMIN_DEFAULT_PASSWORD` + variables) | `<fullname>-config-sec` | `env.secret.createSecret: true` |
| ServiceAccount | `<fullname>` | `serviceAccount.create: true` |
| Ingress | `<fullname>` | `ingress.enabled: true` |
| HorizontalPodAutoscaler | `<fullname>` | `autoscaling.enabled: true` |

Le conteneur pgAdmin monte le fichier `/pgadmin4/servers.json` depuis le Secret `<fullname>-serverconfig-sec` (ou `admin.secret`), qui déclare le serveur PostgreSQL à afficher.

## Configuration

### Base de données

| Clé | Défaut | Description |
|---|---|---|
| `version` | `"16"` | Version majeure de PostgreSQL. |
| `cluster.image.repository` | `ghcr.io/cloudnative-pg/postgresql` | |
| `cluster.image.tagSuffix` | `-system-trixie` | Tag final : `<version><tagSuffix>`, par exemple `16-system-trixie`. |
| `cluster.image.tagOverride` | `""` | Tag complet, prioritaire sur la combinaison ci-dessus. |
| `cluster.instances` | `1` | Nombre d'instances (1 primaire + réplicas). |
| `cluster.storage.size` | `80Gi` | Taille du volume de chaque instance. |
| `cluster.monitoring.enabled` | `true` | Crée le PodMonitor. |
| `database.name` | `database` | Base créée à l'initialisation. |
| `database.owner` | `database-owner` | Utilisateur propriétaire de la base. |
| `database.password` | `CHANGEME123!` | Mot de passe du propriétaire. **À changer.** |
| `database.secret` | `setmetonullplease` | Nom du Secret des identifiants. **Obligatoire**, à renommer. |
| `cluster.createSecret` | `true` | Crée ce Secret à partir de `database.owner` et `database.password`. Mettre `false` pour fournir un Secret existant. |

Pour utiliser un Secret géré ailleurs (External Secrets, Sealed Secrets…), il doit contenir les clés `username` et `password` :

```yaml
cluster:
  createSecret: false
database:
  secret: ma-base-identifiants
```

### pgAdmin

| Clé | Défaut | Description |
|---|---|---|
| `image.repository` | `docker.io/dpage/pgadmin4` | |
| `image.tag` | `""` | Vide : `appVersion` du chart (`9`). |
| `admin.email` | `pgadmin-user@mail.example.com` | Identifiant de connexion à pgAdmin. |
| `admin.password` | `CHANGEMET00!` | Mot de passe pgAdmin. **À changer.** |
| `admin.user` | `pgadmin-user` | Non utilisé par les templates. |
| `admin.secret` | `null` | Nom du Secret contenant `servers.json`. Vide : `<fullname>-serverconfig-sec`. |
| `env.config.values` / `env.secret.values` | `{}` | Variables d'environnement pgAdmin supplémentaires (`PGADMIN_CONFIG_*`…). |
| `service.port` | `80` | Port du Service et du conteneur (pgAdmin écoute sur 80 par défaut). |
| `resources.requests` | `cpu: 100m`, `memory: 256Mi` | |
| `resources.limits` | `cpu: 500m`, `memory: 512Mi` | |
| `livenessProbe` / `readinessProbe` | `GET /misc/ping`, délai initial 360 s | pgAdmin est lent au premier démarrage. |

### Exposition de pgAdmin

Identique à [`webcomponent`](../webcomponent/README.md#exposition) : `ingress.enabled` (défaut `false`), `ingress.auto` pour l'hôte `<fullname>.<global.domain>`, `ingress.autoTld`, `ingress.className`, `ingress.annotations`, `ingress.hosts`, `ingress.tls`.

Les autres clés de pod (`serviceAccount`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `volumes`, `volumeMounts`, `nodeSelector`, `tolerations`, `affinity`, `autoscaling`) fonctionnent comme dans `webcomponent`.

## Points d'attention

- **Le Secret `servers.json` n'est pas créé par ce chart.** Utilisé seul, le pod pgAdmin reste bloqué en `ContainerCreating` tant que le Secret `<fullname>-serverconfig-sec` (ou `admin.secret`) n'existe pas. Sous `webapp`, il est généré automatiquement.
- **Changez les mots de passe par défaut** (`database.password`, `admin.password`) et préférez un Secret externe en production.
- Le nom par défaut de `database.secret` (`setmetonullplease`) est un marqueur à remplacer.
- `cluster.initdb.auto`, `service.nameOverride` et `admin.user` sont déclarés mais non utilisés.
- Le PodMonitor est créé par défaut : sans Prometheus Operator, l'installation échoue. Désactivez-le avec `cluster.monitoring.enabled: false`.
