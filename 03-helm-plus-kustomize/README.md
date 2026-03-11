# Moduł 3: Helm + Kustomize razem

## Idea: Helm do dystrybucji, Kustomize do customizacji

To jest prawdziwy scenariusz produkcyjny. Wyobraź sobie:

- **Zespół platformy** stworzył i opublikował Helm chart `myapp` (z Modułu 1)
- **Ty** (zespół aplikacji) chcesz go użyć, ale potrzebujesz dostosować do swoich środowisk
- Nie chcesz forkować chartu (bo wtedy tracisz updaty od zespołu platformy)

**Rozwiązanie:** Kustomize potrafi użyć Helm chart jako źródło bazowych manifestów (`helmCharts:` w `kustomization.yaml`), a następnie nałożyć swoje patche.

```
[Helm chart v1.0.0]  ← zewnętrzny, nie modyfikujesz
         ↓
   Kustomize renderuje chart (helm template wewnętrznie)
         ↓
   Nakłada Twoje patche (np. dodaje sidecar, zmienia namespace)
         ↓
[dev overlay]   →  namespace: myapp-dev, 1 replika
[prod overlay]  →  namespace: myapp-prod, 3 repliki + anti-affinity
```

## Kiedy to podejście wygrywa z samym values.yaml?

| Sytuacja | Helm values.yaml | Kustomize patch |
|----------|-----------------|-----------------|
| Zmiana liczby replik | ✅ jeśli chart to eksponuje | ✅ zawsze |
| Dodanie sidecar (np. Vault agent) | ❌ chart musi to przewidzieć | ✅ zawsze |
| Zmiana annotation | ❌ chart musi to przewidzieć | ✅ zawsze |
| Dodanie PodDisruptionBudget | ❌ chart musi to przewidzieć | ✅ zawsze |
| Zmiana dowolnego pola YAML | ❌ chart musi to eksponować | ✅ zawsze |

## Struktura tego modułu

```
03-helm-plus-kustomize/
├── README.md
├── values-base.yaml        ← wspólne wartości dla Helm chart
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml  ← helmCharts + dev patche
    │   └── patches/
    │       └── deployment-patch.yaml
    └── prod/
        ├── kustomization.yaml  ← helmCharts + prod patche
        └── patches/
            └── deployment-patch.yaml
```

## Ćwiczenie krok po kroku

### 1. Sprawdź wymagania

Kustomize potrzebuje Helm do renderowania chart:

```bash
helm version    # musi być zainstalowany
```

### 2. Zajrzyj do kustomization.yaml

```bash
cat overlays/dev/kustomization.yaml
```

Zwróć uwagę na sekcję `helmCharts:` — wskazuje lokalny chart z Modułu 1.

### 3. Podejrzyj wynik

```bash
# Kustomize renderuje chart + nakłada patche (wymaga --enable-helm)
kubectl kustomize overlays/dev --enable-helm
kubectl kustomize overlays/prod --enable-helm
```

### 4. Zastosuj overlay dev

```bash
kubectl create namespace myapp-dev 2>/dev/null || true
kubectl apply -k overlays/dev --enable-helm

kubectl get all -n myapp-dev
```

### 5. Zastosuj overlay prod

```bash
kubectl create namespace myapp-prod 2>/dev/null || true
kubectl apply -k overlays/prod --enable-helm

kubectl get all -n myapp-prod
```

### 6. Przetestuj

```bash
kubectl port-forward -n myapp-dev svc/myapp-dev 8081:80 &
curl http://localhost:8081
# -> "ŚRODOWISKO: DEV" + sidecar info

kubectl port-forward -n myapp-prod svc/myapp-prod 8082:80 &
curl http://localhost:8082
# -> "ŚRODOWISKO: PROD"

kill %1 %2
```

### 7. Posprzątaj

```bash
kubectl delete namespace myapp-dev myapp-prod
```

---

## Kluczowe obserwacje

**Kustomize + Helm = najlepsze z obu światów:**

- Helm dostarcza **wersjonowany, parametryzowany pakiet** (dystrybucja)
- Kustomize dostarcza **nieograniczoną customizację** bez forkowania chartu
- `helmCharts:` w kustomization.yaml = punkt integracji obu narzędzi

**Ważna uwaga o `--enable-helm`:**
Flaga `--enable-helm` jest wymagana bo `helmCharts:` to feature który wywołuje zewnętrzny proces `helm`. Dla bezpieczeństwa Kustomize nie robi tego domyślnie.

**W ArgoCD / Flux:**
GitOps narzędzia jak ArgoCD i Flux mają natywne wsparcie dla tego wzorca — możesz skonfigurować żeby automatycznie renderowały Helm + Kustomize bez ręcznego `--enable-helm`.

---

## Podsumowanie kursu

| | Moduł 1 (Helm) | Moduł 2 (Kustomize) | Moduł 3 (Razem) |
|--|--|--|--|
| **Cel** | Dystrybucja pakietu | Customizacja środowisk | Pełny wzorzec produkcyjny |
| **Narzędzie** | `helm install/upgrade` | `kubectl apply -k` | `kubectl apply -k --enable-helm` |
| **Rollback** | `helm rollback` | Git + kubectl | Git + kubectl |
| **Środowiska** | Osobne instalacje | Overlaye | Overlaye |
