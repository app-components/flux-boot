# ADR-003: Flux Versioning Policy — Pin by Track, Reconcile by Patch

**Date:** 2025-11-06  
**Status:** Accepted  
**Context:** `flux-boot` repository

---

## Context and Problem Statement

The `flux-boot` project defines the declarative bootstrap layer that installs and maintains Flux itself — the foundation of the GitOps control plane.  
To keep clusters **deterministic, auditable, and secure**, the bootstrap layer must evolve in a **controlled, track-based** manner.

Without explicit versioning discipline, clusters can silently drift between controller versions or patch levels, leading to inconsistent behavior even when configuration appears identical.  
The repository therefore requires a clear policy for:

- how Flux versions are represented and released,
- which updates occur automatically,
- which require human intent, and
- how reconciliation remains safe and predictable.

---

## Decision

`flux-boot` mirrors the **FluxCD release cadence and version numbers**, adopting the same `major.minor.patch` scheme (for example, `2.7.3`).  
Each upstream Flux release is rendered into a static, reproducible YAML manifest stored under `/release/manifests`.  
Automatic upgrades occur **only within a version track** (for example, `2.7.x`).  
Advancing to a new minor (`2.8.x`) or major (`3.x`) line requires **explicit human action**.

| Version Type | Example | Change Scope | Upgrade Mechanism |
|---------------|----------|--------------|------------------|
| **Patch (x.y.Z)** | 2.7.2 → 2.7.3 | Security fixes / controller updates | Automatic via the track bundle (`/release/tracks/2.7/`) |
| **Minor (x.Y.z)** | 2.7 → 2.8 | New features / non-breaking updates | Manual operator promotion |
| **Major (X.y.z)** | 2.x → 3.0 | Breaking or architectural change | Manual migration guided by release notes |

---

## Repository Layout

```
release/
├── manifests/        # Immutable version-specific Flux manifests
│   ├── flux-2.7.2.yaml
│   ├── flux-2.7.3.yaml
│   └── flux-2.8.0.yaml
├── driftguard/       # Drift guard definitions (self-reconciliation)
│   ├── flux-2.7.yaml
│   └── flux-2.8.yaml
└── tracks/           # Kustomize bundles defining each version line
    ├── 2.7/
    │   └── kustomization.yaml
    └── 2.8/
        └── kustomization.yaml
```

### Example: `/release/tracks/2.7/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../manifests/flux-2.7.3.yaml
  - ../../driftguard/flux-2.7.yaml
```

This allows users or automation to bootstrap from a single remote location:

```bash
kubectl apply -k https://github.com/app-components/flux-boot.git/release/tracks/2.7/
```

That one command installs the latest patch in the 2.7 line **plus** the drift guard that keeps Flux self-reconciling.

When maintainers release `flux-2.7.4.yaml`, the only change required is updating this `kustomization.yaml` to reference the new manifest.  
Clusters tracking `2.7/` will automatically reconcile to the new patch version.

---

## Upgrade Philosophy

1. **Pin by Track** – Operators pin clusters to a minor line (for example, `2.7/`), ensuring automatic patch updates but no implicit minor jumps.
2. **Reconcile, Don’t Mutate** – Flux never self-updates arbitrarily; reconciliation simply reapplies declarative manifests from Git.
3. **Intent for Larger Changes** – Moving to a new minor or major line requires explicit human action.
4. **Declarative Rollback** – Any older manifest can be applied directly from `/release/manifests` for deterministic rollback.

---

## Rationale

| Concern | Policy Response |
|----------|----------------|
| **Determinism** | Immutable manifests guarantee identical rebuilds of any historical Flux version. |
| **Security** | Automatic patch reconciliation within a track ensures timely CVE fixes. |
| **Auditability** | Every manifest is tagged, committed, and verifiable in Git. |
| **Predictability** | Tracks define exactly what version a cluster runs — no hidden upgrades. |
| **Air-gapped Operation** | YAMLs are static; no runtime network fetches required. |
| **Operational Simplicity** | CI promotes new patches by editing a single file per track. |

---

## Responsibilities

| Actor | Responsibility |
|-------|----------------|
| **Maintainers** | Render and commit immutable manifests under `/release/manifests`, update `/release/tracks/<line>/kustomization.yaml`, and tag each release. |
| **Cluster Operators** | Bootstrap or pin to a track (for example, `2.7/`), allow automatic patch reconciliation, and manually promote to new minor or major lines when desired. |
| **Flux Controllers** | Reconcile only the resources defined in Git; never cross version lines autonomously. |

---

## Security Alignment

Patch updates within a track are **security-critical** and must flow automatically through the Kustomize bundle mechanism.  
Clusters that remain on an older patch after a new one is published are considered **non-compliant**.

For detailed enforcement and automation policy, see [ADR-004 – Self-Reconciling Bootstrap and Drift Guard Pattern](./004-self-reconciling-bootstrap.md).

---

## Consequences

### Positive
- Automatic patch updates within each track
- Immutable, auditable manifests for every version
- Deterministic rebuilds and consistent GitOps behavior
- Fully air-gap compatible
- Easy CI/CD automation (edit one line per patch release)

### Negative
- Manual promotion required for minor and major lines
- Slightly more directory complexity
- Operators must ensure track paths match their intended release

---

## Relationship to Other ADRs

| Related ADR | Relationship |
|--------------|--------------|
| **000 – Vision for Kubernetes Cluster Management** | Defines the headless, declarative philosophy that drives this policy. |
| **001 – Select FluxCD as GitOps Engine** | Establishes Flux as the controller of record for all reconciliation. |
| **002 – Render Once, Reconcile Forever** | Provides the rendering model that produces the release manifests. |
| **004 – Self-Reconciling Bootstrap (Drift Guard Pattern)** | Implements continuous reconciliation for whichever track the cluster is pinned to. |

---

## Summary

`flux-boot` mirrors upstream Flux releases as immutable YAML manifests in `/release/manifests`, with patch lines represented by **Kustomize tracks** under `/release/tracks/<minor>/`.  
Each track bundles the latest manifest and its drift guard definition.  
Clusters **pin to a track** to receive **automatic patch upgrades**, while **minor and major promotions** remain explicit and manual.  
This model ensures that Flux upgrades are **predictable, secure, auditable, and entirely declarative**, fulfilling the goals set out in ADR-000 through ADR-002.
