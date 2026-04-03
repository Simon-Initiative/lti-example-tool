# Kubernetes Deployment

This directory contains a `kustomize`-based deployment for running `lti-example-tool` on Kubernetes.

## Layout

- `base/`: reusable application and PostgreSQL manifests
- `overlays/plasma/`: the deployable overlay used by the GitHub Actions workflow

## Secrets

The manifests expect a runtime secret named `lti-example-tool-secrets` with these keys:

- `postgres-user`
- `postgres-password`
- `postgres-db`
- `secret-key-base`
- `admin-password`

The deploy workflow creates or updates that secret automatically from GitHub Actions variables and secrets.

## Manual apply

If you want to apply the manifests yourself, create the runtime secret first and then render the overlay:

```sh
kubectl create namespace lti-example-tool --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lti-example-tool create secret generic lti-example-tool-secrets \
  --from-literal=postgres-user=postgres \
  --from-literal=postgres-password=postgres \
  --from-literal=postgres-db=lti_example_tool \
  --from-literal=secret-key-base=replace-me \
  --from-literal=admin-password=changeme \
  --dry-run=client -o yaml | kubectl apply -f -
```

Replace the placeholder values in these files before applying:

- `overlays/plasma/ingress.yaml`: `__INGRESS_HOST__`
- `base/deployment.yaml`: `__PUBLIC_URL__`

Then apply the overlay:

```sh
kubectl apply -k kubernetes/overlays/plasma
```
