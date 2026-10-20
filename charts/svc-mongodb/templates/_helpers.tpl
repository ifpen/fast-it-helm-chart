{{/*
Expand the name of the chart.
*/}}
{{- define "svc-mongodb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "svc-mongodb.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "svc-mongodb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "svc-mongodb.labels" -}}
helm.sh/chart: {{ include "svc-mongodb.chart" . }}
{{ include "svc-mongodb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "svc-mongodb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "svc-mongodb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "svc-mongodb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "svc-mongodb.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}



{{- define "svc-mongodb.configmapName" -}}
{{- printf "%s-config" (include "svc-mongodb.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.secretName" -}}
{{- printf "%s-config-sec" (include "svc-mongodb.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
MongoExpress specific tpls
*/}}
{{- define "svc-mongodb.mongoExpressConnString" -}}
{{- $mongoSvc := printf "%s-svc.%s.svc.%s" (include "svc-mongodb.clusterName" .) .Release.Namespace .Values.global.clusterDomain -}}
{{- printf "mongodb+srv://%s:%s@%s/admin?replicaSet=%s&authSource=admin&authMechanism=SCRAM-SHA-256" .Values.cluster.database.user .Values.cluster.database.password $mongoSvc (include "svc-mongodb.clusterName" .) -}}
{{- end -}}

{{- define "svc-mongodb.mongoExpressEnvConfigmapName" -}}
{{- printf "%s-mongoexpress-env" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.mongoExpressEnvSecretName" -}}
{{- printf "%s-mongoexpress-env-sec" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}



{{/*
MongoDB Cluster specific tpls
*/}}
{{- define "svc-mongodb.clusterName" -}}
{{- printf "%s-mongo" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.clusterSecretName" -}}
{{- printf "%s" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.scramSecretName" -}}
{{- printf "%s-scram" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.promSecretName" -}}
{{- printf "%s-prom-pass" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.serviceAccountAppdb" -}}
{{- printf "mongodb-kubernetes-appdb" -}}
{{- end -}}


{{/*
MongoDB Cluster init
*/}}
{{- define "svc-mongodb.initJob" -}}
{{- printf "%s-init-db" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.initScriptConfigmap" -}}
{{- printf "%s-init-script" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.initEnvConfigmapName" -}}
{{- printf "%s-init-env" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc-mongodb.initEnvSecretName" -}}
{{- printf "%s-init-env-sec" (include "svc-mongodb.clusterName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}


## INGRESS CONFIG
{{/*
Return the automatically generated ingress host.

Returns an empty string when auto ingress is not active.

Example:
  toto-back.example.com
*/}}
{{- define "svc-mongodb.autoIngressHost" -}}
{{- if and .Values.ingress.enabled .Values.ingress.auto -}}
  {{- $tld := .Values.ingress.autoTld | default .Values.global.domain -}}
  {{- $tld = required "ingress.autoTld or global.domain must be set when ingress.auto is enabled" $tld -}}
  {{- printf "%s.%s" (include "svc-mongodb.fullname" .) $tld -}}
{{- end -}}
{{- end -}}


{{/*
Build the complete ingress hosts list.

The automatically generated host is prepended to manually configured
hosts when automatic ingress is enabled.
*/}}
{{- define "svc-mongodb.ingressHosts" -}}
{{- $hosts := .Values.ingress.hosts | default (list) -}}

{{- $autoHost := include "svc-mongodb.autoIngressHost" . | trim -}}
{{- if $autoHost -}}
  {{- $hosts = prepend $hosts (dict
      "host" $autoHost
      "paths" (list (dict
        "path" "/"
        "pathType" "Prefix"
      ))
  ) -}}
{{- end -}}

{{- toYaml $hosts -}}
{{- end -}}
