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

echo "Writing users config"
cat <<EOT > /etc/clickhouse-server/users.d/users.xml
<!-- Docs: <https://clickhouse.tech/docs/en/operations/settings/settings_users/> -->
<users>
{% for u in (clickhouse.users | dict2items) %}
  <{{ u.key }}>
    <profile>default</profile>
    <networks>
      <ip>::/0</ip>
    </networks>
    <password>{% raw %}${{% endraw %}{{ u.key | upper }}{% raw %}_PASSWORD}{% endraw %}</password>
    <quota>default</quota>
    <grants>
{% for g in (u.value.grants or []) %}
      <query>{{ g }}</query>
{% endfor %}
    </grants>
  </{{ u.key }}>
{% endfor %}
</users>
EOT
#cat /etc/clickhouse-server/users.d/user.xml;
