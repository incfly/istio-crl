# Istio CRL Sample Configuration

This repo contains a full E2E instructions of how to enable Certificate
Revocation List (CRL) on Istio ingress gateway. Specifically, we want to demo
that Ingress gateway would reject a client with a revoked certificate.

## Setup

1. Install Istio with versions equal or greater than 1.9.5. This contains a fix that we need to
apply the relevant EnvoyFilter.

1. Get familiar with the certificates generated as test data in `openssl-selfsigned/certs/`.

  - `newcerts/` folder contains the user cert. This contains two, user-foo@01 is revoked, user-bar@02
  is still valid.
  - `site/` is what we will use for the https traffic configured on ingress gateway
  - `certs/` root folder contains the ca certificate, crl pem etc.

You can also generate your own cert. Follow the `openssl-selfsign/readme.md`.
https cert for httpbin.example.com.

    ```shell
    ./0-init-ca.sh example.com
    ./1-sign-site.sh httpbin.example.com
    ./2-sign-user.sh user-foo
    ./2-sign-user.sh user-bar
    ./3-revoke-user.sh user-foo
    ./4-list-revoked-cert.sh
    ./5-update-crl.sh
    ```

1. Configure the ingress gateway with gateway and VirtualService Resources.

    ```shell
    kubectl create -n istio-system secret generic \
      httpbin-credential-3 --from-file=tls.key=./cert/site/example.com/cert.key   \
      --from-file=tls.crt=./cert/site/example.com/cert.crt   \
      --from-file=ca.crt=./cert/ca.crt
    kubectl create configmap envoy-crl -nistio-system \
      --from-file=openssl-selfsign/cert/crl.pem
    ka ./gw.yaml
    ka ./ef-tls.yaml
    ```

1. Verify the ingress gateway is work as expected.

    ```shell
    source ./setup.sh
    kubectl port-forward service/istio-ingressgateway 8443:443 -n istio-system
    mtlscurl user-foo@01
    mtlscurl user-bar@02
    ```

When sending requests with user-foo, you'll see error as below.

```
*  subject: O=example.com; CN=*.example.com; subjectAltName=*.example.com; emailAddress=admin@example.com
*  start date: Sep  6 20:38:07 2021 GMT
*  expire date: Sep  6 20:38:07 2022 GMT
*  common name: *.example.com (matched)
*  issuer: O=example.com; CN=example.com; emailAddress=admin@example.com
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x563c5c0b7860)
> GET /headers HTTP/2
> Host:httpbin.example.com
> user-agent: curl/7.68.0
> accept: */*
>
* TLSv1.3 (IN), TLS alert, certificate revoked (556):
* OpenSSL SSL_read: error:14094414:SSL routines:ssl3_read_bytes:sslv3 alert certificate revoked, errno 0
* Failed receiving HTTP2 data
* OpenSSL SSL_write: SSL_ERROR_ZERO_RETURN, errno 0
* Failed sending HTTP2 data
* Connection #0 to host httpbin.example.com left intact
curl: (56) OpenSSL SSL_read: error:14094414:SSL routines:ssl3_read_bytes:sslv3 alert certificate revoked, errno 0
```

## Links

- Istio guide of setup mTLS with ingress gateway, https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
- Openssl library we used for generate CRL, https://github.com/felix021/openssl-selfsign
