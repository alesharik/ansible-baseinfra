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


cat <<EOT > /etc/clickhouse-server/users.d/root.xml
<!-- Docs: <https://clickhouse.tech/docs/en/operations/settings/settings_users/> -->
<users>
  <${CLICKHOUSE_USER}>
    <profile>default</profile>
    <networks>
      <ip>::/0</ip>
    </networks>
    <password>${CLICKHOUSE_PASSWORD}</password>
    <quota>default</quota>
  </${CLICKHOUSE_USER}>
</users>
EOT

{% for db in clickhouse.databases %}
clickhouse-client -u "${CLICKHOUSE_USER}" --password "${CLICKHOUSE_PASSWORD}" --query "CREATE DATABASE IF NOT EXISTS {{ db }}";
{% endfor %}

cat <<EOT > /etc/clickhouse-server/users.d/users.xml
<!-- Docs: <https://clickhouse.tech/docs/en/operations/settings/settings_users/> -->
<users>
{% for u in (clickhouse.users | dict2items) %}
  <{{ u.key }}>
    <profile>default</profile>
    <networks>
      <ip>::/0</ip>
    </networks>
    <password>${{{ u.key }}_PASSWORD}</password>
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
