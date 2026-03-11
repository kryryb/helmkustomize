{{/*
Pełna nazwa aplikacji: używana jako prefix dla nazw zasobów.
Domyślnie: nazwa release + nazwa chartu (skrócone do 63 znaków).
*/}}
{{- define "myapp.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Etykiety wspólne dla wszystkich zasobów.
Helm automatycznie śledzi zasoby przez te etykiety.
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Etykiety selektora — używane w matchLabels i podSelector.
Muszą być niezmienne po pierwszym deploymencie!
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
