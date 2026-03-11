# Kurs: Helm + Kustomize w praktyce

## Czym się różni Helm od Kustomize?

Oba narzędzia służą do zarządzania manifestami Kubernetes, ale rozwiązują **różne problemy**.

### Helm — templating i dystrybucja

Helm to **menedżer pakietów** dla Kubernetesa. Działa jak `apt`, `brew` czy `npm` — pozwala pakować aplikację w **chart** (zestaw szablonów + wartości domyślne), wersjonować go i dystrybuować przez repozytoria.

Helm używa **Go templates** wewnątrz plików YAML:
```yaml
# templates/deployment.yaml
replicas: {{ .Values.replicaCount }}
image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
```

Instalujesz chart komendą `helm install`, a Helm śledzi **release** — zna historię zmian i umożliwia rollback.

### Kustomize — nakładanie łatek bez szablonów

Kustomize to **nakładarka łatek** (patcher). Nie zmienia plików YAML — zamiast tego definiujesz **co chcesz zmienić** względem bazy. Działa na czystym YAML, bez własnego języka szablonów.

```yaml
# overlays/prod/kustomization.yaml
bases:
  - ../../base
patches:
  - path: patches/deployment-patch.yaml
```

Kustomize jest wbudowany w `kubectl` od wersji 1.14: `kubectl apply -k`.

---

## Tabela porównawcza

| Aspekt | Helm | Kustomize |
|--------|------|-----------|
| **Podejście** | Szablony (templating) | Nakładanie łatek (patching) |
| **Język** | Go templates + YAML | Czysty YAML |
| **Wersjonowanie** | `Chart.yaml` z semver | Git (brak wbudowanego) |
| **Dystrybucja** | Helm repos (OCI, HTTP) | Git repos |
| **Customizacja środowisk** | `values.yaml` override | Strategic Merge Patch, JSON Patch |
| **Śledzenie instalacji** | `helm list` (release history) | Brak — `kubectl` zarządza stanem |
| **Rollback** | `helm rollback` | `git revert` + `kubectl apply` |
| **Krzywizna nauki** | Wyższa (Go templates) | Niższa (czysty YAML) |

---

## Wzorzec: Helm do dystrybucji, Kustomize do customizacji

To jest popularny wzorzec w firmach, gdzie:

- **Zespół platform** (platforma/SRE) tworzy i publikuje Helm chart — to jest "produkt" do użycia przez inne zespoły
- **Zespół aplikacji** używa Kustomize żeby dostosować chart do swoich potrzeb (środowisko, namespace, dodatkowe sidecar'y) **bez forkowania chartu**

```
[Helm Chart v1.2.0]  ←  dystrybuowany przez platformę
         |
         ↓  (Kustomize renderuje chart i nakłada patche)
  [Overlay dev]  →  myapp-dev namespace, 1 replika, małe zasoby
  [Overlay prod] →  myapp-prod namespace, 3 repliki, duże zasoby, anti-affinity
```

Kustomize obsługuje pole `helmCharts:` w `kustomization.yaml`, które pozwala użyć Helm chart jako źródła bazowych manifestów.

---

## Wymagania wstępne

```bash
# Sprawdź czy masz wymagane narzędzia
minikube version      # powinno działać
kubectl version       # od v1.14 ma wbudowany kustomize
helm version          # jeśli brakuje: brew install helm
argocd version        # Moduł 4: jeśli brakuje: brew install argocd
```

Jeśli nie masz Helm lub ArgoCD CLI:
```bash
brew install helm argocd
```

---

## Struktura kursu

```
helmkustomize/
├── README.md                    ← jesteś tutaj
├── 01-helm/                     ← Moduł 1: Helm jako narzędzie dystrybucji
├── 02-kustomize/                ← Moduł 2: Kustomize jako narzędzie customizacji
├── 03-helm-plus-kustomize/      ← Moduł 3: Oba narzędzia razem
└── 04-argocd/                   ← Moduł 4: GitOps z ArgoCD
```

Moduły 1-3 pokazują **jak** deployować — ręcznie, przez komendy.
Moduł 4 pokazuje **GitOps** — ArgoCD obserwuje Git i deployuje automatycznie.

## Jak zacząć

```bash
minikube start
cd 01-helm && cat README.md
```
