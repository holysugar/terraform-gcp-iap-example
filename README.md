# terraform-gcp-iap-example

Example using Identity-Aware Proxy on GCP

## Preparation

- Enable APIs
- [Create Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts) and download credential as `account.json`
- [Create OAuth2 Client ID](https://console.cloud.google.com/apis/credentials)
  - redirect_uri: `https://<your_domain>/_gcp_gatekeeper/authenticate`
- Set SSL certificate and get selfLink URL by REST API
  - (or define google_compute_ssl_certificate resource)

## tfvars

required

- user: name (ex. holysugar)
- basename: resource prefix (ex. holysugar-iaptrial)
- gcp_project: GCP project ID
- gcp_region: GCP region resouces will create in
- cert_url: SSL certificate URL
- iap_client_id: OAuth2 Client ID
- iap_client_secret: OAuth2 Client Secret

