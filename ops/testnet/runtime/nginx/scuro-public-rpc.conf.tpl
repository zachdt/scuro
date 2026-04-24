server {
    listen 80 default_server;
    server_name __SCURO_RPC_HOSTNAME__;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    server_name __SCURO_RPC_HOSTNAME__;

    ssl_certificate __SCURO_ORIGIN_CERT_PATH__;
    ssl_certificate_key __SCURO_ORIGIN_KEY_PATH__;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location / {
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Origin, Accept, Authorization" always;
            add_header Access-Control-Max-Age 3600 always;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }

        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Connection "";
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 30s;
        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        client_max_body_size 1m;
        proxy_pass http://127.0.0.1:8545;

        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Origin, Accept, Authorization" always;
    }
}
