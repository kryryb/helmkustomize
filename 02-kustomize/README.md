# Moduł 2: Kustomize — customizacja bez szablonów

## Jak działa Kustomize?

Kustomize **nie używa szablonów**. Zamiast tego działa na zasadzie:

1. **Base** — bazowe, "czyste" manifesty YAML (bez żadnych placeholderów)
2. **Overlay** — katalog środowiskowy który wskazuje na base i definiuje **co zmienić**
3. **Patch** — plik YAML opisujący zmianę (Strategic Merge Patch lub JSON Patch)

```
base/
├── kustomization.yaml     ← "zarządzam tymi plikami"
├── deployment.yaml        ← czysty YAML, bez {{ }}
├── service.yaml
└── configmap.yaml

overlays/
├── dev/
│   ├── kustomization.yaml ← "użyj base + zastosuj te patche"
│   └── patches/
│       ├── deployment-patch.yaml   ← zmień repliki i zasoby
│       └── configmap-patch.yaml   ← zmień treść strony
└── prod/
    ├── kustomization.yaml
    └── patches/
        ├── deployment-patch.yaml
        └── configmap-patch.yaml
```

## Dlaczego Kustomize nie templatkuje?

Helm wymaga nauczenia się Go templates. Kustomize celowo tego unika — każdy plik YAML jest poprawnym YAML-em, który możesz `kubectl apply` bezpośrednio. To ułatwia:
- debugowanie (brak "co tu podstawia template?")
- code review (diff pokazuje konkretne zmiany)
- integrację z narzędziami IDE

## Ćwiczenie krok po kroku

### 1. Zajrzyj do struktury

```bash
# Baza — czyste manifesty
cat base/kustomization.yaml
cat base/deployment.yaml

# Overlay dev — co się zmienia
cat overlays/dev/kustomization.yaml
cat overlays/dev/patches/deployment-patch.yaml
```

### 2. Podejrzyj wynik bez stosowania

`kubectl kustomize` (lub `kustomize build`) generuje finalny YAML:

```bash
# Co zostanie zastosowane dla dev?
kubectl kustomize overlays/dev

# Co zostanie zastosowane dla prod?
kubectl kustomize overlays/prod
```

Porównaj wyniki — widać różnicę w replikach, zasobach i treści strony.

### 3. Utwórz namespace i zastosuj overlay dev

```bash
kubectl create namespace myapp-dev
kubectl apply -k overlays/dev

# Sprawdź co powstało
kubectl get all -n myapp-dev
kubectl get configmap -n myapp-dev
```

### 4. Zastosuj overlay prod

```bash
kubectl create namespace myapp-prod
kubectl apply -k overlays/prod

kubectl get all -n myapp-prod
```

### 5. Porównaj środowiska

```bash
# Repliki
kubectl get deployment -n myapp-dev
kubectl get deployment -n myapp-prod

# Zasoby CPU/RAM
kubectl get deployment myapp -n myapp-dev -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool
kubectl get deployment myapp -n myapp-prod -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool
```

### 6. Przetestuj aplikację

```bash
# Dev
kubectl port-forward -n myapp-dev svc/myapp 8081:80 &
curl http://localhost:8081
# -> żółte tło, "ŚRODOWISKO: DEV"

# Prod
kubectl port-forward -n myapp-prod svc/myapp 8082:80 &
curl http://localhost:8082
# -> zielone tło, "ŚRODOWISKO: PROD"

# Zatrzymaj port-forwardy
kill %1 %2
```

### 7. Posprzątaj

```bash
kubectl delete namespace myapp-dev myapp-prod
```

---

## Kluczowe obserwacje

**Zalety podejścia Kustomize:**

1. **Czyste YAML-e** — base jest poprawnym YAML-em, działa bez Kustomize
2. **DRY** — wspólna konfiguracja jest w base, overlaye zawierają tylko różnice
3. **Przejrzyste diff'y** — patch-plik jasno pokazuje co się zmienia
4. **Brak języka szablonów** — nie musisz znać Go templates

**Kiedy Kustomize > Helm values.yaml:**
- Chcesz dodać **sidecar container** (chart tego nie przewidział)
- Chcesz zmienić **pole które chart nie eksponuje** przez values
- Pracujesz z **zewnętrznym chartem** (nie możesz go modyfikować)

To właśnie jest tematem Modułu 3!

---

## Następny krok

```bash
cd ../03-helm-plus-kustomize && cat README.md
```
