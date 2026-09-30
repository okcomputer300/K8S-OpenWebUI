# Open WebUI auf Kubernetes (GitOps)

Open WebUI laüft auf Kubernetes, ausgeliefert per Argo CD aus diesem Repository.
Erreichbar unter https://openwebui.test.saas.netways.cloud

## Struktur

```
apps/openwebui/base                 Deployment, Service, PVC
apps/openwebui/overlays/production  Kustomize-Overlay: HTTPRoute, HTTP->HTTPS-Redirect, SealedSecret
argocd/root.yaml                    Root-Application (app-of-apps), einmalig anwenden
argocd/apps/                        alle Applications (siehe Tabelle)
infra/envoy-gateway                 Installation (Kustomize) + GatewayClass, Gateway, ListenerSet
infra/cert-manager                  ClusterIssuer (Let's Encrypt), Certificate
infra/sealed-secrets                Installation des Sealed-Secrets-Controllers (Kustomize)
scripts/                            seal-openwebui-secret.sh
```

## Komponenten 

| Komponente | Aufgabe | Installation |
|---|---|---|
| Argo CD | GitOps: gleicht Cluster mit dem Git-Stand ab (prune + selfHeal) | vorhanden, Zugriff per Port-Forward :8080 |
| Envoy Gateway | Gateway-API-Implementierung, nimmt den Traffic an | Kustomize (Release-`install.yaml`) |
| Gateway + ListenerSet | Gateway hat den HTTP-Listener, das ListenerSet hängt den HTTPS-Listener (443, TLS) an | Kustomize |
| cert-manager | holt/erneuert das TLS-Zertifikat bei Let's Encrypt (HTTP-01 ueber Gateway API) | Helm via Argo CD |
| Sealed Secrets | verschluesselte Secrets im Git, Controller entschluesselt im Cluster | Kustomize (Release-`controller.yaml`) |
| Open WebUI | die Anwendung, Daten auf PVC (SQLite) | Kustomize base/overlay |
| kube-prometheus-stack | Prometheus + Grafana (Port-Forward :3000) | Helm via Argo CD |
| loki-stack | Logs (Loki + Promtail), Datasource in derselben Grafana | Helm via Argo CD |

Traffic: Browser -> Envoy (Port 80: Redirect auf HTTPS / Port 443: ListenerSet, TLS-Terminierung) -> HTTPRoute -> Service `open-webui` -> Pod.

## Bootstrap

1. Argo CD ist installiert, das Repo ist dort hinterlegt.
2. `kubectl apply -f argocd/root.yaml` - Argo legt alle Applications in Reihenfolge an (Sync-Waves).
3. Sobald der Sealed-Secrets-Controller laeuft: `scripts/seal-openwebui-secret.sh` ausfuehren,
   `apps/openwebui/overlays/production/sealed-secret.yaml` committen.
4. **Master-Key sichern** (nicht ins Git!):
   `kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-master-key.yaml`
   Ohne diesen Schluessel sind die SealedSecrets nach einer Neuinstallation des Clusters nicht mehr lesbar.

## Regeln

- Deployment nur ueber Git (Merge nach `main`), nicht per `kubectl apply`.
- Die CI (`.gitlab-ci.yml`) prueft nur: yamllint + `kustomize build | kubeconform`.
- Keine Klartext-Secrets im Repo (`.gitignore` schuetzt die typischen Dateien).
- Versionen sind gepinnt (Open WebUI, Envoy Gateway, cert-manager, Sealed Secrets, Charts).