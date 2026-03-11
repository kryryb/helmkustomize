# Moduł 4: ArgoCD — GitOps w praktyce

## Czym jest GitOps?

W poprzednich modułach deployowaliśmy ręcznie:
- Moduł 1: `helm install myapp ./myapp`
- Moduł 2: `kubectl apply -k overlays/dev`
- Moduł 3: `kubectl apply -k overlays/dev --enable-helm`

**GitOps odwraca to podejście:**

```
Ręczne podejście (push):  Developer → kubectl/helm → Klaster
GitOps (pull):            Developer → git push → ArgoCD wykrywa → Klaster
```

**Zasada GitOps:** Git jest jedynym źródłem prawdy dla stanu klastra. Żadnych ręcznych `kubectl apply`. Każda zmiana w klastrze zaczyna się od commita w repozytorium.

## Czym jest ArgoCD?

ArgoCD to **kontroler Kubernetes** (działający wewnątrz klastra), który:
1. Obserwuje wskazane Git repository
2. Porównuje stan w Git z faktycznym stanem klastra
3. Wykrywa rozbieżności (**drift detection**)
4. Synchronizuje klaster do stanu z Git (automatycznie lub na żądanie)

```
Git repo
   |
   | (obserwuje co 3 min lub przez webhook)
   ↓
ArgoCD Repo Server  →  renderuje Helm chart / Kustomize overlays
   |
   ↓
ArgoCD Application Controller  →  porównuje z klastrem
   |
   ↓ (jeśli różni)
kubectl apply  →  Klaster Kubernetes
```

## Architektura ArgoCD (skrót)

| Komponent | Rola |
|-----------|------|
| **argocd-server** | API + UI webowe |
| **application-controller** | Porównuje Git vs klaster, wykrywa drift |
| **repo-server** | Klonuje repo, renderuje Helm i Kustomize |
| **Application CRD** | Zasób K8s: "wdróż `ścieżka/w/repo` do `namespace`" |

## Ćwiczenie krok po kroku

### 1. Przygotuj Git repo

ArgoCD **wymaga zdalnego** Git repo (nie może czytać z lokalnego dysku).

```bash
# W katalogu helmkustomize/
cd /Users/kr/LAB/helmkustomize

git init
git add .
git commit -m "Kurs Helm+Kustomize - wersja inicjalna"

# Utwórz repo na GitHub i wypchnij
# (zastąp URL swoim repo)
git remote add origin https://github.com/<TWOJ_LOGIN>/helmkustomize.git
git push -u origin main
```

Zanotuj URL swojego repo — będziesz go potrzebować w plikach `apps/*.yaml`.

### 2. Uruchom minikube

```bash
minikube start
```

### 3. Zainstaluj ArgoCD

```bash
# Namespace dla ArgoCD
kubectl create namespace argocd

# Oficjalny manifest instalacyjny
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Poczekaj na gotowość (może zająć 1-2 minuty)
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

# Sprawdź co zostało zainstalowane
kubectl get all -n argocd
```

### 4. Zaloguj się do ArgoCD

```bash
# Uruchom port-forward do UI (w tle lub osobnym terminalu)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Pobierz hasło admin
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Hasło: $ARGOCD_PASSWORD"

# Zaloguj przez CLI (ignoruje self-signed cert)
argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure
```

Otwórz UI w przeglądarce: **https://localhost:8080**
(login: `admin`, hasło: z powyższego polecenia)

### 5. Podmień URL w plikach Application

Otwórz każdy plik w `04-argocd/apps/` i zastąp `<TWOJ_GITHUB_URL>` prawdziwym URL:

```bash
# Przykład: zastąp placeholder swoim URL
REPO_URL="https://github.com/<TWOJ_LOGIN>/helmkustomize.git"

sed -i '' "s|<TWOJ_GITHUB_URL>|$REPO_URL|g" 04-argocd/apps/*.yaml

# Sprawdź wynik
grep repoURL 04-argocd/apps/*.yaml
```

### 6. Zastosuj Application resources

```bash
# Zacommituj zmienione pliki (ArgoCD zobaczy je w repo)
git add 04-argocd/apps/
git commit -m "Dodaj ArgoCD Application resources"
git push

# Zarejestruj aplikacje w ArgoCD
kubectl apply -f 04-argocd/apps/
```

### 7. Sprawdź status aplikacji

```bash
# Lista wszystkich aplikacji
argocd app list

# Szczegóły konkretnej aplikacji
argocd app get myapp-kustomize-dev
argocd app get myapp-kustomize-prod
argocd app get myapp-helm
```

Oczekiwany wynik: status `Synced` / `Healthy` dla każdej aplikacji.

Sprawdź w UI: **https://localhost:8080** — widać graficzny status każdej aplikacji z drzewem zasobów.

