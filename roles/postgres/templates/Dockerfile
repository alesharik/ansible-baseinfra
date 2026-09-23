#jinja2: trim_blocks: True, lstrip_blocks: True
{#
  Written only when postgres.packages is not empty. The image tag carries a hash
  of this file, so a package change gives a new tag, and compose builds and
  recreates the container. The `#jinja2:` line above never reaches the output.
#}
FROM {{ postgres.image }}:{{ postgres.version }}
{# sorted, so list order never changes the file, and never changes the tag #}
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
{% for pkg in postgres.packages | sort %}
      postgresql-{{ postgres_major }}-{{ pkg }} \
{% endfor %}
 && rm -rf /var/lib/apt/lists/*
