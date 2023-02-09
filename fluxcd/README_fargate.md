* create a Fargate profile including namespace flux-system. This will allow to deploy flux pods in Fargate pods


* in your terminal session, connect to the desired kubernetes cluster and run
```
kubectl config current-context
kubectl get pods
# set the cluster name, you can use real name or an alias like staging or production
cluster_name=
# install flux cli from https://fluxcd.io/flux/installation/#install-the-flux-cli
# check the cluster meets pre-requirements
flux check --pre
```


* use a Git repository from https://fluxcd.io/flux/installation/#bootstrap
```
# CodeCommit sample
codecommit_username=
codecommit_password=
flux bootstrap git \
  --token-auth \
  --url=https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repository \
  --username="$codecommit_username" \
  --password="$codecommit_password" \
  --branch=main \
  --path=clusters/$cluster_name
# GitHub sample
export GITHUB_TOKEN=
flux bootstrap github \
  --token-auth \
  --hostname=my-github-enterprise.com \
  --owner=my-github-organization \
  --repository=my-repository \
  --branch=main \
  --path=clusters/$cluster_name
# GitLab sample
export GITLAB_TOKEN=
flux bootstrap gitlab \
  --token-auth \
  --hostname=my-gitlab-enterprise.com \
  --owner=my-gitlab-group \
  --repository=my-repository \
  --branch=main \
  --path=clusters/$cluster_name
```


* "flux bootstrap" will fail with this error
```
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✗ client rate limiter Wait returned an error: context deadline exceeded
► confirming components are healthy
✗ helm-controller: deployment not ready
✗ kustomize-controller: deployment not ready
✗ notification-controller: deployment not ready
✗ source-controller: deployment not ready
✗ bootstrap failed with 2 health check failure(s)
```


* find the pod names
```
% kubectl get pods -n flux-system
NAME                                       READY   STATUS             RESTARTS        AGE
helm-controller-7b9bd7896b-vn2lw           0/1     CrashLoopBackOff   6 (4m33s ago)   10m
kustomize-controller-655694898f-8jpwr      0/1     CrashLoopBackOff   6 (4m32s ago)   10m
notification-controller-75fd8ffffd-nkkfq   0/1     CrashLoopBackOff   6 (2m57s ago)   10m
source-controller-cc4dc7f5-szrf2           0/1     CrashLoopBackOff   6 (3m23s ago)   10m
```


* view the pod events
```
% kubectl describe pods $pod_name  -n flux-system
Name:                 helm-controller-7b9bd7896b-vn2lw
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       StartError
      Message:      failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error setting cgroup config for procHooks process: failed to write "100000": write /sys/fs/cgroup/cpu,cpuacct/kubepods/burstable/podf33b4adc-c8f4-44dd-ae24-a987874f7f5b/e7b2f0070b548595960c84d18cd0189161662106dfc2a48a4f09b247585ae3b8/cpu.cfs_quota_us: invalid argument: unknown
      Exit Code:    128
      Started:      Wed, 31 Dec 1969 18:00:00 -0600
      Finished:     Mon, 19 Dec 2022 09:53:49 -0600
Events:
  Type     Reason           Age                  From               Message
  ----     ------           ----                 ----               -------
  Warning  LoggingDisabled  11m                  fargate-scheduler  Disabled logging because aws-logging configmap was not found. configmap "aws-logging" not found
  Normal   Scheduled        10m                  fargate-scheduler  Successfully assigned flux-system/helm-controller-7b9bd7896b-vn2lw to fargate-ip-10-108-25-34.us-west-2.compute.internal
  Normal   Pulling          10m                  kubelet            Pulling image "ghcr.io/fluxcd/helm-controller:v0.27.0"
  Normal   Pulled           10m                  kubelet            Successfully pulled image "ghcr.io/fluxcd/helm-controller:v0.27.0" in 3.311024563s
  Normal   Created          9m52s (x4 over 10m)  kubelet            Created container manager
  Warning  Failed           9m52s (x4 over 10m)  kubelet            Error: failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error setting cgroup config for procHooks process: failed to write "100000": write /sys/fs/cgroup/cpu,cpuacct/kubepods/burstable/podf33b4adc-c8f4-44dd-ae24-a987874f7f5b/manager/cpu.cfs_quota_us: invalid argument: unknown
  Normal   Pulled           9m52s (x3 over 10m)  kubelet            Container image "ghcr.io/fluxcd/helm-controller:v0.27.0" already present on machine
  Warning  BackOff          30s (x58 over 10m)   kubelet            Back-off restarting failed container
```


* Fargate has a restricted list of valid pod resources values in https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
When a resource is deployed, Fargate uses “/resources/request/cpu” and “resources/request/memory” to select a pod size. Once the pod is created, it tries to set “resources/limits/cpu” and “resources/limits/memory”. In this case, it fails because the container limits are higher than the pod limits. Fix the container limits to not exceed the Fargate pod limits.
clone the git repo created by flux bootstrap. Add these lines in clusters/$cluster_name/flux-system/kustomization.yaml
```
patches:
  - target:
      kind: Deployment
      labelSelector: app.kubernetes.io/part-of=flux
    patch: |
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: 250m
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 512M
```


* push changes
```
git add -A && git commit -m "flux pods resource limits" && git push
# run flux bootstrap again, it should succeed this time
# check pods status in namespace flux-system, everything should be running healthy
```


* view the git auth token stored in the kubernetes cluster
```
kubectl get secret flux-system -n flux-system -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

* in this sample, the app is deployed using the monorepo model from https://fluxcd.io/flux/guides/repository-structure/#repository-structure. 
We omit the infrastructure folder it is not required for this sample.


* add files containing an app template to deploy on 1 or many clusters 
  * apps/base/my-app/deployment.yaml
  * apps/base/my-app/kustomization.yaml


* add files to define what apps to deploy in each cluster and override any template values
  * apps/production/kustomization.yaml
  * apps/production/my-app.yaml
  * clusters/production/apps.yaml


* push changes
```
git add -A && git commit -m "apps" && git push
```


* apply changes
```
# apply immediately
flux reconcile kustomization apps --with-source
# or wait for flux to detect the change
flux get kustomizations --watch
```
