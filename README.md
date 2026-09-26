# Astronomy E-commerce Shop: Microservices on AWS EKS

End-to-end DevOps implementation for a polyglot microservices e-commerce app
(the OpenTelemetry Astronomy Shop), from local containers to a GitOps-managed
Kubernetes deployment on AWS.

> 🚧 In progress. Sections are checked off as they are completed.

## Architecture

Service architecture of the OpenTelemetry demo **v2.1.3**, taken from this repo's
`docker-compose.yml`. Boxes are colored by implementation language (same palette as the
[official diagram](https://opentelemetry.io/docs/demo/architecture/)). Solid arrows are
synchronous calls; dotted arrows are asynchronous events through Kafka.

```mermaid
flowchart LR
    user([Internet users]) -- HTTP --> proxy
    mobile[React Native App] -- HTTP --> proxy
    lg[Load Generator] -- HTTP --> proxy

    proxy[Frontend Proxy<br/>Envoy] -- HTTP --> frontend[Frontend]
    proxy -- HTTP --> imgp[Image Provider<br/>nginx]
    proxy -- HTTP --> flagdui[flagd UI]

    frontend -- gRPC --> ad[Ad]
    frontend -- gRPC --> rec[Recommendation]
    frontend -- gRPC --> catalog[Product Catalog]
    frontend -- gRPC --> cart[Cart]
    frontend -- gRPC --> currency[Currency]
    frontend -- HTTP --> shipping[Shipping]
    frontend -- gRPC --> checkout[Checkout]

    rec -- gRPC --> catalog
    cart --> valkey[(Valkey<br/>cache)]

    checkout -- gRPC --> cart
    checkout -- gRPC --> catalog
    checkout -- gRPC --> currency
    checkout -- gRPC --> payment[Payment]
    checkout -- HTTP --> email[Email]
    checkout -- HTTP --> shipping
    shipping -- HTTP --> quote[Quote]

    checkout -. TCP: order events .-> kafka[(Kafka)]
    kafka -.-> acct[Accounting]
    kafka -.-> fraud[Fraud Detection]
    acct --> pg[(PostgreSQL)]

    flagd{{flagd<br/>feature flags}}

    subgraph legend [Language legend]
        direction LR
        L1[.NET]:::dotnet ~~~ L2[C++]:::cpp ~~~ L3[Elixir]:::elixir ~~~ L4[Go]:::go ~~~ L5[Java]:::java ~~~ L6[JavaScript]:::js
        L7[Kotlin]:::kotlin ~~~ L8[PHP]:::php ~~~ L9[Python]:::python ~~~ L10[Ruby]:::ruby ~~~ L11[Rust]:::rust ~~~ L12[TypeScript]:::ts
    end

    classDef dotnet fill:#2f1c79,stroke:#2f1c79,color:#fff
    classDef cpp fill:#e0587e,stroke:#e0587e,color:#fff
    classDef elixir fill:#ac95b7,stroke:#ac95b7,color:#fff
    classDef go fill:#4daad4,stroke:#4daad4,color:#fff
    classDef java fill:#a77530,stroke:#a77530,color:#fff
    classDef js fill:#eee170,stroke:#eee170,color:#000
    classDef kotlin fill:#6859f5,stroke:#6859f5,color:#fff
    classDef php fill:#515b8f,stroke:#515b8f,color:#fff
    classDef python fill:#8caf53,stroke:#8caf53,color:#fff
    classDef ruby fill:#671e1a,stroke:#671e1a,color:#fff
    classDef rust fill:#d4a788,stroke:#d4a788,color:#000
    classDef ts fill:#da8b38,stroke:#da8b38,color:#fff
    classDef ext fill:#eeeeff,stroke:#999,color:#000
    classDef store fill:#f4f4f4,stroke:#999,color:#000

    class acct,cart dotnet
    class proxy,imgp,currency cpp
    class flagdui elixir
    class catalog,checkout,flagd go
    class ad,kafka java
    class payment js
    class fraud kotlin
    class quote php
    class lg,rec python
    class email ruby
    class shipping rust
    class frontend,mobile ts
    class user ext
    class valkey,pg store
```

- **flagd** (feature flags) is read by ad, cart, checkout, email, fraud-detection,
  frontend, load-generator, payment, product-catalog and recommendation. Those links are
  left off the diagram to keep it readable.
- **Observability:** every service sends traces, metrics and logs to the OpenTelemetry
  Collector, which forwards them to Jaeger (traces), Prometheus and Grafana (metrics) and
  OpenSearch (logs).
- The upstream [architecture diagram](https://opentelemetry.io/docs/demo/architecture/)
  shows the latest release, which adds AI services (chatbot, agent, MCP) that aren't in v2.1.3.

## Tech stack

| Area | Tools |
|---|---|
| Cloud | AWS (EC2, VPC, EKS, IAM, S3, DynamoDB) |
| Containers | Docker, Docker Compose |
| Infrastructure as Code | Terraform |
| Orchestration | Kubernetes (EKS) |
| CI | GitHub Actions |
| CD / GitOps | Argo CD |

## Progress

- [ ] Environment setup (EC2, Docker, kubectl, Terraform, AWS CLI)
- [ ] Run the app locally with Docker Compose
- [ ] Containerize services (Go, Java, Python)
- [ ] Provision VPC + EKS with Terraform (remote state in S3, locking with DynamoDB)
- [ ] Kubernetes manifests + deployment to EKS
- [ ] Ingress + custom domain
- [ ] CI with GitHub Actions
- [ ] CD with Argo CD (GitOps)

## Repo layout

| Path | Contents |
|---|---|
| `src/` | Microservice source code and Dockerfiles |
| `docker-compose.yml` | Local multi-container setup |
| `terraform/` | AWS infrastructure (coming soon) |
| `kubernetes/` | K8s manifests (coming soon) |
| `.github/workflows/` | CI pipelines (coming soon) |

## Credits

- Application: [OpenTelemetry Demo](https://github.com/open-telemetry/opentelemetry-demo) v2.1.3
  (Apache 2.0; see `LICENSE` and `README.opentelemetry.md`).
- Project structure follows Abhishek Veeramalla's *Ultimate DevOps Project* course;
  the DevOps implementation in this repo is my own work.
- Used Claude (Anthropic) as a learning and debugging assistant.
