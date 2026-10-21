# webcomponent

Chart générique pour déployer **un composant web conteneurisé** : une API back-end, un front-end, un petit service HTTP. C'est la brique de base utilisée deux fois par le meta-chart [`webapp`](../webapp) (alias `back` et `front`), mais il s'utilise aussi seul.

```bash
helm repo add fastit https://ifpen.github.io/fast-it-helm-chart
helm install mon-api fastit/webcomponent \
  --set image.repository=registry.example.com/mon-api \
  --set image.tag=1.2.0 \
  --set service.port=8000 \
  --set global.domain=apps.example.com
```

## Ce qui est déployé

Les noms ci-dessous utilisent `<fullname>`, qui vaut `<release>-webcomponent` (ou simplement `<release>` si le nom de release contient déjà `webcomponent`, ou `fullnameOverride` s'il est défini).

| Ressource | Nom | Condition |
|---|---|---|
| Deployment | `<fullname>` | toujours |
| Service | `<fullname>` | toujours |
| ConfigMap (variables d'environnement) | `<fullname>-config` | `env.config.createConfigMap: true` |
| Secret (variables d'environnement) | `<fullname>-config-sec` | `env.secret.createSecret: true` |
| ServiceAccount | `<fullname>` ou `serviceAccount.name` | `serviceAccount.create: true` |
| Ingress | `<fullname>` | `ingress.enabled: true` |
| HorizontalPodAutoscaler | `<fullname>` | `autoscaling.enabled: true` |
| Pod de test (`helm test`) | `<fullname>-test-connection` | hook de test uniquement |

Le conteneur :

- écoute sur **`service.port`** : c'est à la fois le port du Service et le `containerPort`. Il doit donc correspondre au port réel de l'application ;
- reçoit **toutes** les clés de la ConfigMap `<fullname>-config` et du Secret `<fullname>-config-sec` comme variables d'environnement (`envFrom`) ;
- est redémarré automatiquement quand ces variables changent (annotation `checksum/environment` sur le pod) ;
- est surveillé par des sondes TCP sur le port `http`.

## Configuration

### Image et réplicas

| Clé | Défaut | Description |
|---|---|---|
| `image.repository` | `nginx` | Image du conteneur. **À surcharger.** |
| `image.tag` | `""` | Tag de l'image. Vide : `appVersion` du chart (`1.16.0`). |
| `image.pullPolicy` | `IfNotPresent` | |
| `imagePullSecrets` | `[]` | Secrets pour un registre privé. |
| `replicaCount` | `1` | Ignoré si `autoscaling.enabled`. |
| `nameOverride` / `fullnameOverride` | `""` | Surcharge du nom des ressources. |

### Variables d'environnement

| Clé | Défaut | Description |
|---|---|---|
| `env.config.createConfigMap` | `true` | Crée la ConfigMap `<fullname>-config`. |
| `env.config.values` | `{}` | Variables non sensibles (`CLE: valeur`). |
| `env.secret.createSecret` | `true` | Crée le Secret `<fullname>-config-sec`. |
| `env.secret.values` | `{}` | Variables sensibles (`CLE: valeur`). |
| `env.config.existingConfigMap` / `env.secret.existingSecret` | `""` | Désactive la création de la ressource correspondante (voir les points d'attention). |

```yaml
env:
  config:
    values:
      LOG_LEVEL: info
      DATABASE_HOST: postgres-rw
  secret:
    values:
      DATABASE_PASSWORD: s3cr3t
```

### Exposition

| Clé | Défaut | Description |
|---|---|---|
| `service.type` | `ClusterIP` | |
| `service.port` | `80` | Port du Service **et** du conteneur. |
| `ingress.enabled` | `false` | Crée un Ingress. |
| `ingress.auto` | `true` | Ajoute automatiquement l'hôte `<fullname>.<domaine>` (chemin `/`, avec TLS). |
| `ingress.autoTld` | `""` | Domaine de l'hôte automatique. Vide : `global.domain`. L'un des deux est **obligatoire** si `ingress.auto`. |
| `global.domain` | `""` | Domaine commun (partagé avec les autres charts dans `webapp`). |
| `ingress.className` | `""` | IngressClass. Vide : classe par défaut du cluster. |
| `ingress.annotations` | `{}` | Par exemple `cert-manager.io/cluster-issuer`. |
| `ingress.hosts` | `[]` | Hôtes supplémentaires (`host`, `paths[].path`, `paths[].pathType`). |
| `ingress.tls` | `[]` | Blocs TLS supplémentaires (`hosts`, `secretName`). |

L'hôte automatique est ajouté au bloc `tls` **sans `secretName`** : c'est le certificat par défaut de l'ingress controller (souvent un wildcard) qui est servi.

### Ressources, sondes et autoscaling

| Clé | Défaut |
|---|---|
| `resources.requests` | `cpu: 500m`, `memory: 512Mi` |
| `resources.limits` | `cpu: 2`, `memory: 2Gi` |
| `livenessProbe` | TCP sur `http`, délai initial 30 s |
| `readinessProbe` | TCP sur `http`, délai 5 s, toutes les 30 s |
| `autoscaling.enabled` | `false` |
| `autoscaling.minReplicas` / `maxReplicas` | `1` / `100` |
| `autoscaling.targetCPUUtilizationPercentage` | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | non défini |

Pour une application HTTP, une sonde `httpGet` sur un endpoint de santé est préférable :

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
```

### Pod

| Clé | Défaut | Description |
|---|---|---|
| `serviceAccount.create` | `true` | |
| `serviceAccount.automount` | `true` | Monte le jeton de l'API Kubernetes. Mettre `false` si l'application n'en a pas besoin. |
| `serviceAccount.annotations` / `name` | `{}` / `""` | |
| `podAnnotations` / `podLabels` | `{}` | |
| `podSecurityContext` / `securityContext` | `{}` | |
| `volumes` / `volumeMounts` | `[]` | Volumes supplémentaires. |
| `nodeSelector` / `tolerations` / `affinity` | vides | Placement. |

## Points d'attention

- **`existingConfigMap` / `existingSecret` ne sont pas branchés sur le Deployment.** Ils empêchent seulement la création de la ressource : le pod référence toujours `<fullname>-config` et `<fullname>-config-sec`. Une ressource existante doit donc porter exactement ces noms, sinon le pod reste en `CreateContainerConfigError`. Même chose si `createConfigMap` ou `createSecret` est à `false` sans que la ressource soit créée ailleurs (c'est `webapp` qui les crée dans ce cas).
- La valeur `role` est déclarée mais n'est utilisée par aucun template.
