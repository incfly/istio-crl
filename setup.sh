
# 0. install istio 1.9.5; istio ingress gateway setup route to httpbin, teapot task
# 1. https://github.com/felix021/openssl-selfsign, create foo, bar cert.
# 2. revoke foo@01
# 3. update the crl pem.
# 4. create that into the configmap.
# Things to clarify
# 1. size limit of the CRL. secret/configmap 1MB, use some other volume mount.
# 2. Current limitations, update, envoyfilter, upgrade version required, might be able to provision
# this to the upstream to revive.
function setup() {
   kubectl create -n istio-system secret generic httpbin-credential-3 \
    --from-file=tls.key=./cert/site/example.com/cert.key   \
    --from-file=tls.crt=./cert/site/example.com/cert.crt   \
    --from-file=ca.crt=./cert/ca.crt
}

httpscurl() {
  curl -v -HHost:httpbin.example.com --resolve "httpbin.example.com:8443:127.0.0.1" \
    --cacert openssl-selfsign/cert/ca.crt \
    "https://httpbin.example.com:8443/headers"
}

# mtlscurl [client-name]
mtlscurl() {
  user=${1:-"user-bar@02"}
  curl -v -HHost:httpbin.example.com --resolve "httpbin.example.com:8443:127.0.0.1" \
    --cacert openssl-selfsign/cert/ca.crt --cert openssl-selfsign/cert/newcerts/${user}/crt.pem \
    --key openssl-selfsign/cert/newcerts/${user}/key.pem  \
    "https://httpbin.example.com:8443/headers"
}

createcrlmap() {
  kubectl create configmap envoy-crl -nistio-system --from-file=openssl-selfsign/cert/crl.pem
  ka ./ef-tls.yaml
}
