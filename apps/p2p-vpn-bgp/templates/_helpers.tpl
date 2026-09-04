{{/*
Determine if metrics should be enabled based on .Values.metrics.enabled and .Values.cluster.apps
*/}}
{{- define "p2p-vpn-bgp.metricsEnabled" -}}
{{- $enabled := .Values.metrics.enabled -}}
{{- if and .Values.cluster .Values.cluster.apps -}}
  {{- if not (hasKey .Values.cluster.apps "loa-observability") -}}
    {{- $enabled = false -}}
  {{- end -}}
{{- end -}}
{{- if $enabled -}}
true
{{- end -}}
{{- end -}}
