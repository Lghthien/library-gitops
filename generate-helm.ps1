# Danh sách các dịch vụ và cổng tương ứng
$services = @(
    @{ Name = "frontend"; Port = 3000 },
    @{ Name = "gateway"; Port = 4000 },
    @{ Name = "auth-service"; Port = 4001 },
    @{ Name = "catalog-service"; Port = 4002 },
    @{ Name = "report-service"; Port = 4003 },
    @{ Name = "notification-service"; Port = 4004 },
    @{ Name = "reader-service"; Port = 4005 },
    @{ Name = "loan-service"; Port = 4006 },
    @{ Name = "parameter-service"; Port = 4007 }
)

foreach ($svc in $services) {
    $svcName = $svc.Name
    $svcPort = $svc.Port
    Write-Host "🚀 Đang tao cau hinh Helm cho: $svcName (Port: $svcPort)" -ForegroundColor Cyan

    # Tạo thư mục templates
    New-Item -ItemType Directory -Force -Path "$svcName\templates" | Out-Null

    # 1. Tạo file Chart.yaml (Đã đổi description sang tiếng Anh)
    @"
apiVersion: v2
name: $svcName
description: Helm chart for $svcName - Library Microservices
type: application
version: 1.0.0
appVersion: "1.0.0"
"@ | Out-File -FilePath "$svcName\Chart.yaml" -Encoding UTF8

    # 2. Định nghĩa biến môi trường và Cờ Database
    if ($svcName -eq "frontend") {
        $needsDatabase = "false"
        $envDev = @"
  NODE_ENV: "development"
  NEXT_PUBLIC_API_URL: "http://gateway-svc:80"
"@
        $envProd = @"
  NODE_ENV: "production"
  NEXT_PUBLIC_API_URL: "https://api.thuvien.vn"
"@
    } elseif ($svcName -eq "gateway") {
        $needsDatabase = "false"
        $envDev = @"
  NODE_ENV: "development"
  PORT: "$svcPort"
"@
        $envProd = @"
  NODE_ENV: "production"
  PORT: "$svcPort"
"@
    } else {
        $needsDatabase = "true"
        $envDev = @"
  NODE_ENV: "development"
  PORT: "$svcPort"
"@
        $envProd = @"
  NODE_ENV: "production"
  PORT: "$svcPort"
"@
    }

    # 3. Tạo values-dev.yaml (Comment tiếng Anh)
    @"
replicaCount: 1

image:
  repository: legiahoangthien/library-$svcName
  tag: "dev-initial"

service:
  type: ClusterIP
  port: $svcPort

# Flag to determine if this service needs MongoDB credentials from Secret
needsDatabase: $needsDatabase

env:
$envDev
"@ | Out-File -FilePath "$svcName\values-dev.yaml" -Encoding UTF8

    # 4. Tạo values-prod.yaml (Comment tiếng Anh)
    @"
replicaCount: 2

image:
  repository: legiahoangthien/library-$svcName
  tag: "prod-initial"

service:
  type: ClusterIP
  port: $svcPort

needsDatabase: $needsDatabase

env:
$envProd
"@ | Out-File -FilePath "$svcName\values-prod.yaml" -Encoding UTF8

    # 5. Tạo templates/deployment.yaml (Sử dụng if/else của Helm)
    @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.service.port }}
          env:
            # Render standard environment variables
            {{- range $key, $val := .Values.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
            {{- end }}
            
            # Mount MongoDB Secret if needed
            {{- if .Values.needsDatabase }}
            - name: MONGO_URI
              valueFrom:
                secretKeyRef:
                  name: library-db-secret
                  key: MONGO_URI
            {{- end }}
'@ | Out-File -FilePath "$svcName\templates\deployment.yaml" -Encoding UTF8

    # 6. Tạo templates/service.yaml
    @'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}-svc
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: 80
      targetPort: {{ .Values.service.port }}
  selector:
    app: {{ .Chart.Name }}
'@ | Out-File -FilePath "$svcName\templates\service.yaml" -Encoding UTF8

}

Write-Host "✅ Hoan tat tao Helm Charts!" -ForegroundColor Green