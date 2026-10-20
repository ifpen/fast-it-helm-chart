{{/*
Build the complete ConfigMap environment for front.

Explicit front.env.config values are loaded first.
Automatically generated values then take precedence.
*/}}
{{- define "webapp.front.configEnv" -}}
{{- $env := dict -}}

{{/* User-provided config */}}
{{- range $key, $value := (.Values.front.env.config | default dict) -}}
  {{- $_ := set $env $key ($value | toString) -}}
{{- end -}}

{{/* Automatically generated config */}}
{{- $_ := set $env "NAMESPACE" (.Release.Namespace | toString) -}}
{{- $_ := set $env "PROJECT_NAME" (.Release.Name | toString) -}}
{{- $_ := set $env "TITLE_PAGE" (.Release.Name | toString) -}}

{{/* Backend URL, if the backend exposes one */}}
{{- with .Subcharts.back -}}
  {{- $apiURL := include "webcomponent.autoIngressHost" . | trim -}}
  {{- if $apiURL -}}
    {{- $_ := set $env "API_URL" $apiURL -}}
  {{- end -}}
{{- end -}}

{{- toYaml $env -}}
{{- end -}}


{{/*
Build the complete Secret environment for front.
*/}}
{{- define "webapp.front.secretEnv" -}}
{{- $env := dict -}}

{{- range $key, $value := (.Values.front.env.secret | default dict) -}}
  {{- $_ := set $env $key ($value | toString) -}}
{{- end -}}

{{- toYaml $env -}}
{{- end -}}
