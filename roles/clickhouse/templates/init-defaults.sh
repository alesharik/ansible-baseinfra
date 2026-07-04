#!/usr/bin/env sh

cat <<EOT > /etc/clickhouse-server/config.d/prometheus.xml
<clickhouse>
    <prometheus>
        <endpoint>/metrics</endpoint>
        <port>9363</port>
        <metrics>true</metrics>
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
        <errors>true</errors>
    </prometheus>
</clickhouse>
EOT

echo "Prometheus config written"

{% for db in clickhouse.databases %}
echo "Creating database {{ db }}"
clickhouse-client -u "${CLICKHOUSE_USER}" --password "${CLICKHOUSE_PASSWORD}" --query "CREATE DATABASE IF NOT EXISTS {{ db }}";
{% endfor %}
