# ADR-002: Render Once, Reconcile Forever — Safe Helm Usage Pattern for Flux

**Date:** 2025-11-06  
**Status:** Accepted

## Context and Problem Statement

[ADR-001 – Select FluxCD as the GitOps Engine](./001-select-fluxcd-as-gitops-engine.md) established FluxCD as the declarative reconciliation engine for the platform.  
FluxCD includes an optional **Helm Controller** that continuously reconciles `HelmRelease` resources against upstream Helm charts.  
While convenient for dynamic chart management, **runtime templating** introduces non-determinism, audit gaps, and lifecycle inconsistencies that directly conflict with the principles defined in  
[ADR-000 – System Architecture for Kubernetes Cluster Management](./000-vision-for-kubernetes-cluster-managment.md).

Layer 1 (bootstrap) and Layer 2 (platform) must remain:

- **Deterministic and declarative** — no runtime chart rendering  
- **Static and version-pinned** — reproducible manifests committed to Git  
- **Small and stable** — minimal controller footprint for bootstrap and drift correction  
- **Air-gap-compatible and auditable** — no runtime network fetches or hidden state  

### Why Runtime Helm Templating Is Problematic

1. **Invisible Rendered Output** — In Git you can see *that* a Helm chart will be installed, but not *what YAML it produces*.  
   To inspect the actual resources, you must re-render the chart locally with identical versions and options.  
   This breaks the “Git as single source of truth” principle and prevents operators from reasoning about live state purely from version control.

2. **Lost Git-Native Audit Trail** — Because only Helm value changes are visible in Git, reviewers cannot see the manifest diffs that will actually be applied.  
   This eliminates meaningful code review, policy validation, and static security scanning.

3. **Non-Reproducible Builds** — Re-rendering a chart even **months** later may yield different manifests due to:  
   - changes in Helm CLI behavior or template evaluation semantics  
   - upstream chart defaults or conditional logic that evolve over time  
   - repository layout or dependency shifts  
   The same chart and values no longer guarantee identical manifests, violating deterministic-state principles.

4. **CRD Installation Behavior** — Helm applies CRDs *imperatively* before the rest of the chart using a built-in pre-install step.  
   These CRDs are applied directly to the cluster outside the normal Helm release lifecycle or templating process.  
   Their state is not declared or reconciled, making dependency order unpredictable for GitOps controllers and preventing idempotent re-application.

5. **CRD Upgrade Limitations** — Helm can **install** CRDs but will never **upgrade** or modify them in subsequent releases.  
   Any schema evolution, version bump, or validation change must be performed manually or by another tool.  
   This creates inconsistent “day 1 vs. day 2” handling and introduces operational fragility for long-lived clusters.

6. **Hidden Drift** — Because Helm stores internal release state in cluster secrets, resources can diverge from the declared Git state without any visible diff.  
   Drift can persist silently, undermining GitOps guarantees.

7. **Broken Provenance and Auditability** — The only complete record of rendered manifests lives in Helm release secrets.  
   These contain mutated and defaulted fields added by admission controllers, so they no longer match the true rendered output.  
   Reconstructing historical state requires scraping the cluster—an anti-pattern for GitOps and compliance workflows.

8. **Loss of Static Reasoning** — When manifests are pre-rendered and stored in Git, tools can statically analyze them to:  
   - detect deprecated or removed Kubernetes APIs  
   - verify RBAC and security policies  
   - assess compatibility with upcoming Kubernetes versions  
   With runtime Helm templating, this reasoning is impossible because the manifests don’t exist until after deployment, when it’s too late to act safely.

9. **Harder Troubleshooting and Reproduction** — Pre-rendered manifests allow teams to spin up identical troubleshooting clusters or namespace snapshots to reproduce issues with full parity.  
   Runtime Helm templating prevents this—the cluster’s state depends on an ephemeral render that may no longer be reproducible, making debugging and post-incident analysis significantly harder.

In short, **runtime Helm templating hides what is actually applied, depends on mutable tooling, and prevents long-term reproducibility.**  
Pre-rendering all charts into static YAML ensures Git remains the single, auditable, and deterministic source of truth.

## Decision

This pattern treats Helm as a **build-time templating engine**, not a runtime dependency.  
By vendoring, rendering, and committing charts, we gain complete visibility into what is deployed, guarantee reproducibility across clusters and time, and eliminate the mutable, opaque behavior associated with runtime Helm operations.

