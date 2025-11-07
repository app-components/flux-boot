# ADR-001: Select FluxCD as the GitOps Engine 

**Date:** 2025-11-06  
**Status:** Accepted

## Context

Following [ADR-000 – System Architecture for Kubernetes Cluster Management](./000-vision-for-kubernetes-cluster-managment.md),  
**Layer 1 (Bootstrap)** transforms a raw Kubernetes cluster into a **self-reconciling, declarative control plane**.  
It must remain **minimal, deterministic, headless, and reproducible** — no dynamic templating, mutable automation, or hidden runtime state.

Candidate GitOps engines:

- **FluxCD** (GitOps Toolkit controllers)
- **Carvel kapp-controller**
- **Argo CD**

## Decision

Adopt **FluxCD** as the **GitOps engine** for Layer 1 and all higher layers.  
Flux is a modular, CRD-native, and composable framework that aligns with the layered, contract-driven model defined in ADR-000.

### Included Controllers
| Controller | Included | Purpose |
|-------------|-----------|----------|
| `source-controller` | ✅ | Fetches and caches manifests from Git / OCI sources |
| `kustomize-controller` | ✅ | Applies manifests declaratively via Kustomize |
| `notification-controller` | ✅ | Emits events for observability and alert integration |

### Excluded Controllers
| Controller | Status | Rationale |
|-------------|---------|------------|
| `helm-controller` | ❌ | Mutable runtime templating; breaks deterministic contract |
| `image-reflector-controller` | ❌ | Tracks mutable image tags; non-declarative |
| `image-automation-controller` | ❌ | Performs runtime Git commits; violates audit-only workflow |

## Rationale

FluxCD best satisfies the principles of ADR-000:

| Principle | FluxCD Alignment |
|------------|------------------|
| **Declarative Contracts** | Every function is exposed as a Kubernetes CRD — auditable in Git. |
| **Deterministic Bootstrap** | No databases or servers; small, self-contained controllers. |
| **Composable Architecture** | Independent controllers with fine-grained ownership boundaries. |
| **Headless Operation** | No UI or custom API server — ideal for CLI and AI-agent automation. |
| **Air-Gap Compatibility** | Static Git or OCI sources only; no external dependencies. |
| **Security and RBAC Reuse** | Uses standard Kubernetes RBAC, reducing extra trust surfaces. |
| **Observable and Extensible** | Notification Controller provides events; custom controllers can extend behavior without central UI. |

### Why not Carvel kapp-controller
- Smaller ecosystem and no native notification system.
- Less integration with the broader Flux Toolkit ecosystem.

### Why not Argo CD
- Monolithic server and required UI conflict with the headless architecture.
- Maintains its own RBAC model instead of using Kubernetes RBAC.
- Centralized, multi-cluster design opposes the cluster-local reconciliation model defined in ADR-000.
- Argo CD’s interactive UI helps developers but diverges from strict GitOps principles

## Consequences

**Positive**
- Minimal bootstrap footprint (three Deployments + RBAC)
- Deterministic and auditable Git-driven state
- Headless and automation-ready
- Unified event pipeline through Notification Controller
- Aligned with cluster-local self-management model (ADR-000)

**Negative**
- No Helm templating or image automation (by design)
- Slightly more explicit YAML (`GitRepository` + `Kustomization` per layer)

## Implementation Notes
Layer 1 (`flux-boot`) installs:
- Deployments for `source-controller`, `kustomize-controller`, `notification-controller`
- Associated RBAC and ServiceAccounts in `flux-system`
- Initial `GitRepository` and `Kustomization` pointing to the `flux-boot` repository

Higher layers reuse these controllers for their own sources.

## References
- [FluxCD Documentation](https://fluxcd.io/docs/)
- [GitOps Toolkit Architecture](https://fluxcd.io/flux/concepts/)
- [Carvel kapp-controller](https://carvel.dev/kapp-controller/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Aenix Blog – *Argo CD vs Flux CD* (Andrei Kvapil, 2024)](https://blog.aenix.io/argo-cd-vs-flux-cd-7b1d67a246ca)
- [ADR-000 – System Architecture for Kubernetes Cluster Management](./000-vision-for-kubernetes-cluster-managment.md)

## Summary  

Use **FluxCD** as the GitOps engine across all layers, limited in `flux-boot` to `source-controller`, `kustomize-controller`, and `notification-controller`.  
Exclude Helm and Image controllers to maintain a deterministic, headless, declarative bootstrap consistent with ADR-000.
