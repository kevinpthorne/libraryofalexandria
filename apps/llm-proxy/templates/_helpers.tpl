{{/*
Expand the name of the chart.
*/}}
{{- define "llm-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "llm-proxy.fullname" -}}
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
{{- define "llm-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "llm-proxy.labels" -}}
helm.sh/chart: {{ include "llm-proxy.chart" . }}
{{ include "llm-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "llm-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llm-proxy.name" . }}
{{- if .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
API key secret name
*/}}
{{- define "llm-proxy.apiKeySecretName" -}}
{{- if .Values.apiKey.existingSecret }}
{{- .Values.apiKey.existingSecret }}
{{- else if .Values.apiKey.secretName }}
{{- .Values.apiKey.secretName }}
{{- else }}
{{- printf "%s-apikey" (include "llm-proxy.fullname" .) }}
{{- end }}
{{- end }}

{{/*
TLS secret name
*/}}
{{- define "llm-proxy.tlsSecretName" -}}
{{- if .Values.tls.secretName }}
{{- .Values.tls.secretName }}
{{- else }}
{{- printf "%s-tls" (include "llm-proxy.fullname" .) }}
{{- end }}
{{- end }}
