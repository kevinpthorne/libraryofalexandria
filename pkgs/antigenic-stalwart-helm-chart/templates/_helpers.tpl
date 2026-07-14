{{- define "stalwart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "stalwart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "stalwart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "stalwart.labels" -}}
helm.sh/chart: {{ include "stalwart.chart" . }}
{{ include "stalwart.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "stalwart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stalwart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "stalwart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "stalwart.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "stalwart.mailServiceName" -}}
{{- printf "%s-mail" (include "stalwart.fullname" .) -}}
{{- end -}}

{{- define "stalwart.httpServiceName" -}}
{{- include "stalwart.mailServiceName" . -}}
{{- end -}}
