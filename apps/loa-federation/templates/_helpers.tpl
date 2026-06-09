{{- define "netbird-api-url" -}}
https://netbird-controller.{{ .Values.netbird.controller.namespace }}.svc.cluster.local   # TODO what port though
{{- end -}}

{{- define "netbird-external-url" -}}
https://{{ .Values.netbird.controller.subdomain }}.{{ .Values.cluster.externalDomain }}
{{- end -}}

