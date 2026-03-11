# Moduł 1: Helm — dystrybucja aplikacji

## Czym jest Helm chart?

Chart to **pakiet aplikacji Kubernetes** — analogia do paczki `npm` czy `apt`. Zawiera:
- `Chart.yaml` — metadane: nazwa, wersja, opis
- `values.yaml` — domyślne wartości parametrów
- `templates/` — szablony YAML z placeholderami `{{ .Values.xxx }}`

Helm **renderuje** szablony (podstawia wartości) i wysyła gotowe YAML-e do Kubernetesa.

## Struktura chartu w tym module

```
myapp/
├── Chart.yaml          ← metadane pakietu
├── values.yaml         ← domyślne wartości (do nadpisania)
└── templates/
    ├── _helpers.tpl    ← helpery: funkcje wielokrotnego użytku
    ├── configmap.yaml  ← treść strony nginx (parametryzowana)
    ├── deployment.yaml ← deployment (repliki, obraz, zasoby)
    └── service.yaml    ← service ClusterIP
```

## Ćwiczenie krok po kroku

### 1. Uruchom minikube

```bash
minikube start
```

### 2. Zajrzyj do chartu

Zanim zainstalujesz — zrozum co instalujesz:

```bash
cat myapp/Chart.yaml         # metadane
cat myapp/values.yaml        # domyślne wartości
cat myapp/templates/deployment.yaml  # jak wartości są użyte w szablonie
```

### 3. Zrenderuj chart bez instalacji

`helm template` to "sucha próba" — generuje finalne YAML-e bez wysyłania do Kubernetesa:

```bash
helm template myapp ./myapp
```

Zauważ jak `{{ .Values.replicaCount }}` zamieniło się na `1`, a `{{ .Values.content }}` na treść strony.

### 4. Zainstaluj chart z domyślnymi wartościami

```bash
helm install myapp ./myapp
```

Sprawdź co zostało utworzone:
```bash
kubectl get all
kubectl get configmap
```

### 5. Przetestuj aplikację

```bash
# Port-forward do serwisu
kubectl port-forward svc/myapp 8080:80

# W nowym terminalu lub przeglądarce:
curl http://localhost:8080
# -> "Witaj z Helm! Środowisko: domyślne"
```

Zatrzymaj port-forward: `Ctrl+C`

### 6. Nadpisz wartości przy instalacji (flaga --set)

```bash
# Odinstaluj poprzednią wersję
helm uninstall myapp

# Zainstaluj z innymi wartościami
helm install myapp ./myapp \
  --set replicaCount=2 \
  --set content="<h1>Zmieniona treść!</h1>"
```

### 7. Nadpisz wartości przez plik values

To lepsze podejście — zamiast długich flag `--set` używasz osobnego pliku:

```bash
helm uninstall myapp

# Instalacja dla środowiska dev
helm install myapp ./myapp -f values-dev.yaml

# Sprawdź różnicę
kubectl get deployment myapp -o yaml | grep -A5 "resources:"
```

```bash
helm uninstall myapp

# Instalacja dla środowiska prod
helm install myapp ./myapp -f values-prod.yaml

kubectl get deployment myapp -o yaml | grep "replicas:"
```

### 8. Upgrade i rollback

```bash
# Zainstaluj wersję 1.0
helm install myapp ./myapp

# Upgrade do nowej konfiguracji
helm upgrade myapp ./myapp --set replicaCount=3

# Historia zmian
helm history myapp

# Rollback do poprzedniej wersji
helm rollback myapp 1

# Sprawdź że repliki wróciły do 1
kubectl get deployment myapp
```

### 9. Posprzątaj

```bash
helm uninstall myapp
```

---

## Kluczowe obserwacje

**Co Helm daje jako narzędzie dystrybucji:**

1. **Wersjonowanie** — `version: 1.0.0` w `Chart.yaml`. Możesz pinować dokładną wersję.
2. **Parametryzacja** — `values.yaml` definiuje co można konfigurować. To publiczne API chartu.
3. **Historia release** — `helm history myapp` pokazuje wszystkie zmiany.
4. **Rollback** — `helm rollback myapp 1` cofa do dowolnej poprzedniej wersji.
5. **Dystrybucja** — chart można spakować (`helm package`) i opublikować w repozytorium.

**Ograniczenie values.yaml:**
Możesz zmienić tylko to, co twórca chartu "udostępnił" przez `values.yaml`. Jeśli chcesz dodać np. sidecar container lub zmienić pole które chart nie eksponuje — musisz forkować chart. Tu wchodzi Kustomize (Moduł 3).

---

## Następny krok

```bash
cd ../02-kustomize && cat README.md
```
