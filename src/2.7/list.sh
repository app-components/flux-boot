
SOURCE_POD=$(kubectl get pods -n flux-system -l app=source-controller -o jsonpath='{.items[0].metadata.name}')
REVISION=$(kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}' | cut -d'@' -f2 | cut -d':' -f2)

# List contents without downloading
kubectl exec -n flux-system ${SOURCE_POD} -- tar -tzf /data/gitrepository/flux-system/flux-system/${REVISION}.tar.gz | head -20
