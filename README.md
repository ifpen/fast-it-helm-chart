# Fast-IT Helm charts

Charts Helm Fast-IT, publiés comme dépôt Helm sur GitHub Pages :

```bash
helm repo add fastit https://ifpen.github.io/fast-it-helm-chart
helm repo update
helm search repo fastit/ --versions           # versions de production
helm search repo fastit/ --versions --devel   # avec les release candidates
```

| Chart          | Description                                              |
|----------------|----------------------------------------------------------|
| `webcomponent` | Composant web (front ou back) d'une WebApp               |
| `svc-postgres` | Cluster CloudNativePG + pgAdmin                          |
| `svc-mongodb`  | Cluster MongoDB + Mongo Express                          |
| `webapp`       | Meta-chart : embarque les trois charts ci-dessus         |

`webapp` référence les autres charts en `file://../<chart>` : ils sont
embarqués dans son package à la publication.

## Versionnement et gitflow

La version de chaque chart (`version:` dans `Chart.yaml`) suit SemVer et doit
toujours être de la forme `X.Y.Z`. Les suffixes de release candidate sont
ajoutés automatiquement par la CI.

| Branche      | Rôle                     | Ce qui est publié                                   |
|--------------|--------------------------|-----------------------------------------------------|
| `feature/*`  | développement            | rien (lint uniquement)                              |
| `develop`    | intégration              | rien (lint uniquement)                              |
| `release/*`  | préparation d'une version| `<chart>-X.Y.Z-rc.N` en pre-release                 |
| `hotfix/*`   | correctif de production  | `<chart>-X.Y.Z-rc.N` en pre-release                 |
| `main`       | production               | `<chart>-X.Y.Z`                                     |

Cycle type :

1. Développer sur `feature/xxx`, PR vers `develop`.
2. Créer `release/x.y.z` depuis `develop` et **incrémenter la version** des
   charts modifiés (`patch` pour un correctif, `minor` pour une évolution
   compatible, `major` pour un changement cassant des values).
3. Chaque push sur `release/x.y.z` publie une nouvelle rc (`-rc.1`, `-rc.2`…)
   des charts dont la version n'est pas encore en production et qui ont changé
   depuis la dernière rc. Les rc sont testables avec `--devel` ou en épinglant
   la version exacte.
4. PR de `release/x.y.z` vers `main` : la CI vérifie que chaque chart modifié a
   une version supérieure à celle de `main`. Au merge, la version finale est
   publiée.
5. Merger `main` dans `develop`.

Les hotfixes suivent le même chemin depuis `main` (`hotfix/x.y.z` → `main`,
puis `main` → `develop`).

Règles vérifiées par la CI sur les PR :

- `main` n'accepte que des PR depuis `release/*` ou `hotfix/*` ;
- `release/*` et `hotfix/*` n'acceptent que des PR depuis `feature/*`, `bugfix/*`
  ou `fix/*` ;
- toutes les versions de `Chart.yaml` sont au format `X.Y.Z` ;
- `helm lint` et `helm template` passent sur tous les charts.

Un chart modifié dont la version est déjà publiée n'est **pas** republié : la
CI émet un avertissement et il faut incrémenter sa version.

## Utilisation dans Argo CD

```yaml
source:
  repoURL: https://ifpen.github.io/fast-it-helm-chart
  chart: webapp
  targetRevision: 0.1.1          # version de production
  # targetRevision: 0.2.0-rc.2   # rc précise
  # targetRevision: ">=0.2.0-0"  # contrainte incluant les rc
```

Une contrainte comme `0.2.*` ou `>=0.2.0` exclut les rc.

## Fonctionnement technique

- `.github/workflows/ci.yaml` : lint, template, règles gitflow, contrôle
  d'incrément de version (chart-testing, `ct.yaml`).
- `.github/workflows/release.yaml` : publication sur `main`, `release/*`,
  `hotfix/*` via `.github/scripts/release-charts.sh`. Chaque version est une
  release GitHub `<chart>-<version>` portant le `.tgz`, et `index.yaml` est mis
  à jour sur la branche `gh-pages`.
- Si l'index devient incohérent, lancer manuellement le workflow
  *Release charts* (mode `reindex`) : il reconstruit `index.yaml` à partir de
  toutes les releases GitHub.
