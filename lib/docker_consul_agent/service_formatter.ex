defmodule DockerConsulAgent.ServiceFormatter do
  @moduledoc """
  A module for formatting Docker container information into a format suitable
  for registering with Consul.
  """

  @service_prefix "consul.service."

  def format(%{} = docker_json) do
    id = docker_json["Id"]
    labels = docker_json["Config"]["Labels"] || %{}
    {_net_name, net_conf} = Enum.at(docker_json["NetworkSettings"]["Networks"], 0)

    node_name = Map.get(labels, "consul.node_name", docker_json["Config"]["Hostname"])

    node_def =
      %{
        Node: node_name,
        Address: net_conf["IPAddress"],
        TaggedAddresses: %{
          lan: net_conf["IPAddress"],
          lan_ipv4: net_conf["IPAddress"],
          wan: net_conf["IPAddress"],
          wan_ipv4: net_conf["IPAddress"]
        },
        SkipNodeUpdate: true,
        NodeMeta: %{
          "docker-consul-agent" => "true",
          "docker_id" => id,
          "docker_name" => docker_json["Name"],
          "docker_image" => docker_json["Config"]["Image"]
        }
      }

    case services(node_name, net_conf, labels)
         |> Enum.map(fn service ->
           Map.merge(node_def, %{Service: service})
         end) do
      [] ->
        [node_def]

      [_ | _rest] = output ->
        output
    end
  end

  # This will create [Service](https://developer.hashicorp.com/consul/api-docs/catalog#service)
  # for each service defined in the docker container labels.
  defp services(node_name, net_conf, labels) do
    service_basename =
      Map.get(labels, "consul.service_basename", "")
      |> String.trim()
      |> then(fn bn ->
        if bn == "", do: "", else: "#{bn}-"
      end)

    group_service_labels(labels)
    |> Enum.map(fn {service_name, service_conf} ->
      service_port = Map.get(service_conf, "port", 0)
      service_tags = Map.get(service_conf, "tags", [])

      %{
        ID: node_name <> "-" <> service_basename <> service_name,
        Service: service_basename <> service_name,
        Port: service_port,
        Address: net_conf["IPAddress"],
        Tags: service_tags
      }
    end)
  end

  # This groups the configuration for each defined service.
  # For example, it will turn the following docker labels:
  #   consul.service.my_service.port=8080
  #   consul.service.my_service.tags=tag1,tag2
  # into:
  #   %{
  #     "my_service" => %{
  #       "port" => 8080,
  #       "tags" => ["tag1", "tag2"]
  #     }
  #   }
  defp group_service_labels(labels) do
    Map.filter(labels, fn {k, _v} -> String.starts_with?(k, @service_prefix) end)
    |> Enum.reduce(%{}, fn {k, v}, m ->
      case String.replace(k, @service_prefix, "") |> String.split(".") do
        [service_name, "port"] ->
          service_port = String.to_integer(v)
          Map.put(m, service_name, Map.merge(m[service_name] || %{}, %{"port" => service_port}))

        [service_name, "tags"] ->
          service_tags = String.split(v, ",") |> Enum.map(&String.trim/1)

          Map.put(m, service_name, Map.merge(m[service_name] || %{}, %{"tags" => service_tags}))

        _unknown_label ->
          m
      end
    end)
  end
end
