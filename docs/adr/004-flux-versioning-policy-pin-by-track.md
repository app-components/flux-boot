# ADR-003: Flux Versioning Policy — Pin by Track

**Date:** 2025-11-06  
**Status:** Accepted  


## Context and Problem Statement

The `flux-boot` project defines the declarative bootstrap layer that installs and maintains Flux itself.  
It forms the foundation of the GitOps control plane: once applied, the cluster continuously reconciles its own state from Git.  

To preserve **reproducibility, auditability, and security**, this bootstrap layer must evolve in a controlled and predictable way.  
Without a clear versioning and upgrade policy, clusters can silently drift between patch levels of Flux or its controllers, leading to inconsistent behavior even when configuration appears identical.

To prevent such drift, `flux-boot` must define:

- how it mirrors upstream Flux releases,  
- which updates occur automatically,  
- which require human intent, and  
- how all upgrades remain deterministic and reviewable.  

## Decision

`flux-boot` mirrors the **FluxCD release cadence and version numbers**, adopting the same `major.minor.patch` scheme (e.g., `2.7.1`).  
Each upstream Flux release is rendered into a static, reproducible YAML manifest stored under `/release`.

Automatic upgrades occur **only within a version track** (e.g., `2.7.x`).  
Advancing to a new minor (`2.8.x`) or major (`3.x`) release requires **explicit intent**, such as editing the manifest reference or re-bootstrapping the Flux layer.

| Version Type | Example | Change Scope | Upgrade Mechanism |
|---------------|----------|--------------|------------------|
| **Patch (x.y.Z)** | 2.7.1 → 2.7.2 | Security fixes / controller updates | Automatic via Flux reconciliation (`flux-2.7.x.yaml`) |
| **Minor (x.Y.z)** | 2.7 → 2.8 | Feature additions / dependency bumps | Manual update or re-bootstrap |
| **Major (X.y.z)** | 2.x → 3.0 | Breaking or architectural change | Manual migration guided by release notes |

### Release Directory Structure

```
release/
├── manifests/      # Immutable, version-specific manifests
│   ├── flux-2.7.1.yaml
│   ├── flux-2.7.2.yaml
│   └── flux-2.8.0.yaml
└── tracks/         # Rolling patch references (latest within a version line)
    ├── flux-2.7.x.yaml
    └── flux-2.8.x.yaml
```

- **`/release/manifests`** contains immutable YAMLs — each bound to a specific Flux version.  
- **`/release/tracks`** contains rolling patch references that always point to the latest patch within a given line (e.g., `flux-2.7.x.yaml`).  
- All manifests are produced using the *Render Once, Reconcile Forever* process described in [ADR-002](./002-render-once-reconcile-forever.md).  

## Upgrade Philosophy

1. **Pin by track.**  
   Clusters pin to a track (e.g., `flux-2.7.x`) to automatically receive safe patch updates.

2. **Reconcile, don’t mutate.**  
   The system never self-updates; reconciliation simply re-applies declarative manifests.

3. **Intent for larger changes.**  
   Moving to a new minor (`flux-2.8.x`) or major (`flux-3.x`) version requires deliberate human action.

4. **Declarative rollback.**  
   Any earlier manifest from `/release/manifests` can be re-applied to restore the previous state.

## Rationale

| Concern | Policy Response |
|----------|----------------|
| **Determinism** | Immutable YAMLs ensure reproducible Flux bootstraps across environments and time. |
| **Security** | Automatic patch reconciliation ensures timely CVE fixes and stable controller updates. |
| **Auditability** | Each release has a unique Git tag and verifiable manifest hash. |
| **Predictability** | Version numbers mirror upstream Flux; no hidden upgrades. |
| **Air-Gapped Operation** | All YAMLs are self-contained; no runtime network access required. |
| **Operational Simplicity** | Reconciliation behavior is driven purely by Git state. |

## Responsibilities

| Actor | Responsibility |
|-------|----------------|
| **Maintainers** | Mirror upstream Flux releases, render and commit immutable YAMLs under `/release/manifests`, update `/release/tracks/flux-x.y.x.yaml`, and tag Git versions. |
| **Cluster Operators** | Pin to a track (e.g., `flux-2.7.x`), accept automatic patch reconciliation, and manually promote to new minor/major versions when appropriate. |
| **Flux Controllers** | Reconcile only what Git declares — never auto-advance beyond the pinned track. |

## Security Alignment

Patch updates are **security-critical** and must flow automatically through the tracking files in `/release/tracks`.  
Disabling patch reconciliation undermines the project’s security posture and is considered non-compliant.

See [ADR-004 – Security and Auto-Patching Policy](./004-security-and-auto-patching-policy.md) for enforcement and automation details.

## Consequences

### Positive
- Automatic patch upgrades within each track  
- Immutable, auditable manifests for every version  
- Deterministic rebuilds and consistent GitOps behavior  
- Secure and air-gap-friendly by design  

### Negative
- Manual effort required for minor/major upgrades  
- Maintenance overhead to update tracking files  
- Slight delay in adopting new Flux features  

## Relationship to Other ADRs

| Related ADR | Relationship |
|--------------|--------------|
| **000 – Vision for Kubernetes Cluster Management** | Establishes the declarative, headless philosophy that underpins this policy. |
| **001 – Select FluxCD as GitOps Engine** | Defines the reconciliation model mirrored here. |
| **002 – Render Once, Reconcile Forever** | Describes the rendering process that produces these release YAMLs. |
| **004 – Security and Auto-Patching Policy** | Expands on automation and compliance enforcement. |

## Summary

`flux-boot` mirrors upstream Flux releases as static YAML manifests under `/release/manifests/`, with corresponding rolling patch references under `/release/tracks/`.  
Clusters **pin to a track** (e.g., `flux-2.7.x`) to receive **automatic patch updates**, while minor and major upgrades require explicit human intent.  
All releases are immutable, reproducible, and reconciled declaratively — ensuring secure, deterministic, and auditable upgrades consistent with ADR-000 through ADR-002.