Helm is ubiquitous in the Kubernetes ecosystem—most operators and vendor components are distributed as Helm charts.  
Completely avoiding Helm is neither practical nor necessary.  
Instead, we adopt a **safe, reproducible pattern** for consuming Helm content without relying on FluxCD’s Helm Controller or any runtime templating.

### Adopted Pattern: *Render Once, Reconcile Forever*

1. **Vendoring Charts**  
   - All third-party or internal Helm charts are pulled into source control using [Carvel `vendir`](https://carvel.dev/vendir/).  
   - Each chart and dependency is **pinned to an explicit version** and stored in Git for full provenance and auditability.  
   - Vendored charts reside under deterministic paths (e.g., `charts/<name>/<version>/`) to ensure traceability across releases.

2. **Rendering Manifests**  
   - A `render.sh` script renders each vendored chart into static YAML using `helm template`.  
   - The script uses the pinned chart version and corresponding `values.yaml` for that release.  
   - Rendered manifests are stored under versioned directories such as `rendered/<component>/release-1.0/manifest.yaml`.  
   - The script must record the Helm version used for rendering (for example, `# rendered-with: helm v3.15.0`) to guarantee reproducibility.

3. **Commit and Reconcile**  
   - The rendered YAML is committed to Git and reconciled by FluxCD via standard `GitRepository` + `Kustomization` objects.  
   - FluxCD **never executes Helm** at runtime—it only applies the static, version-controlled manifests.

4. **Configuration via Kustomize Overlays**  
   - Environment-specific variations (e.g., namespace, replicas, ingress hostnames) are expressed as **Kustomize overlays**, not Helm values.  
   - This preserves deterministic renders and supports the layered configuration model defined in ADR-000.

5. **Re-Rendering for Upgrades**  
   - When chart versions or configuration values change, manifests are re-rendered using the same `render.sh` script—either manually by a developer or automatically by CI.  
   - The new YAML is committed to source control, and its diff becomes part of the pull request for transparent review before deployment.  
   - In cases where upstream charts introduce parameter changes, `values.yaml` may also need updates; this edit-and-render workflow remains fully declarative and auditable.

## Consequences

### Positive
- Smaller Layer 1 footprint (no Helm Controller or CRDs)  
- Full Git visibility of every applied resource  
- Simplified security posture and compliance audits  
- Predictable upgrades through explicit manifest versions  
- Fewer bootstrap race conditions  
- Works reliably in air-gapped environments  

### Negative
- Requires manual or CI-driven re-rendering on chart upgrades  
- Less dynamic flexibility for on-the-fly Helm value overrides  
- Slightly larger repositories due to committed YAML  

## References

- [FluxCD Helm Controller documentation](https://fluxcd.io/flux/components/helm/)  
- [Carvel vendir](https://carvel.dev/vendir/)  
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/references/kustomize/)   
- [ADR-000 – System Architecture for Kubernetes Cluster Management](./000-vision-for-kubernetes-cluster-managment.md)  
- [ADR-001 – Select FluxCD as the GitOps Engine](./001-select-fluxcd-as-gitops-engine.md)  

## Summary

Adopt the *Render Once, Reconcile Forever* pattern for Helm integration. Disable the FluxCD Helm 
Controller across all layers and replace runtime Helm templating with a build-time rendering 
workflow: vendor charts with `vendir`, render them with `helm template`, commit the output to Git, 
and let FluxCD reconcile static YAML. This ensures deterministic, auditable, and air-gap-friendly 
GitOps operations consistent with the headless, declarative architecture defined in ADR-000.

| Concern | Helm Controller | Build-Time Rendering Pattern |
|----------|----------------|------------------------------|
| **Reproducibility** | Depends on remote repos and mutable CLI | Fully pinned YAML, deterministic rebuilds |
| **Security / Auditability** | State hidden in cluster secrets | All manifests visible in Git |
| **CRD Management** | Imperative install, no upgrades | Declarative and version-controlled |
| **Air-gapped Support** | Needs network access to fetch charts | Vendir vendors everything into repo |
| **Operational Simplicity** | Adds extra controller and CRDs | Uses only Flux Source + Kustomize |
| **Drift Correction** | Indirect via Helm release secrets | Direct via Git and Flux reconciliation |
