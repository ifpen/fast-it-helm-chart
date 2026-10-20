{{/*
Expand the name of the chart.
*/}}
{{- define "webcomponent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "webcomponent.fullname" -}}
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
{{- define "webcomponent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "webcomponent.labels" -}}
helm.sh/chart: {{ include "webcomponent.chart" . }}
{{ include "webcomponent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "webcomponent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webcomponent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "webcomponent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "webcomponent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "webcomponent.configmapName" -}}
{{- printf "%s-config" (include "webcomponent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webcomponent.secretName" -}}
{{- printf "%s-config-sec" (include "webcomponent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}


## INGRESS CONFIG
{{/*
Return the automatically generated ingress host.

Returns an empty string when auto ingress is not active.

Example:
  toto-back.example.com
*/}}
{{- define "webcomponent.autoIngressHost" -}}
{{- if and .Values.ingress.enabled .Values.ingress.auto -}}
  {{- $tld := .Values.ingress.autoTld | default .Values.global.domain -}}
  {{- $tld = required "ingress.autoTld or global.domain must be set when ingress.auto is enabled" $tld -}}
  {{- printf "%s.%s" (include "webcomponent.fullname" .) $tld -}}
{{- end -}}
{{- end -}}


{{/*
Build the complete ingress hosts list.

The automatically generated host is prepended to manually configured
hosts when automatic ingress is enabled.
*/}}
{{- define "webcomponent.ingressHosts" -}}
{{- $hosts := .Values.ingress.hosts | default (list) -}}

{{- $autoHost := include "webcomponent.autoIngressHost" . | trim -}}
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
