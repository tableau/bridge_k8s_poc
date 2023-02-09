# Deploy commands

Sync secrets
```
kubectl annotate es bridgess force-sync=$(date +%s) --overwrite -n tableau
```

Apply change immediately
```
flux reconcile kustomization apps --with-source
```

Wait for fluxcd to detect change and apply it
```
flux get kustomizations --watch
```

Check health
```
kubectl get pods -n tableau
kubectl get events -n tableau
kubectl logs bridge-site1-pool1-0 -c bridge -n tableau
kubectl logs bridge-site1-pool1-0 -c fluent-bit -n tableau
```
