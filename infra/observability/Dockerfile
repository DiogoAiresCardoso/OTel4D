FROM grafana/otel-lgtm:0.41.1@sha256:1b852b77d7bcadb7699bfe7c78a51d059dff85168de674728cf7abf4474645e5

COPY grafana/provisioning.yaml /otel-lgtm/grafana/conf/provisioning/dashboards/otel4d.yaml
COPY grafana/dashboards/otel4d-delphi-demo.json /otel-lgtm/otel4d-dashboards/otel4d-delphi-demo.json

ENV ENABLE_OBI=false \
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/otel-lgtm/otel4d-dashboards/otel4d-delphi-demo.json \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false \
    GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false \
    GF_PLUGINS_PREINSTALL_DISABLED=true \
    LOKI_EXTRA_ARGS=-reporting.enabled=false \
    TEMPO_EXTRA_ARGS=-reporting.enabled=false \
    PYROSCOPE_EXTRA_ARGS=-usage-stats.enabled=false
