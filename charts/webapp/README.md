# webapp

Meta-chart qui assemble une **application web complète** à partir des autres charts du dépôt :

| Alias | Chart | Rôle | Activé par défaut |
|---|---|---|---|
| `back` | [`webcomponent`](../webcomponent) | API / back-end | oui |
| `front` | [`webcomponent`](../webcomponent) | front-end | non (`front.enabled`) |
| `postgres` | [`svc-postgres`](../svc-postgres) | PostgreSQL (CloudNativePG) + pgAdmin | non (`postgres.enabled`) |
| `mongodb` | [`svc-mongodb`](../svc-mongodb) | MongoDB (Community Operator) + Mongo Express | non (`mongodb.enabled`) |

Son intérêt principal : il **câble automatiquement** les composants entre eux. Le back reçoit en variables d'environnement l'adresse et les identifiants des bases activées, et le front reçoit l'URL du back.

```bash
helm repo add fastit https://ifpen.github.io/fast-it-helm-chart
helm install monapp fastit/webapp -f values-monapp.yaml
```

```yaml
# values-monapp.yaml
global:
  domain: apps.example.com

back:
  image:
    repository: registry.example.com/monapp-back
    tag: 1.0.0
  env:
    config:
      values:
        LOG_LEVEL: info

front:
  enabled: true
  image:
    repository: registry.example.com/monapp-front
    tag: 1.0.0
  service:
    port: 80

postgres:
  enabled: true
  database:
    password: un-vrai-mot-de-passe
  admin:
    password: un-autre-mot-de-passe
```

## Prérequis

Ceux des sous-charts activés : l'opérateur **CloudNativePG** pour `postgres`, le **MongoDB Community Operator** pour `mongodb`, et le **Prometheus Operator** si leur supervision reste activée. Pour `webapp.ciliumNetworkPolicy`, il faut **Cilium**.

## Ce qui est déployé

Sous `webapp`, chaque sous-chart prend le nom de son alias. Pour une release `monapp` :

| Composant | Ressources principales | Hôte de l'Ingress automatique |
|---|---|---|
| back | Deployment / Service `monapp-back` | `monapp-back.<global.domain>` |
| front | Deployment / Service `monapp-front` | `monapp-front.<global.domain>` |
| postgres | Cluster CNPG `monapp-postgres-cluster` (Service `monapp-postgres-cluster-rw`), pgAdmin `monapp-postgres` | `monapp-postgres.<global.domain>` |
| mongodb | MongoDBCommunity `monapp-mongo` (Service `monapp-mongo-svc`), Mongo Express `monapp-mongodb` | `monapp-mongodb.<global.domain>` |

Le détail des ressources de chaque composant est dans le README du sous-chart correspondant.

En plus des sous-charts, `webapp` crée lui-même les ressources suivantes.

| Ressource | Nom | Condition |
|---|---|---|
| ConfigMap d'environnement du back | `monapp-back-config` | toujours |
| Secret d'environnement du back | `monapp-back-config-sec` | toujours |
| ConfigMap / Secret d'environnement du front | `monapp-front-config` / `monapp-front-config-sec` | `front.enabled` |
| ConfigMap / Secret d'environnement de pgAdmin | `monapp-postgres-config` / `monapp-postgres-config-sec` | `postgres.enabled` |
| Secret `servers.json` de pgAdmin | `monapp-postgres-serverconfig-sec` | `postgres.enabled` |
| Secret des identifiants PostgreSQL | `postgres.database.secret` (`postgres-initdb`) | `postgres.enabled` et `postgres.cluster.createSecret: false` |
| CiliumNetworkPolicy | `monapp-webapp-allow-all-in-own-ns` | `webapp.ciliumNetworkPolicy.enabled` |

C'est pour cela que `back.env`, `front.env` et `postgres.env` ont `createConfigMap` / `createSecret` à `false` : `webapp` génère ces ressources à leur place, sous les noms attendus par les sous-charts, en y ajoutant les variables de câblage.

## Variables injectées automatiquement

### Dans le back

Toujours :

| Variable | Valeur |
|---|---|
| `NAMESPACE` | namespace de la release |

Si `postgres.enabled` :

