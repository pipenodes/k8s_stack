# Traefik

![Versão](https://img.shields.io/badge/Vers%C3%A3o-2.10.4-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5)
![Componente](https://img.shields.io/badge/Componente-Ingress-orange)
![Status](https://img.shields.io/badge/Status-Ativo-brightgreen)

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Configuração](#configuração)
4. [Recursos](#recursos)
5. [Monitoramento](#monitoramento)
6. [Acesso e Segurança](#acesso-e-segurança)
7. [Integrações](#integrações)
8. [Troubleshooting](#troubleshooting)
9. [Certificados](#certificados)

## Visão Geral

Traefik é um proxy reverso e balanceador de carga moderno que facilita a implantação de microsserviços. Na nossa plataforma, o Traefik funciona como Ingress Controller dentro do cluster EKS, integrando-se com AWS Network Load Balancers para fornecer acesso a serviços internos e externos.

## Arquitetura

O Traefik é implantado em nosso cluster Kubernetes com a seguinte arquitetura:

```
    +-------------------+
    |     AWS NLB       |
    | (SSL Offloading)  |
    +-------------------+
          /       \
         /         \
+----------------+           +----------------+
|   Public LB    |           |  Internal LB   |
| (goapice APIs) |           | (Web Consoles) |
+----------------+           +----------------+
        |                           |
        v                           v
+-----------------+          +------------------+
|                 |          |   Pritunl VPN    |
|     Traefik     |<---------+  vpn.goapice.com |
| (Ingress Ctrl)  |          |                  |
+-----------------+          +------------------+
        |
+-------+----------------------------------------------------+
|       |         |          |         |         |           |
v       v         v          v         v         v           v
+-------+ +-------+ +------+ +--------+ +-------+ +---------+
| Trino | |StarRoc| |Dagster| |  Redis | |Grafana| | Outras  |
|       | |  ks   | |       | |        | |       | | UIs Web |
+-------+ +-------+ +------+ +--------+ +-------+ +---------+
```

### Componentes

- **Traefik Controller**:
  - Deployment com alta disponibilidade (2+ réplicas)
  - Gerencia todas as rotas de entrada para o cluster
  - Integração com AWS NLB via annotations

- **AWS Network Load Balancers**:
  - **Public NLB**: Expõe as APIs da goapice para acesso externo
  - **Internal NLB**: Fornece acesso aos consoles web internos (acessível apenas via VPN)
  - Realizam SSL offloading para o tráfego de entrada

- **Pritunl VPN**:
  - Fornece acesso seguro aos serviços internos
  - Integra-se com o Internal Load Balancer
  - Acessível via vpn.goapice.com

## Configuração

### Helm Chart

O Traefik é implantado usando um Helm chart personalizado com configurações específicas para nosso ambiente.

### Principais Configurações

```yaml
traefik:
  deployment:
    kind: Deployment
    replicas: 2
    
  resources:
    requests:
      cpu: 500m
      memory: 500Mi
    limits:
      cpu: 1
      memory: 1Gi
      
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
          
  ports:
    web:
      port: 8000
      expose: true
      exposedPort: 80
      protocol: TCP
    websecure:
      port: 8443
      expose: true
      exposedPort: 443
      protocol: TCP
      
  # Integração com AWS NLB
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${AWS_ACM_CERTIFICATE_ARN}"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
  
  # Configurações adicionais
  additionalArguments:
    - "--api.dashboard=true"
    - "--log.level=INFO"
    - "--accesslog=true"
    - "--accesslog.format=json"
    - "--accesslog.fields.headers.names.X-Real-Ip=keep"
    - "--accesslog.fields.headers.names.User-Agent=keep"
    - "--providers.kubernetesingress.ingressclass=traefik"
    - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
    - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
    
  # Headers de segurança
  headers:
    customResponseHeaders:
      X-Content-Type-Options: "nosniff"
      X-Frame-Options: "SAMEORIGIN"
      X-XSS-Protection: "1; mode=block"
      Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"
```

## Recursos

### Limites de Hardware

| Componente | CPU Request | CPU Limit | Memória Request | Memória Limit | Storage |
|------------|------------|-----------|-----------------|---------------|---------|
| Traefik | 500m | 1 | 500Mi | 1Gi | - |

### Auto-Scaling

| Componente | Min Replicas | Max Replicas | Target CPU | Target Memory | Outras Métricas |
|------------|--------------|--------------|------------|---------------|-----------------|
| Traefik | 2 | 5 | 80% | - | - |

## Monitoramento

### Métricas Prometheus

O Traefik expõe métricas em formato Prometheus através do endpoint:
- `http://<traefik-service>:9100/metrics`

### Principais Métricas Monitoradas

- **Métricas de Tráfego**:
  - `traefik_service_requests_total`
  - `traefik_service_request_duration_seconds`
  - `traefik_service_open_connections`
  - `traefik_entrypoint_requests_total`

- **Métricas de Recursos**:
  - `traefik_process_cpu_seconds_total`
  - `traefik_process_resident_memory_bytes`
  - `go_goroutines`
  - `go_gc_duration_seconds`

### Dashboards Grafana

Um dashboard Grafana dedicado está disponível em:
- `http://grafana.internal/dashboards/traefik`

## Acesso e Segurança

### Configuração de Rotas

O Traefik cria rotas baseadas em Ingress e IngressRoutes do Kubernetes:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dagster-ingress
  namespace: workload-dlg
  annotations:
    kubernetes.io/ingress.class: "traefik"
    traefik.ingress.kubernetes.io/router.middlewares: "cors-headers@kubernetescrd"
spec:
  rules:
    - host: dagster.internal
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: dagster-webserver
                port:
                  number: 80
```

### Middlewares

O Traefik utiliza middlewares para modificar o comportamento das requisições:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: cors-headers
  namespace: default
spec:
  headers:
    accessControlAllowMethods:
      - GET
      - OPTIONS
      - PUT
      - POST
    accessControlAllowOriginList:
      - "https://*.goapice.com"
    accessControlAllowCredentials: true
    accessControlMaxAge: 100
    addVaryHeader: true
```

### Segurança

- **TLS Termination**: Realizada no AWS NLB para descarregar a criptografia
- **Headers de Segurança**: Configurados automaticamente para todas as respostas
- **Redirecionamento HTTP para HTTPS**: Configurado para todas as requisições
- **Rate Limiting**: Aplicado para evitar abuso de recursos

## Integrações

### AWS Network Load Balancer

O Traefik integra-se com AWS NLB através de annotations no serviço Kubernetes:

```yaml
service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${AWS_ACM_CERTIFICATE_ARN}"
service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
```

### Integrações de Autenticação

O Traefik suporta integração com provedores de autenticação externos:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: auth-oauth
  namespace: default
spec:
  forwardAuth:
    address: "http://oauth-service.default.svc.cluster.local/auth"
    authResponseHeaders:
      - "X-Auth-User"
      - "X-Auth-Email"
```

## Troubleshooting

### Problemas Comuns e Soluções

#### 1. Problemas de Roteamento

Se as rotas não funcionarem como esperado:

```bash
# Verificar logs do Traefik
kubectl -n workload-common logs -l app.kubernetes.io/name=traefik

# Verificar configuração gerada pelo Traefik
kubectl -n workload-common port-forward <traefik-pod> 9000:9000
# Acessar http://localhost:9000/dashboard/
```

#### 2. Problemas de Certificados

Se houver problemas com certificados TLS:

```bash
# Verificar se o certificado está corretamente referenciado
aws acm describe-certificate --certificate-arn "${AWS_ACM_CERTIFICATE_ARN}"

# Verificar configuração do NLB
aws elbv2 describe-load-balancers --names "${NLB_NAME}"
```

#### 3. Problemas de Performance

Em caso de latência ou erros:

```bash
# Verificar métricas de recursos
kubectl -n workload-common top pods -l app.kubernetes.io/name=traefik

# Verificar métricas detalhadas no Prometheus
http://prometheus.internal/graph?g0.expr=rate(traefik_service_requests_total%5B5m%5D)
```

## Certificados

### Gestão de Certificados

Os certificados TLS são gerenciados pelo AWS Certificate Manager (ACM):

1. Certificados públicos são validados via validação DNS em Route 53
2. Certificados são associados aos AWS NLBs via annotations
3. Renovação automática gerenciada pelo ACM

### Domínios Configurados

| Domínio | Tipo | Descrição | Acesso |
|---------|------|-----------|--------|
| *.goapice.com | Público | APIs e serviços externos | Internet |
| *.internal | Privado | UIs e consoles de administração | VPN |

### Verificação de Certificados

Para verificar a validade e configuração de certificados:

```bash
# Verificar validade do certificado via OpenSSL
echo | openssl s_client -showcerts -servername api.goapice.com -connect api.goapice.com:443 2>/dev/null | openssl x509 -inform pem -noout -text

# Verificar certificados no ACM
aws acm list-certificates --query "CertificateSummaryList[?DomainName=='*.goapice.com']"
```
