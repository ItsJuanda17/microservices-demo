# Taller de Ingeniería de Software V — Microservices Voting Demo

## Tabla de contenidos

1. [Metodología ágil](#1-metodología-ágil)
2. [Estrategia de branching para desarrolladores (2.5%)](#2-estrategia-de-branching-para-desarrolladores)
3. [Estrategia de branching para operaciones (2.5%)](#3-estrategia-de-branching-para-operaciones)
4. [Patrones de diseño de nube (15%)](#4-patrones-de-diseño-de-nube)
5. [Diagrama de arquitectura (15%)](#5-diagrama-de-arquitectura)
6. [Pipelines de desarrollo (15%)](#6-pipelines-de-desarrollo)
7. [Pipelines de infraestructura (5%)](#7-pipelines-de-infraestructura)
8. [Implementación de la infraestructura (20%)](#8-implementación-de-la-infraestructura)
9. [Demostración en vivo (15%)](#9-demostración-en-vivo-de-cambios-en-el-pipeline)
10. [Documentación de resultados (10%)](#10-entrega-de-resultados)

---

## 1. Metodología ágil

**Metodología seleccionada: Kanban**

| Aspecto | Detalle |
|---------|---------|
| Tablero | GitHub Projects (columnas: To Do → In Progress → In Review → Done) |
| WIP Limit | Máximo 2 tareas en progreso por persona |
| Backlog | GitHub Issues con labels: `dev`, `ops`, `docs` |
| Tracking | Cada Issue se vincula a su PR correspondiente |
| Definition of Done | Tests pasan, pipeline verde, PR aprobada por el otro miembro |

Se elige Kanban porque se adapta mejor a un equipo pequeño (2 personas) con entrega continua y sin ciclos de release fijos. Permite un flujo pull-based donde cada miembro toma la siguiente tarea disponible sin depender de ceremonias ni sprints.

---

## 2. Estrategia de branching para desarrolladores

**Modelo: GitHub Flow**

Se escoge GitHub Flow por su simplicidad: una rama principal (`main`) protegida y todo lo demás son ramas de trabajo cortas que se integran mediante Pull Request.

### Estructura de ramas

```
main (producción, protegida)
  ↑
  ├── feature/...  (nuevas funcionalidades)
  ├── bugfix/...   (correcciones de bugs)
  ├── hotfix/...   (correcciones críticas en producción)
  └── test/...     (adición de pruebas)
```

### Convenciones de nombres

| Tipo | Formato | Ejemplo |
|------|---------|---------|
| Feature | `feature/<descripción>` | `feature/vote-duplicate-prevention` |
| Bugfix | `bugfix/<descripción>` | `bugfix/kafka-timeout-error` |
| Hotfix | `hotfix/<descripción>` | `hotfix/security-patch` |
| Test | `test/<descripción>` | `test/worker-unit-tests` |

**Reglas de naming:** minúsculas, guiones (no underscores), máximo 50 caracteres.

### Reglas

1. `main` es la rama de producción y está **protegida** (no push directo).
2. Toda contribución se hace mediante Pull Request desde una rama de trabajo.
3. Cada PR requiere al menos **1 review aprobado** y **pipeline verde** (CI pasa).
4. Se usa **Squash and Merge** para mantener el historial limpio.
5. Las ramas se eliminan después del merge.
6. Las ramas no deben durar más de **3 días**; si se excede, dividir en PRs más pequeñas.

### Conventional Commits

```
<tipo>(<alcance>): <descripción>

feat(vote):     add input validation
fix(worker):    handle kafka reconnection
refactor(result): optimize database query
test(vote):     add duplicate vote tests
docs:           update architecture diagram
chore:          update dependencies
```

### Flujo de trabajo

1. **Crear rama** desde `main` actualizado.
2. **Desarrollar** los cambios, haciendo commits descriptivos con conventional commits.
3. **Validar** que los cambios compilan, pasan pruebas y no rompen funcionalidad existente.
4. **Push** de la rama y crear Pull Request en GitHub con descripción clara de los cambios.
5. **Review** por parte del otro miembro del equipo; resolver comentarios si los hay.
6. **Merge** a `main` (Squash and Merge) una vez aprobado y con CI en verde.
7. **Eliminar** la rama de trabajo después del merge.

---

## 3. Estrategia de branching para operaciones

**Modelo: GitHub Flow integrado para Ops**

Los cambios de infraestructura siguen el mismo rigor que el código: PRs, reviews y validación automática en CI.

### Estructura de ramas

```
main (producción, protegida)
  ↑
  ├── infra/...      (cambios de infraestructura: Terraform, Docker, Helm)
  ├── ops-fix/...    (correcciones operacionales)
  └── deploy/...     (configuración de despliegues y pipelines)
```

### Convenciones de nombres

| Tipo | Formato | Ejemplo |
|------|---------|---------|
| Infraestructura | `infra/<descripción>` | `infra/kafka-upgrade-3.8` |
| Corrección ops | `ops-fix/<descripción>` | `ops-fix/certificate-renewal` |
| Despliegue | `deploy/<descripción>` | `deploy/enable-monitoring` |

**Reglas de naming:** minúsculas, guiones (no underscores), máximo 50 caracteres.

### Reglas de operaciones

1. Cambios en `terraform/`, `docker-compose.yml`, `.github/workflows/` e `infrastructure/` requieren PR con revisión.
2. El pipeline de infra ejecuta `terraform plan` automáticamente en PRs para previsualizar cambios.
3. `terraform apply` solo se ejecuta en `main` con environment `production` (requiere aprobación manual en GitHub).
4. Los secretos se gestionan exclusivamente vía **GitHub Secrets** (nunca en código).
5. Cada PR de ops debe incluir un **plan de rollback** documentado.
6. Las ramas no deben durar más de **5 días**; los cambios de infra pueden tomar más que código, pero se deben hacer commits progresivos.

### Conventional Commits (Ops)

```
ops(componente): descripción breve

ops(kafka):     upgrade to 3.8.0
ops-fix(postgres): increase backup retention
deploy(ci):     add staging validation step
chore(infra):   update helm chart version
```

### Flujo de trabajo

1. **Crear rama** desde `main` actualizado con el prefijo adecuado (`infra/`, `ops-fix/`, `deploy/`).
2. **Realizar los cambios** de infraestructura (Terraform, Docker Compose, workflows, Helm).
3. **Validar localmente** que los cambios son correctos (ej: `terraform plan`, `helm lint`, `docker compose config`).
4. **Push** de la rama y crear Pull Request con descripción de los cambios y plan de rollback.
5. **Revisión automática**: el pipeline ejecuta validaciones (format, init, validate, plan).
6. **Review** por parte del otro miembro del equipo; verificar que el plan de Terraform es correcto.
7. **Merge** a `main` — en caso de Terraform, el apply se ejecuta automáticamente tras aprobación manual del environment.

---

## 4. Patrones de diseño de nube

### Patrón 1: Competing Consumers

**Referencia:** [Microsoft Cloud Design Patterns - Competing Consumers](https://learn.microsoft.com/en-us/azure/architecture/patterns/competing-consumers)

#### Descripción

El patrón Competing Consumers permite que múltiples instancias de un consumidor procesen mensajes de la misma cola de forma concurrente. Cada mensaje es procesado por un solo consumidor, distribuyendo la carga de trabajo entre las réplicas.

#### Implementación en el proyecto

```
                                              ┌─────────────────────────┐
                                         ┌───►│ VoteProcessor Replica 1 │──┐
                                         │    │ (Go)                    │  │
┌──────────┐   Kafka    ┌──────────────┐ │    └─────────────────────────┘  │
│  Vote    │──────────►│VoteTaskConsumer│─┤    ┌─────────────────────────┐  ├──► DB
│ (Java)   │  "votes"  │(Consumer Group:│ ├───►│ VoteProcessor Replica 2 │──┤
└──────────┘           │ worker-group)  │ │    │ (Go)                    │  │
                       └──────────────┘ │    └─────────────────────────┘  │
                                         │    ┌─────────────────────────┐  │
                                         └───►│ VoteProcessor Replica 3 │──┘
                                              │ (Go)                    │
                                              └─────────────────────────┘
```

**Configuración del Consumer Group** (`worker/main.go`):
```go
groupID = kingpin.Flag("group", "Consumer group ID").Default("worker-group").String()

// Cada réplica se une al mismo grupo; Kafka distribuye particiones entre ellas
config.Consumer.Group.Rebalance.GroupStrategies = []sarama.BalanceStrategy{
    sarama.NewBalanceStrategyRoundRobin(),
}
group, _ := sarama.NewConsumerGroup(brokers, *groupID, config)
```

**ConsumerGroupHandler** (`worker/main.go`):
```go
func (c *VoteTaskConsumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
    for msg := range claim.Messages() {
        // Cada réplica procesa solo los mensajes que Kafka le asigna
        fmt.Printf("[Replica] Received message #%d: user %s vote %s (partition %d)\n",
            count, voterID, vote, msg.Partition)
        c.store.PersistVote(voterID, vote)
        session.MarkMessage(msg, "")
    }
    return nil
}
```

**Docker Compose** — 3 réplicas compitiendo por mensajes:
```yaml
worker:
  build: ./worker
  deploy:
    replicas: 3   # 3 VoteProcessor Replicas
```

**Kafka configurado con 3 particiones** para permitir paralelismo real:
```yaml
kafka:
  environment:
    KAFKA_NUM_PARTITIONS: 3
```

**Beneficios en esta arquitectura:**
- **Escalabilidad horizontal**: Cada réplica procesa un subconjunto de particiones.
- **Tolerancia a fallos**: Si una réplica cae, Kafka reasigna sus particiones a las demás.
- **Throughput**: 3 réplicas procesan votos en paralelo.
- **Rebalanceo automático**: Sarama usa `RoundRobin` para distribuir particiones equitativamente.

---

### Patrón 2: Circuit Breaker

**Referencia:** [Microsoft Cloud Design Patterns - Circuit Breaker](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)

#### Descripción

El patrón Circuit Breaker previene que un servicio siga intentando una operación que probablemente fallará, evitando cascada de fallos. Tiene tres estados: **Closed** (normal), **Open** (rechaza llamadas) y **Half-Open** (prueba con pocas llamadas).

#### Implementación en el proyecto

Se implementan **dos** Circuit Breakers, uno para escrituras y otro para lecturas:

```
  Worker Service                                Result Service
  ══════════════                                ══════════════

  VoteProcessor Replica ──► DbWriteCircuitBreaker ──► VoteStoreAdapter ──► PostgreSQL
                            (5 fallos → OPEN)                                │
                            (10s timeout → HALF-OPEN)                        │
                            (2 éxitos → CLOSED)                              │
                                                                             │
  ResultsPollingService ──► DbReadCircuitBreaker ──► ResultsDbReader ────────┘
                            (5 fallos → OPEN)
                            (10s timeout → HALF-OPEN)
                            (2 éxitos → CLOSED)
```

**DbWriteCircuitBreaker** (`worker/main.go`):
```go
type CircuitBreaker struct {
    state            CircuitState   // CLOSED → OPEN → HALF-OPEN
    failureThreshold int            // 5 fallos consecutivos → OPEN
    successThreshold int            // 2 éxitos en HALF-OPEN → CLOSED
    openTimeout      time.Duration  // 10s en OPEN → intenta HALF-OPEN
}

func (s *VoteStoreAdapter) PersistVote(voterID, vote string) error {
    return s.cb.Call(func() error {
        stmt := `INSERT INTO votes(id, vote) VALUES($1, $2) ON CONFLICT(id) DO UPDATE SET vote = $2`
        _, err := s.db.Exec(stmt, voterID, vote)
        return err
    })
}
```

**DbReadCircuitBreaker** (`result/server.js`):
```javascript
class DbReadCircuitBreaker {
  constructor({ failureThreshold = 5, successThreshold = 2, openTimeout = 10000 }) {
    this.state = 'CLOSED';
    // ...
  }
  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.openTimeout) {
        this.state = 'HALF-OPEN';  // probar de nuevo
      } else {
        throw new Error('Circuit breaker is OPEN – call rejected');
      }
    }
    // ejecutar fn → éxito cierra, fallo abre
  }
}

// Uso en el polling de resultados
function getVotes(client) {
  circuitBreaker.call(() => resultsDbReader(client))
    .then(result => io.sockets.emit('scores', JSON.stringify(votes)))
    .catch(err => console.error('[CircuitBreaker] Query failed: ' + err.message));
}
```

**Beneficios en esta arquitectura:**
- **Protección ante caídas de BD**: Si PostgreSQL cae, los servicios no saturan la conexión.
- **Fail fast**: En estado OPEN, las llamadas se rechazan inmediatamente sin esperar timeout.
- **Auto-recuperación**: Después de 10s en OPEN, prueba con HALF-OPEN y vuelve a CLOSED si tiene éxito.
- **Visibilidad**: Logs claros del cambio de estado para debugging.

---

## 5. Diagrama de arquitectura

### Diagrama UML de despliegue

El siguiente diagrama representa la arquitectura del sistema usando notación **UML de despliegue** (deployment diagram). Modela los nodos físicos/virtuales (`«device»`), los componentes desplegados en cada uno (`«component»`), sus interfaces (`lollipop`) y las rutas de comunicación entre nodos (`«communication path»`).

Los dos patrones de diseño están resaltados visualmente:
- 🟢 **Competing Consumers** — `worker-service`: tres réplicas `VoteProcessor` comparten el mismo Consumer Group, cada una procesa particiones distintas del topic `votes`.
- 🟡 **Circuit Breaker** — `DbWriteCircuitBreaker` (escrituras Worker → PostgreSQL) y `DbReadCircuitBreaker` (lecturas Result → PostgreSQL).

![Diagrama de arquitectura UML](docs/architecture.png)

> **Archivo editable:** [`Ingesoft.drawio`](Ingesoft.drawio) — abrir con [draw.io](https://app.diagrams.net/).

---

### Diagrama general del sistema

```
                          ┌───────────────────────────────────────────────────────┐
                          │              SERVICIOS (Docker Containers)             │
                          │                                                       │
   ┌──────────┐          │  ┌─────────────┐    ┌─────────┐    ┌──────────────┐  │
   │ Usuario  │──────────┼─►│ Vote        │───►│  Kafka  │───►│   Worker x3  │  │
   │ (Browser)│  HTTP    │  │ Java/Spring │    │ KRaft   │    │   Go/Sarama  │  │
   │          │  :8080   │  │ :8080       │    │ :9092   │    │ ConsumerGroup│  │
   └──────────┘          │  └─────────────┘    │ 3 part. │    │ worker-group │  │
                          │                     └─────────┘    └──────┬───────┘  │
                          │                                           │          │
                          │   Competing Consumers              DbWrite│CB        │
                          │   (Patrón 1)                              │          │
                          │                                           ▼          │
   ┌──────────┐          │  ┌─────────────┐    DbRead CB     ┌──────────────┐   │
   │ Usuario  │◄─────────┼──│ Result      │◄─────────────────│  PostgreSQL  │   │
   │ (Browser)│ Socket.io│  │ Node.js     │  polling + CB     │  :5432       │   │
   │          │  :80     │  │ :80         │                   │  DB: votes   │   │
   └──────────┘          │  └─────────────┘                   └──────────────┘   │
                          │                                                       │
                          │   Circuit Breaker (Patrón 2)                          │
                          │   Write: Worker ──► DbWriteCB ──► DB                  │
                          │   Read:  Result ──► DbReadCB  ──► DB                  │
                          │                                                       │
                          └───────────────────────────────────────────────────────┘
                                              │
                                         Dockerfiles
                                              │
                          ┌───────────────────────────────────────────────────────┐
                          │              INFRAESTRUCTURA (Azure + Terraform)       │
                          │                                                       │
                          │   Terraform → Azure VM (Windows Server 2022)          │
                          │   Resource Group, VNet, Subnet, NSG, Public IP        │
                          │                                                       │
                          └───────────────────────────────────────────────────────┘
                                              │
                                        GitHub Actions
                                              │
                          ┌───────────────────────────────────────────────────────┐
                          │                  CI/CD PIPELINES                       │
                          │                                                       │
                          │   ci-dev.yml:   Build → Test → Docker Push (GHCR)     │
                          │   ci-infra.yml: Terraform Plan → Apply                │
                          │                                                       │
                          └───────────────────────────────────────────────────────┘
```

### Diagrama de flujo de datos

```
                                                   ┌───── VoteProcessor Replica 1 ──┐
  ┌────────┐  POST /     ┌──────┐  kafka.send()   │                                 │
  │Browser │────────────►│ Vote │───────────────►┌─┤ VoteTaskConsumer               │
  │        │  vote=a|b   │(Java)│  topic:"votes" │ │ (ConsumerGroup: worker-group)   ├──► DbWriteCB
  └────────┘             └──────┘  key:voter_id  │ ├───── VoteProcessor Replica 2 ──┤     │
                                   3 partitions  │ │                                 │     ▼
                                                 │ └───── VoteProcessor Replica 3 ──┘  PostgreSQL
                                                 └──────────────────────────────────┘     │
                                                                                          │
  ┌────────┐  Socket.io  ┌────────┐  DbReadCircuitBreaker  ┌────────────┐                │
  │Browser │◄────────────│ Result │◄───────────────────────│ PostgreSQL │────────────────┘
  │        │  scores{}   │(NodeJS)│  polling cada 1000ms   │  (votes)   │
  └────────┘             └────────┘                        └────────────┘
```

### Diagrama del pipeline CI/CD

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                    CI/CD PIPELINE (GitHub Actions)                    │
  │                                                                      │
  │  PIPELINE DE DESARROLLO (ci-dev.yml)                                 │
  │  ┌──────────┐    ┌──────────┐    ┌───────────┐                     │
  │  │  Detect  │───►│  Build   │───►│  Docker   │                     │
  │  │  Changes │    │  & Test  │    │  Push     │                     │
  │  │          │    │          │    │  (GHCR)   │                     │
  │  └──────────┘    └──────────┘    └───────────┘                     │
  │   paths-filter    mvn/go/npm     ghcr.io/...                        │
  │                                                                      │
  │  PIPELINE DE INFRA (ci-infra.yml)                                    │
  │  ┌──────────────────────────────────────────────────────────────┐   │
  │  │  terraform fmt → init → validate → plan → [apply en main]   │   │
  │  └──────────────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────────────────┘
```

> **Nota:** El archivo `Ingesoft.drawio` en la raíz del proyecto contiene el diagrama editable en Draw.io con más detalle visual.

---

## 6. Pipelines de desarrollo

**Archivo:** `.github/workflows/ci-dev.yml`

### Estructura del pipeline

```
ci-dev.yml
│
├── changes          → Detecta qué servicios cambiaron (paths-filter)
│
├── vote-build       → mvn clean package + mvn test (Java 22)
├── vote-docker      → Build & push imagen a GHCR
│
├── worker-build     → go build + go vet (Go 1.24.1)
├── worker-docker    → Build & push imagen a GHCR
│
├── result-build     → npm ci + npm audit (Node.js 22)
└── result-docker    → Build & push imagen a GHCR
```

### Características clave

| Característica | Detalle |
|----------------|---------|
| **Trigger** | Push a `main`, `develop`, `release/*`; PRs a `main`, `develop` |
| **Detección selectiva** | Solo construye servicios que realmente cambiaron |
| **Registry** | GitHub Container Registry (`ghcr.io`) |
| **Tags de imagen** | Por SHA del commit + nombre de rama |
| **Artefactos** | Upload de JARs, binarios y app como artifacts |

### Etapas por servicio

#### Vote (Java/Spring Boot)
```yaml
# Build
- uses: actions/setup-java@v4 (JDK 22, Temurin)
- mvn clean package -B
- mvn test -B

# Docker
- docker/build-push-action (multi-stage: maven builder + temurin:22-jre)
```

#### Worker (Go)
```yaml
# Build
- uses: actions/setup-go@v5 (Go 1.24.1)
- go mod download
- CGO_ENABLED=0 GOOS=linux go build -v -o worker main.go
- go vet ./...

# Docker
- docker/build-push-action (multi-stage: golang bookworm + scratch)
```

#### Result (Node.js)
```yaml
# Build
- uses: actions/setup-node@v4 (Node 22)
- npm ci || npm install
- npm audit --audit-level=high

# Docker
- docker/build-push-action (node:22-slim + tini)
```

---

## 7. Pipelines de infraestructura

**Archivo:** `.github/workflows/ci-infra.yml`

### Estructura del pipeline

```
ci-infra.yml
│
├── terraform-plan    → fmt check → init → validate → plan
└── terraform-apply   → apply (solo main + aprobación manual)
```

### Terraform Pipeline

| Etapa | Comando | Propósito |
|-------|---------|-----------|
| Format | `terraform fmt -check -recursive` | Verifica formato estándar |
| Init | `terraform init` | Descarga providers (azurerm, random) |
| Validate | `terraform validate` | Validación sintáctica |
| Plan | `terraform plan -out=tfplan` | Preview de cambios |
| Apply | `terraform apply -auto-approve tfplan` | Aplica cambios (solo en main) |

### Secretos necesarios en GitHub

| Secreto | Propósito |
|---------|-----------|
| `AZURE_CLIENT_ID` | Service Principal para Terraform |
| `AZURE_CLIENT_SECRET` | Credencial del SP |
| `AZURE_SUBSCRIPTION_ID` | Suscripción Azure |
| `AZURE_TENANT_ID` | Tenant Azure AD |

---

## 8. Implementación de la infraestructura

### 8.1 Infraestructura Azure (Terraform)

**Directorio:** `terraform/terraform-azure-vm/`

Terraform provisiona una VM Windows Server en Azure:

| Recurso | Tipo | Detalle |
|---------|------|---------|
| Resource Group | `azurerm_resource_group` | Nombre dinámico con random_pet |
| Virtual Network | `azurerm_virtual_network` | `10.0.0.0/16` |
| Subnet | `azurerm_subnet` | `10.0.1.0/24` |
| Public IP | `azurerm_public_ip` | Estática |
| NSG | `azurerm_network_security_group` | Reglas: RDP (3389), HTTP (80) |
| NIC | `azurerm_network_interface` | Conecta VM a subnet + IP pública |
| Storage Account | `azurerm_storage_account` | Para boot diagnostics |
| VM | `azurerm_windows_virtual_machine` | Windows Server 2022, Standard_B1s |
| Extension | `azurerm_virtual_machine_extension` | Instala IIS automáticamente |

**Comandos para desplegar:**

```bash
cd terraform/terraform-azure-vm

# Autenticarse con Azure
az login

# Inicializar y desplegar
terraform init
terraform plan -out=main.tfplan
terraform apply main.tfplan

# Ver outputs
terraform output -raw public_ip_address
terraform output -raw admin_password
```

### 8.2 Infraestructura Kubernetes (Helm Charts)

**Directorio:** `infrastructure/`

| Componente | Imagen | Puerto | Persistencia |
|-----------|--------|--------|-------------|
| **PostgreSQL** | `postgres:16` | 5432 | PVC 1Gi |
| **Kafka** | `apache/kafka:3.7.0` | 9092 (broker), 9093 (controller) | PVC 1Gi |

Ambos componentes tienen:
- Liveness probes y readiness probes
- Resource limits (CPU + memoria)
- Persistent Volume Claims
- Services ClusterIP

**Kafka en KRaft mode** (sin Zookeeper):
- `KAFKA_PROCESS_ROLES: broker,controller`
- `KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093`

### 8.3 Servicios de aplicación (Helm Charts)

| Servicio | Chart | Imagen | Puerto | Ingress |
|----------|-------|--------|--------|---------|
| Vote | `vote/chart/` | `okteto.dev/vote` | 8080 | Sí (Okteto auto-host) |
| Worker | `worker/chart/` | `okteto.dev/worker` | N/A | No |
| Result | `result/chart/` | `okteto.dev/result` | 80 | Sí (Okteto auto-host) |

**Despliegue completo con Okteto:**

```bash
# Login y deploy automático
okteto login
okteto deploy

# O manualmente con Helm
helm upgrade --install infrastructure infrastructure/
helm upgrade --install vote vote/chart --set image=<registry>/vote:<tag>
helm upgrade --install result result/chart --set image=<registry>/result:<tag>
helm upgrade --install worker worker/chart --set image=<registry>/worker:<tag>
```

---

## 9. Demostración en vivo de cambios en el pipeline

### Escenario de demostración

Se recomienda el siguiente flujo para la demostración en vivo:

#### Paso 1: Cambio en el servicio Vote (mostrar pipeline dev)

```bash
# Crear rama feature
git checkout -b feature/vote-change-options

# Cambiar las opciones de votación
# En vote/src/.../controller/VoteController.java:
# Cambiar "Burritos" por "Pizza" y "Tacos" por "Hamburguesa"

git add . && git commit -m "feat(vote): cambiar opciones de votación"
git push origin feature/vote-change-options
```

**Resultado esperado:** El pipeline `ci-dev.yml` se activa, detecta cambios solo en `vote/`, ejecuta build + test de Java, construye imagen Docker.

#### Paso 2: Crear PR y merge (mostrar deploy)

```bash
# Crear PR en GitHub
# → Pipeline corre en PR
# → Review + Approve
# → Merge a main
# → Pipeline de deploy se ejecuta automáticamente
```

**Resultado esperado:** Tras el merge a `main`, se construye y publica la imagen Docker actualizada en GHCR.

#### Paso 3: Cambio de infraestructura (mostrar pipeline infra)

```bash
git checkout -b infra/add-https-rule

# Agregar regla HTTPS al NSG en terraform/terraform-azure-vm/main.tf:
# security_rule { name = "HTTPS", priority = 1002, port = "443", ... }

git add . && git commit -m "infra: agregar regla HTTPS al NSG"
git push origin infra/add-https-rule
```

**Resultado esperado:** Pipeline de infra ejecuta `terraform plan` mostrando la nueva regla. Tras merge a main, `terraform apply` la crea.

#### Paso 4: Verificar resultados

```bash
# Ver las imágenes publicadas en GitHub Container Registry
# → github.com/<usuario>/<repo>/pkgs

# Ver el estado del Terraform
terraform show

# Verificar la VM en Azure
az vm show -g <resource-group> -n <vm-name>
```

---

## 10. Entrega de resultados

### Estructura del repositorio final

```
microservices-demo/
├── .github/
│   └── workflows/
│       ├── ci-dev.yml                 # Pipeline de desarrollo
│       └── ci-infra.yml               # Pipeline de infraestructura
├── docs/
│   └── TALLER.md                      # Este documento
├── infrastructure/                    # Helm chart: Kafka + PostgreSQL
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── kafka.yaml
│       └── postgresql.yaml
├── vote/                              # Servicio Java (Publisher)
│   ├── Dockerfile
│   ├── pom.xml
│   ├── chart/                         # Helm chart
│   └── src/
├── worker/                            # Servicio Go (Subscriber/Writer)
│   ├── Dockerfile
│   ├── go.mod
│   ├── main.go
│   ├── Makefile
│   └── chart/                         # Helm chart
├── result/                            # Servicio Node.js (Query/Reader)
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   ├── chart/                         # Helm chart
│   └── views/
├── terraform/                         # IaC para Azure VM
│   └── terraform-azure-vm/
│       ├── main.tf
│       ├── variables.tf
│       ├── providers.tf
│       └── outputs.tf
├── docker-compose.yml                     # Ejecución local (worker x3)
├── okteto.yml                         # Config desarrollo local
├── Ingesoft.drawio                    # Diagrama editable
└── README.md
```

### Resumen de tecnologías

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Frontend votación | Java / Spring Boot / Thymeleaf | 3.4.1 / Java 22 |
| Cola de mensajes | Apache Kafka (KRaft) | 3.7.0 |
| Worker/consumer | Go / Sarama (ConsumerGroup) | 1.24.1 |
| Base de datos | PostgreSQL | 16 |
| Frontend resultados | Node.js / Express / Socket.io / AngularJS | 22.12.0 |
| Contenedores | Docker (multi-stage builds) | - |
| Orquestación | Kubernetes / Helm | v2 charts |
| IaC | Terraform / Azure Provider | >= 1.0 / ~4.0 |
| CI/CD | GitHub Actions | v4 |
| Dev local | Okteto | - |

### Patrones implementados

| # | Patrón | Dónde | Implementación |
|---|--------|-------|----------------|
| 1 | **Competing Consumers** | Worker Service (Go) | 3 réplicas con `sarama.ConsumerGroup` (group: `worker-group`), Kafka con 3 particiones, rebalanceo RoundRobin |
| 2 | **Circuit Breaker** | Worker (`DbWriteCircuitBreaker`) + Result (`DbReadCircuitBreaker`) | Estados CLOSED→OPEN→HALF-OPEN; 5 fallos → OPEN, 10s timeout, 2 éxitos → CLOSED |

### Configuración de GitHub necesaria

1. **Repository Settings → Branches → Branch protection rules:**
   - Branch `main`: Require PR, require status checks, require review
2. **Repository Settings → Environments:**
   - Crear environment `production` con required reviewers
3. **Repository Settings → Secrets and variables → Actions:**
   - Agregar: `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`
