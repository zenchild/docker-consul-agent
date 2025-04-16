defmodule DockerConsulAgent.Reconciler do
  alias DockerConsulAgent.ConsulClient
  alias DockerConsulAgent.DockerClient
  alias DockerConsulAgent.ServiceFormatter

  @doc """
  This will reconcile the state of the Consul agent with the state of the Docker
  by comparing %{"Meta" => %{"docker_id" => "id"}} in the Consul catalog with
  %{"Id" => "id"} in the Docker API. It only compares the nodes that have the
  %label `consul.enabled=true` in Docker and the nodes that have the meta key
  %`docker-consul-agent` in Consul.
  If there were any changes to the Services or Nodes in Consul, those will be
  ignored. We are only reconciling id to id.
  """
  def run() do
    current_consul_ids_to_nodes =
      ConsulClient.get_current_docker_nodes()
      |> Enum.map(fn node ->
        {node["Meta"]["docker_id"], node["Node"]}
      end)
      |> Map.new()

    current_docker_containers =
      DockerClient.get_current_consul_containers()

    current_docker_container_ids =
      current_docker_containers
      |> Enum.map(fn container ->
        container["Id"]
      end)

    Enum.each(current_consul_ids_to_nodes, fn {docker_id, node_name} ->
      if !Enum.member?(current_docker_container_ids, docker_id) do
        ConsulClient.deregister!(node_name)
      end
    end)

    Enum.each(current_docker_containers, fn container ->
      DockerClient.get_container_info!(container["Id"])
      |> ServiceFormatter.format()
      |> Enum.each(&ConsulClient.register!/1)
    end)
  end
end
