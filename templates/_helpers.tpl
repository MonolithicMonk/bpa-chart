{{/*
Expand the name of the chart.
*/}}
{{- define "global.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "global.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
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
{{- define "global.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name for the password secret key. TODO currently not used, either delete or migrate key generation to template function
*/}}
{{- define "global.dbPasswordKey" -}}
{{- if .Values.global.persistence.existingSecret -}}
  {{- .Values.global.persistence.existingSecretKey -}}
{{- else -}}
  postgresql-password
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified bpa name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "bpa.fullname" -}}
{{ template "global.fullname" . }}-core
{{- end -}}


{{/*
Common bpa labels
*/}}
{{- define "bpa.labels" -}}
helm.sh/chart: {{ include "global.chart" . }}
{{ include "bpa.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector bpa labels
*/}}
{{- define "bpa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "global.fullname" . }}-core
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bpa.serviceAccountName" -}}
{{- if .Values.bpa.serviceAccount.create }}
{{- default (include "bpa.fullname" .) .Values.bpa.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.bpa.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
generate hosts if not overriden
*/}}
{{- define "bpa.host" -}}
{{- if .Values.bpa.ingress.hosts -}}
{{- (index .Values.bpa.ingress.hosts 0).host -}}
{{- else }}
{{- include "global.fullname" . }}{{ .Values.global.ingressSuffix -}}
{{- end -}}
{{- end }}


{{/*
generate ledger browser url
*/}}
{{- define "bpa.ledgerBrowser" -}}
{{- $ledgerBrowser := dict "idu" "" "bcovrin-test" "http://test.bcovrin.vonx.io" -}}
{{ .Values.bpa.config.ledger.browserUrlOverride | default ( get $ledgerBrowser .Values.global.ledger ) }}
{{- end }}


{{/*
Return JAVA_OPTS -Dmicronaut.config.files
Always return application.yml add in other files if they are enabled.
*/}}
{{- define "bpa.config.files" -}}
{{- $configFiles := list "classpath:application.yml"}}
{{- if .Values.schemas.enabled -}}
{{- $configFiles = append $configFiles "/home/indy/schemas.yml" -}}
{{- end -}}
{{- if eq (include "bpa.ux.override" .) "true" -}}
{{- $configFiles = append $configFiles "/home/indy/ux.yml" -}}
{{- end -}}
{{- if .Values.keycloak.enabled -}}
{{- $configFiles = append $configFiles "classpath:security-keycloak.yml" -}}
{{- end -}}
{{- if .Values.bpa.config.security.strict -}}
{{- $configFiles = append $configFiles "classpath:strict-security.yml" -}}
{{- end -}}
{{- join "," $configFiles -}}
{{- end -}}

{{/*
If Keycloak is enabled, add the client id and secret from the keycloak secret to bpa env
*/}}
{{- define "bpa.keycloak.secret.env.vars" -}}
{{- if (.Values.keycloak.enabled) -}}
- name: BPA_KEYCLOAK_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ template "global.fullname" . }}-keycloak
      key: clientSecret
{{- end -}}
{{- end -}}

{{/*
If Consul Discovery is enabled, mount the consul config map as env vars
*/}}
{{- define "bpa.consul.configmap.env.vars" -}}
{{- if (.Values.consul.enabled) -}}
envFrom:
  - configMapRef:
      name: {{ template "bpa.fullname" . }}-consul
{{- end -}}
{{- end -}}

{{/*
If Keycloak is enabled, mount the keycloak config map as env vars
*/}}
{{- define "bpa.keycloak.configmap.env.vars" -}}
{{- if (.Values.keycloak.enabled) -}}
envFrom:
  - configMapRef:
      name: {{ template "bpa.fullname" . }}-keycloak
{{- end -}}
{{- end -}}


{{/*
If Micronaut is enabled, mount the keycloak config map as env vars
We don't need envFrom because we always load application configmap...
*/}}
{{- define "bpa.micronaut.configmap.env.vars" -}}
envFrom:
  - configMapRef:
      name: {{ template "bpa.fullname" . }}-micronaut
{{- end -}}

{{/*
Mount the application config map as env vars
*/}}
{{- define "bpa.application.configmap.env.vars" -}}
envFrom:
  - configMapRef:
      name: {{ template "bpa.fullname" . }}
{{- end -}}

{{/*
Are we overriding the UX?
*/}}
{{- define "bpa.ux.override" -}}
{{- if ne .Values.ux.preset "default" -}}
{{- printf "true" }}
{{- else -}}
{{- printf "false" }}
{{- end -}}
{{- end -}}

