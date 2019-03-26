local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local row = grafana.row;
local singlestat = grafana.singlestat;
local template = grafana.template;
local numbersinglestat = promgrafonnet.numbersinglestat;

{
  grafanaDashboards+:: {
    'deployment.json':
      local cpuStat =
        numbersinglestat.new(
          'CPU',
          'sum(rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod_name=~"$deployment.*"}[3m]))' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('cores')
        .withSparkline();

      local memoryStat =
        numbersinglestat.new(
          'Memory',
          'sum(container_memory_usage_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod_name=~"$deployment.*"}) / 1024^3' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('GB')
        .withSparkline();

      local networkStat =
        numbersinglestat.new(
          'Network',
          'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod_name=~"$deployment.*"}[3m])) + sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace="$namespace",pod_name=~"$deployment.*"}[3m]))' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('Bps')
        .withSparkline();

      local overviewRow =
        row.new()
        .addPanel(cpuStat)
        .addPanel(memoryStat)
        .addPanel(networkStat);

      local desiredReplicasStat = numbersinglestat.new(
        'Desired Replicas',
        'max(kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local currentReplicasStat = numbersinglestat.new(
        'Replicas of current version',
        'min(kube_deployment_status_replicas{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local availableReplicasStat = numbersinglestat.new(
        'Available replicas',
        'min(kube_deployment_status_replicas_available{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local updatedReplicasStat = numbersinglestat.new(
        'Updated replicas',
        'min(kube_deployment_status_replicas_updated{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local unavailableReplicasStat = numbersinglestat.new(
        'Unavailable replicas',
        'min(kube_deployment_status_replicas_unavailable{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local observedGenerationStat = numbersinglestat.new(
        'Observed Generation',
        'max(kube_deployment_status_observed_generation{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", deployment="$deployment"}) without (instance, pod)' % $._config,
      );

      local metadataGenerationStat = numbersinglestat.new(
        'Metadata Generation',
        'max(kube_deployment_metadata_generation{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
      );

      local statsRow =
        row.new(height='100px')
        .addPanel(desiredReplicasStat)
        .addPanel(currentReplicasStat)
        .addPanel(availableReplicasStat)
        .addPanel(unavailableReplicasStat)
        .addPanel(updatedReplicasStat)
        .addPanel(observedGenerationStat)
        .addPanel(metadataGenerationStat);

      local replicasGraph =
        graphPanel.new(
          'Replicas',
          datasource='$datasource',
        )
        .addTarget(prometheus.target(
          'max(kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='replicas specified',
        ))
        .addTarget(prometheus.target(
          'max(kube_deployment_status_replicas{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='replicas created',
        ))
        .addTarget(prometheus.target(
          'min(kube_deployment_status_replicas_availabre{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='available',
        ))
        .addTarget(prometheus.target(
          'min(kube_deployment_status_replicas_unavailable{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='unavailable',
        ))
        .addTarget(prometheus.target(
          'min(kube_deployment_status_replicas_updated{%(kubeStateMetricsSelector)s, deployment="$deployment", %(clusterLabel)s="$cluster", namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='updated',
        ));

      local replicasRow =
        row.new()
        .addPanel(replicasGraph);

      dashboard.new(
        '%(dashboardNamePrefix)sDeploymentss' % $._config.grafanaK8s,
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['deployment.json']),
        tags=($._config.grafanaK8s.dashboardTags),
        graphTooltip='shared_tooltip',
      ).addTemplate(
        {
          current: {
            text: 'Prometheus',
            value: 'Prometheus',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'cluster',
          '$datasource',
          'label_values(kube_deployment_metadata_generation, %s)' % $._config.clusterLabel,
          label='cluster',
          refresh='time',
          hide=if $._config.showMultiCluster then '' else 'variable',
        )
      )
      .addTemplate(
        template.new(
          'namespace',
          '$datasource',
          'label_values(kube_deployment_metadata_generation{%(kubeStateMetricsSelector)s}, namespace)' % $._config,
          label='Namespace',
          refresh='time',
        )
      )
      .addTemplate(
        template.new(
          'deployment',
          '$datasource',
          'label_values(kube_deployment_metadata_generation{%(kubeStateMetricsSelector)s, namespace="$namespace"}, deployment)' % $._config,
          label='Name',
          refresh='time',
        )
      )
      .addRow(overviewRow)
      .addRow(statsRow)
      .addRow(replicasRow),
  },
}
