# 🔄 Library GitOps Repository

<div align="center">

![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-v3-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Manifests-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

Repo chứa toàn bộ cấu hình triển khai **Helm Charts** và **ArgoCD Applications** cho hệ thống [Library Microservices](https://github.com/Lghthien/library-website-microservice).  
Image tag được tự động cập nhật bởi pipeline CI/CD — ArgoCD sẽ tự động sync và deploy lên Kubernetes.

</div>

---

## 📋 Mục lục

- [Tổng quan GitOps Flow](#-tổng-quan-gitops-flow)
- [Cấu trúc Repository](#-cấu-trúc-repository)
- [Helm Charts](#-helm-charts)
- [ArgoCD Applications](#-argocd-applications)
- [Môi trường triển khai](#-môi-trường-triển-khai)
- [Cách hoạt động tự động](#-cách-hoạt-động-tự-động)
- [Cài đặt ArgoCD Applications](#-cài-đặt-argocd-applications)
- [Cập nhật thủ công](#-cập-nhật-thủ-công)

---

## 🌊 Tổng quan GitOps Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              library-website-microservice (Source)              │
│                                                                 │
│   Developer pushes code → GitHub Actions CI/CD Pipeline         │
│                                                                 │
│   Job 1: Detect Changes  →  Job 2: CI Tests  →  Job 3: Push    │
│                                                    Docker Hub   │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Job 4: Update GitOps
                                 │ (sed image tag → git push)
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              library-gitops (This Repo — Source of Truth)       │
│                                                                 │
│   auth-service/values-dev.yaml                                  │
│     image.tag: "dev-abc1234"  ◄── Auto-updated by CI/CD         │
└────────────────────────────────┬────────────────────────────────┘
                                 │ ArgoCD watches & auto-syncs
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│   Namespace: library-dev   │   Namespace: library-prod          │
│   ┌─────────────────────┐  │   ┌─────────────────────────────┐  │
│   │ auth-service (dev)  │  │   │  auth-service (prod, x2)    │  │
│   │ catalog-service     │  │   │  catalog-service (x2)       │  │
│   │ ... (9 services)    │  │   │  ... (9 services)           │  │
│   └─────────────────────┘  │   └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Cấu trúc Repository

```
library-gitops/
│
├── argocd-root/                    # ArgoCD Application manifests
│   ├── dev-auth-service.yaml       # App: dev environment
│   ├── dev-catalog-service.yaml
│   ├── dev-frontend.yaml
│   ├── dev-gateway.yaml
│   ├── dev-loan-service.yaml
│   ├── dev-notification-service.yaml
│   ├── dev-parameter-service.yaml
│   ├── dev-reader-service.yaml
│   ├── dev-report-service.yaml
│   ├── prod-auth-service.yaml      # App: production environment
│   ├── prod-catalog-service.yaml
│   ├── prod-frontend.yaml
│   ├── prod-gateway.yaml
│   ├── prod-loan-service.yaml
│   ├── prod-notification-service.yaml
│   ├── prod-parameter-service.yaml
│   ├── prod-reader-service.yaml
│   └── prod-report-service.yaml
│
├── auth-service/                   # Helm Chart cho từng service
│   ├── Chart.yaml
│   ├── values-dev.yaml             # Config môi trường Dev
│   ├── values-prod.yaml            # Config môi trường Prod
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
│
├── catalog-service/                # Tương tự auth-service
├── frontend/
├── gateway/
├── loan-service/
├── notification-service/
├── parameter-service/
├── reader-service/
├── report-service/
│
└── generate-helm.ps1               # Script tạo Helm Charts tự động
```

---

## ⛵ Helm Charts

Mỗi service có một Helm Chart độc lập với cấu trúc chuẩn:

### `Chart.yaml`

```yaml
apiVersion: v2
name: auth-service
description: Helm chart for auth-service - Library Microservices
type: application
version: 1.0.0
appVersion: "1.0.0"
```

### `values-dev.yaml` (Dev — 1 replica)

```yaml
replicaCount: 1

image:
  repository: legiahoangthien/library-auth-service
  tag: "dev-<git-sha>"           # ← Được CI/CD tự động cập nhật

service:
  type: ClusterIP
  port: 4001

needsDatabase: true              # Mount Secret MONGO_URI nếu true

env:
  NODE_ENV: "development"
  PORT: "4001"
```

### `values-prod.yaml` (Production — 2 replicas)

```yaml
replicaCount: 2

image:
  repository: legiahoangthien/library-auth-service
  tag: "prod-<git-sha>"          # ← Được CI/CD tự động cập nhật

service:
  type: ClusterIP
  port: 4001

needsDatabase: true

env:
  NODE_ENV: "production"
  PORT: "4001"
```

### Templates

| File | Mô tả |
|------|-------|
| `templates/deployment.yaml` | Kubernetes Deployment — tự động mount `MONGO_URI` từ Secret nếu `needsDatabase: true` |
| `templates/service.yaml` | Kubernetes Service (ClusterIP) — expose port 80, forward đến port service |

---

## 🎯 ArgoCD Applications

Mỗi file trong `argocd-root/` là một **ArgoCD Application** object, khai báo:

```yaml
# Ví dụ: argocd-root/dev-auth-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-auth-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Lghthien/library-gitops.git
    targetRevision: main
    path: auth-service                # Helm Chart path
    helm:
      valueFiles:
        - values-dev.yaml             # values file cho môi trường Dev
  destination:
    server: https://kubernetes.default.svc
    namespace: library-dev            # Deploy vào namespace này
  syncPolicy:
    automated:
      prune: true                     # Xóa resource không còn trong Git
      selfHeal: true                  # Tự phục hồi nếu bị chỉnh tay
    syncOptions:
      - CreateNamespace=true          # Tạo namespace nếu chưa có
```

### Danh sách Applications

| Application Name | Namespace | values file |
|-----------------|-----------|-------------|
| `dev-auth-service` | `library-dev` | `values-dev.yaml` |
| `dev-catalog-service` | `library-dev` | `values-dev.yaml` |
| `dev-frontend` | `library-dev` | `values-dev.yaml` |
| `dev-gateway` | `library-dev` | `values-dev.yaml` |
| `dev-loan-service` | `library-dev` | `values-dev.yaml` |
| `dev-notification-service` | `library-dev` | `values-dev.yaml` |
| `dev-parameter-service` | `library-dev` | `values-dev.yaml` |
| `dev-reader-service` | `library-dev` | `values-dev.yaml` |
| `dev-report-service` | `library-dev` | `values-dev.yaml` |
| `prod-auth-service` | `library-prod` | `values-prod.yaml` |
| `prod-catalog-service` | `library-prod` | `values-prod.yaml` |
| `prod-frontend` | `library-prod` | `values-prod.yaml` |
| ... | ... | ... |

---

## 🌍 Môi trường triển khai

| Thuộc tính | Dev | Production |
|-----------|-----|------------|
| **Branch trigger** | `dev` | `main` |
| **Image tag prefix** | `dev-{git-sha}` | `prod-{git-sha}` |
| **K8s Namespace** | `library-dev` | `library-prod` |
| **Replicas** | `1` | `2` |
| **NODE_ENV** | `development` | `production` |
| **Frontend API URL** | `http://gateway-svc:80` | `https://api.thuvien.vn` |

---

## ⚙️ Cách hoạt động tự động

Khi developer push code lên nhánh `dev` hoặc `main` trong repo source, pipeline CI/CD sẽ:

1. **Phát hiện** các service có thay đổi
2. **Chạy CI** (lint, scan bảo mật, tests, build Docker image)
3. **Push image** lên Docker Hub với tag `{env}-{git-sha}`
4. **Cập nhật repo này** (GitOps) bằng lệnh `sed`:

```bash
# Ví dụ lệnh được CI/CD chạy tự động:
sed -i "s|tag: .*|tag: \"dev-abc1234\"|g" auth-service/values-dev.yaml
git commit -m "Auto-update dev images tag to dev-abc1234 [skip ci]"
git push origin main
```

5. **ArgoCD phát hiện** thay đổi trong repo này → tự động sync → deploy lên Kubernetes

---

## 🚀 Cài đặt ArgoCD Applications

### Yêu cầu

- Kubernetes cluster đang chạy
- ArgoCD đã được cài đặt trong namespace `argocd`
- Secret `library-db-secret` đã được tạo trong các namespace `library-dev` và `library-prod`:

```bash
# Tạo Secret chứa MongoDB URI
kubectl create secret generic library-db-secret \
  --from-literal=MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/library" \
  -n library-dev

kubectl create secret generic library-db-secret \
  --from-literal=MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net/library" \
  -n library-prod
```

### Apply toàn bộ ArgoCD Applications

```bash
# Apply tất cả Applications (dev + prod)
kubectl apply -f argocd-root/

# Chỉ apply môi trường dev
kubectl apply -f argocd-root/dev-*.yaml

# Chỉ apply môi trường prod
kubectl apply -f argocd-root/prod-*.yaml
```

### Kiểm tra trạng thái

```bash
# Xem tất cả Applications
kubectl get applications -n argocd

# Kiểm tra chi tiết một Application
kubectl describe application dev-auth-service -n argocd

# Xem pods đang chạy
kubectl get pods -n library-dev
kubectl get pods -n library-prod
```

---

## 🛠 Cập nhật thủ công

Trong trường hợp cần cập nhật image tag thủ công (không qua CI/CD):

```bash
# 1. Clone repo này
git clone https://github.com/Lghthien/library-gitops.git
cd library-gitops

# 2. Sửa image tag trong values file tương ứng
# Ví dụ: cập nhật auth-service dev lên tag mới
sed -i "s|tag: .*|tag: \"dev-newsha123\"|g" auth-service/values-dev.yaml

# 3. Commit và push
git add auth-service/values-dev.yaml
git commit -m "Manual update auth-service dev tag to dev-newsha123"
git push origin main
```

---

## 🔧 Tái tạo Helm Charts

Nếu cần tái tạo lại toàn bộ cấu trúc Helm Charts từ đầu, sử dụng script PowerShell có sẵn:

```powershell
# Chạy từ thư mục root của repo
.\generate-helm.ps1
```

Script sẽ tự động tạo `Chart.yaml`, `values-dev.yaml`, `values-prod.yaml`, `templates/deployment.yaml` và `templates/service.yaml` cho tất cả 9 services.

---

## 🔗 Liên kết liên quan

- **Source Code**: [library-website-microservice](https://github.com/Lghthien/library-website-microservice)
- **Docker Hub**: [legiahoangthien](https://hub.docker.com/u/legiahoangthien)
- **SonarCloud**: [lghthien organization](https://sonarcloud.io/organizations/lghthien)

---

<div align="center">
  🤖 Image tags trong repo này được cập nhật <strong>tự động</strong> bởi GitHub Actions CI/CD pipeline.<br/>
  Không chỉnh sửa <code>image.tag</code> trực tiếp — mọi thay đổi sẽ bị ghi đè bởi pipeline.
</div>
