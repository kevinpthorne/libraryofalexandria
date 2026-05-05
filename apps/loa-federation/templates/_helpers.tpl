{{- define "netbird-api-url" -}}
https://netbird-controller.{{ .Values.netbird.controllerNamespace }}.svc.cluster.local   # TODO what port though
{{- end -}}