{{/*
Determine the log configuration file name that should be used
*/}}
{{- define "bpa.logFileName" -}}
{{- if .Values.bpa.config.logging }}
{{- printf "/home/indy/log4j2.yml" }}
{{- else }}
{{- .Values.bpa.config.logConfigurationFile }}
{{- end }}
{{- end }}

{{/*
If custom schemas, ux, or logging configuration is enabled, create a volumes for the config maps
*/}}
{{- define "bpa.volumes" -}}
{{- if or (.Values.schemas.enabled) (.Values.bpa.config.logging) (eq (include "bpa.ux.override" .) "true") -}}
volumes:
{{- end -}}
{{- end -}}

{{/*
If schemas is enabled, create a volume for the config maps
*/}}
{{- define "bpa.volumes.schemas" -}}
{{- if (.Values.schemas.enabled) -}}
- name: config-schemas
  configMap:
    name: {{ template "bpa.fullname" . }}-schemas
    items:
    - key: "schemas.yml"
      path: "schemas.yml"
{{- end -}}
{{- end -}}

{{/*
If ux is enabled, create a volume for the config maps
*/}}
{{- define "bpa.volumes.ux" -}}
{{- if eq (include "bpa.ux.override" .) "true" -}}
- name: config-ux
  configMap:
    name: {{ template "bpa.fullname" . }}-ux
    items:
    - key: "ux.yml"
      path: "ux.yml"
{{- end -}}
{{- end -}}

{{/*
If custom logging config is used, create a volume for the config maps
*/}}
{{- define "bpa.volumes.logging" -}}
{{- if (.Values.bpa.config.logging) -}}
- name: config-logging
  configMap:
    name: {{ template "bpa.fullname" . }}-logging
    items:
    - key: "log4j2.yml"
      path: "log4j2.yml"
{{- end -}}
{{- end -}}

{{/*
If custom schemas, ux, or logging configuration is enabled, create a volume mounts for the config maps
*/}}
{{- define "bpa.volume.mounts" -}}
{{- if or (.Values.schemas.enabled) (.Values.bpa.config.logging) (eq (include "bpa.ux.override" .) "true") -}}
volumeMounts:
{{- end -}}
{{- end -}}

{{/*
If schemas is enabled, create a volume mount
*/}}
{{- define "bpa.volume.mounts.schemas" -}}
{{- if (.Values.schemas.enabled) -}}
- name: config-schemas
  mountPath: "/home/indy/schemas.yml"
  subPath: "schemas.yml"
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
If ux is enabled, create a volume mount
*/}}
{{- define "bpa.volume.mounts.ux" -}}
{{- if eq (include "bpa.ux.override" .) "true" -}}
- name: config-ux
  mountPath: "/home/indy/ux.yml"
  subPath: "ux.yml"
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
If custom logging config is enabled, create a volume mount
*/}}
{{- define "bpa.volume.mounts.logging" -}}
{{- if (.Values.bpa.config.logging) -}}
- name: config-logging
  mountPath: "/home/indy/log4j2.yml"
  subPath: "log4j2.yml"
  readOnly: true
{{- end -}}
{{- end -}}

{{- define "bpa.openshift.route.tls" -}}
{{- if (.Values.bpa.openshift.route.tls.enabled) -}}
tls:
  insecureEdgeTerminationPolicy: {{ .Values.bpa.openshift.route.tls.insecureEdgeTerminationPolicy }}
  termination: {{ .Values.bpa.openshift.route.tls.termination }}
{{- end -}}
{{- end -}}


{{/*
Set the Business Partner Agent name
*/}}
{{- define "business.partner.agent.name" -}}
{{- $name := camelcase .Release.Name }}
{{- if .Values.bpa.config.nameOverride -}}
{{- $name = (tpl .Values.bpa.config.nameOverride .) -}}
{{- end -}}
{{- if .Values.bpa.name -}}
{{- $name = (tpl .Values.bpa.name .) -}}
{{- end -}}
{{- $name -}}
{{- end -}}

{{/*
Set the Business Partner Agent Browser Title value.
*/}}
{{- define "business.partner.browser.title" -}}
{{- $title := camelcase .Release.Name }}
{{- if .Values.bpa.config.nameOverride -}}
{{- $title = (tpl .Values.bpa.config.nameOverride .) -}}
{{- end -}}
{{- if .Values.bpa.config.titleOverride -}}
{{- $title = (tpl .Values.bpa.config.titleOverride .) -}}
{{- end -}}
{{- $title -}}
{{- end -}}