| Variable | Valeur |
|---|---|
| `POSTGRES_IP` | `monapp-postgres-cluster-rw.<namespace>.svc.cluster.local` |
| `POSTGRES_PORT` | `postgres.database.port` (`5432`) |
| `POSTGRES_NAME` | `postgres.database.name` |
| `POSTGRES_USER` | `postgres.database.owner` |
| `POSTGRES_PASS` *(Secret)* | `postgres.database.password` |
| `POSTGRES_ADMIN_URL` | hôte de pgAdmin |
| `POSTGRES_ADMIN_PORT` | `postgres.admin.port` (`80`) |
| `POSTGRES_ADMIN_MAIL` | `postgres.admin.email` |
| `POSTGRES_ADMIN_PASS` *(Secret)* | `postgres.admin.password` |

Si `mongodb.enabled` :

| Variable | Valeur |
|---|---|
| `MONGO_IP` | `monapp-mongo-svc` |
| `MONGO_PORT` | `27017` |
| `MONGO_NAME` | `monapp-mongo` (nom de la base applicative) |
| `MONGO_USER` | `mongodb.cluster.database.user` |
| `MONGO_PASS` *(Secret)* | `mongodb.cluster.database.password` |
| `MONGO_ADMIN_URL` | hôte de Mongo Express |
| `MONGO_ADMIN_PORT` | `8081` |
| `MONGO_ADMIN_USER` | `mongodb.mongoExpress.username` |
| `MONGO_ADMIN_PASS` *(Secret)* | `mongodb.mongoExpress.password` |

S'y ajoutent les variables de `back.env.config.values` (ConfigMap) et `back.env.secret.values` (Secret).

### Dans le front (si `front.enabled`)

| Variable | Valeur |
|---|---|
| `NAMESPACE` | namespace de la release |
| `PROJECT_NAME` / `TITLE_PAGE` | nom de la release |
| `API_URL` | hôte de l'Ingress automatique du back (sans `https://`), si le back est exposé |

S'y ajoutent `front.env.config.values` et `front.env.secret.values`.

## Configuration

Toutes les clés des sous-charts sont disponibles sous leur alias (`back.*`, `front.*`, `postgres.*`, `mongodb.*`) : voir leurs README. Les valeurs par défaut propres à `webapp` :

| Clé | Défaut | Description |
|---|---|---|
| `global.domain` | `example.com` | Domaine des Ingress automatiques de tous les composants. **À surcharger.** |
| `back.service.port` | `5001` | Port du back (Service et conteneur). |
| `back.ingress.enabled` / `auto` | `true` / `true` | Back exposé sur `monapp-back.<domaine>`. |
| `front.enabled` | `false` | |
| `front.ingress.enabled` / `auto` | `true` / `true` | |
| `postgres.enabled` | `false` | |
| `postgres.cluster.createSecret` | `false` | Le Secret des identifiants est créé par `webapp`. |
| `postgres.database.secret` | `postgres-initdb` | Nom de ce Secret. |
| `postgres.database.port` | `5432` | Utilisé pour `POSTGRES_PORT` et `servers.json`. |
| `postgres.database.password` / `postgres.admin.password` | valeurs d'exemple | **À changer.** |
| `postgres.ingress.enabled` / `auto` | `true` / `true` | pgAdmin exposé. |
| `mongodb.enabled` | `false` | |
| `mongodb.cluster.database.password` / `mongodb.mongoExpress.password` | valeurs d'exemple | **À changer.** |
| `webapp.ciliumNetworkPolicy.enabled` | `false` | Voir les points d'attention. |
| `webapp.ciliumNetworkPolicy.annotations` | `{}` | |

Les images `back.image` et `front.image` valent `nginx` par défaut : elles doivent toujours être surchargées.

## Points d'attention

- **`global.ingressClassName` n'est pas utilisé.** Les sous-charts lisent `<alias>.ingress.className` ; sans valeur, c'est l'IngressClass par défaut du cluster qui s'applique. Pour forcer `nginx`, définissez `back.ingress.className`, `front.ingress.className`, etc.
- **La CiliumNetworkPolicy ne doit pas être activée en l'état** :
  - il lui manque `endpointSelector`, que Cilium exige ;
  - l'indentation de `matchLabels` est incorrecte, le sélecteur de namespace est donc ignoré ;
  - même corrigée, elle bloquerait le trafic venant de l'ingress controller (autre namespace) et les requêtes DNS vers `kube-system`.
- Le fichier `templates/_front.tpl` définit des helpers qui ne sont utilisés par aucun template.
- Avec `mongodb.enabled`, une seule release `webapp` par namespace est possible (voir le README de [`svc-mongodb`](../svc-mongodb/README.md#points-dattention)).
- **Changez tous les mots de passe par défaut** et préférez des Secrets externes en production.