### 8. Ręczna synchronizacja (jeśli OutOfSync)

```bash
# Zsynchronizuj konkretną aplikację
argocd app sync myapp-kustomize-dev

# Sprawdź co się różni między Git a klastrem (przed sync)
argocd app diff myapp-kustomize-dev
```

### 9. GitOps w akcji — zmień coś w Git

To jest **kluczowe ćwiczenie** — zobaczymy GitOps loop w działaniu:

```bash
# 1. Zmień liczbę replik dla dev (z 1 na 2)
#    Edytuj: 02-kustomize/overlays/dev/patches/deployment-patch.yaml
#    Zmień: replicas: 1 → replicas: 2

# 2. Zacommituj i wypchnij
git add 02-kustomize/overlays/dev/patches/deployment-patch.yaml
git commit -m "dev: zwiększ repliki do 2"
git push

# 3a. Poczekaj na auto-sync (domyślnie ~3 minuty)
#     LUB
# 3b. Ręcznie wyzwól sync
argocd app sync myapp-kustomize-dev

# 4. Sprawdź wynik
kubectl get deployment -n myapp-dev
# -> READY: 2/2
```

**Bez `git push` nie ma zmiany w klastrze.** To jest sedno GitOps.

### 10. Obserwuj drift detection

ArgoCD wykrywa kiedy klaster **odbiega** od stanu w Git:

```bash
# Ręcznie zmień coś w klastrze (poza Git)
kubectl scale deployment myapp -n myapp-dev --replicas=5

# Sprawdź status w ArgoCD — powinno pokazać OutOfSync
argocd app get myapp-kustomize-dev
# -> Status: OutOfSync

# ArgoCD z selfHeal=true automatycznie przywróci 2 repliki
# (lub ręcznie: argocd app sync myapp-kustomize-dev)
kubectl get deployment -n myapp-dev
# -> READY: 2/2  (przywrócone!)
```

### 11. Rollback przez Git

```bash
# Przywróć poprzednią wersję konfiguracji
git revert HEAD
git push

# ArgoCD wykryje nowy commit i zsynchronizuje z powrotem
argocd app sync myapp-kustomize-dev
```

### 12. Posprzątaj

```bash
# Usuń aplikacje z ArgoCD (i zasoby które zarządzały)
argocd app delete myapp-kustomize-dev --cascade
argocd app delete myapp-kustomize-prod --cascade
argocd app delete myapp-helm --cascade

# LUB przez kubectl
kubectl delete -f 04-argocd/apps/

# Usuń namespace ArgoCD
kubectl delete namespace argocd myapp-dev myapp-prod myapp-helm-argocd

# Zatrzymaj port-forward
kill %1 2>/dev/null || true
```

---

## Porównanie: ręczne podejście vs ArgoCD

| Aspekt | Ręcznie (moduły 1-3) | ArgoCD (moduł 4) |
|--------|---------------------|-----------------|
| **Trigger deployu** | `helm install` / `kubectl apply` | `git push` |
| **Drift detection** | Brak | ✅ wykrywa rozbieżności |
| **Self-healing** | Brak | ✅ `selfHeal: true` cofa ręczne zmiany |
| **Rollback** | `helm rollback` / `git revert` + kubectl | `git revert` + auto-sync |
| **Audit trail** | Historia Helm release | Git history (pełna historia) |
| **Widoczność stanu** | `kubectl get all` | UI + `argocd app list` |
| **Multi-env** | Osobne komendy dla każdego env | Oddzielne Application resources |

---

## Integracja ArgoCD z Helm i Kustomize

ArgoCD natywnie obsługuje oba narzędzia — **bez `--enable-helm`**:

| `source` w Application | Co ArgoCD robi |
|------------------------|----------------|
| `path:` (brak helm/kustomize) | `kubectl apply` |
| `path:` + `kustomization.yaml` w katalogu | `kubectl kustomize` automatycznie |
| `path:` + `helm:` | `helm template` automatycznie |
| `path:` + `kustomization.yaml` z `helmCharts:` | Kustomize + Helm (jak Moduł 3) |

---

## Instalacja ArgoCD CLI (jeśli brakuje)

```bash
# macOS
brew install argocd

# Lub bezpośrednio
curl -sSL -o argocd-darwin-arm64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-arm64
chmod +x argocd-darwin-arm64
sudo mv argocd-darwin-arm64 /usr/local/bin/argocd
```

---

## Dalsze kroki

Tematy do eksploracji po tym kursie:
- **App of Apps** — jeden Application zarządzający wieloma innymi
- **ApplicationSet** — generowanie wielu Application z jednego szablonu
- **Sync Waves** — kolejność deployowania zasobów
- **Notifications** — alerty Slack/email przy zmianach
- **Flux** — alternatywa dla ArgoCD (inny model: pull-based controller per repo)
