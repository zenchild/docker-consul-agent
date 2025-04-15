defmodule DockerConsulAgent do
  use GenServer

  require Logger

  alias DockerConsulAgent.ConsulClient

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Logger.debug("#{inspect(node())}: init(:ok)")
    {:ok, {:socket, connect_to_docker_socket()}}
  end

  @impl true
  def handle_info({{Finch.HTTP1.Pool, _pid}, {:data, msg}}, state) do
    msg = Jason.decode!(msg)
    Logger.debug("Received message: #{inspect(msg)}")

    manage_event(msg)

    Logger.debug("Message processed: #{inspect(msg)}")

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Internal functions

  defp connect_to_docker_socket() do
    socket_path = Application.fetch_env!(:docker_consul_agent, :docker_socket_path)
    Logger.debug("#{inspect(node())}: connect_to_docker_socket()")

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]

    filter = %{
      type: ["container"],
      event: ["start", "die"],
      label: ["consul.enabled=true"]
    }

    # The `localhost` won't be used because we are setting `unix_socket` in the
    # request. The request will use the socket in it's place and append the path
    # and params to the unix socket path.
    Req.get(
      "http://localhost/events",
      params: [
        filters: Jason.encode!(filter)
      ],
      unix_socket: socket_path,
      headers: headers,
      receive_timeout: :infinity,
      into: :self
    )

    :ok
  end

  def manage_event(%{"id" => id} = ev) do
    case ev["status"] do
      "start" ->
        Logger.info("Container started: #{id} - #{ev["Actor"]["Attributes"]["image"]}")
        {:ok, %Req.Response{body: body}} = req([], [], "containers/#{id}/json")

        format_service(body)
        |> ConsulClient.register!()

        Logger.info("Service registered: #{id}")

      "die" ->
        Logger.info("Container killed: #{id} - #{ev["Actor"]["Attributes"]["image"]}")

        {:ok, %Req.Response{body: body}} = req([], [], "containers/#{id}/json")

        format_service(body)
        |> ConsulClient.deregister!()

        Logger.info("Service deregistered: #{id}")

      _ ->
        Logger.info("Unknown event: #{inspect(ev)}")
    end
  rescue
    e ->
      Logger.error("Error processing event: #{inspect(e)}")
      Logger.error("Event: #{inspect(ev)}")
      {:error, e}
  end

  def format_service(%{} = docker_json) do
    id = docker_json["Id"]
    labels = docker_json["Config"]["Labels"] || %{}
    {_net_name, net_conf} = Enum.at(docker_json["NetworkSettings"]["Networks"], 0)

    tags =
      Map.get(labels, "consul.tags", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    node_name = Map.get(labels, "consul.node_name", docker_json["Config"]["Hostname"])

    service_name =
      Map.get(labels, "consul.service_name", String.slice(docker_json["Name"], 1..-1//1))
      |> String.trim()
      |> String.replace(" ", "_")

    %{
      Node: node_name,
      Address: net_conf["IPAddress"],
      Service: %{
        ID: id,
        Address: net_conf["IPAddress"],
        Service: service_name,
        Tags: tags,
        Port: 4000,
        Meta: %{
          "docker-consul-agent" => "true",
          "docker_id" => id,
          "docker_name" => docker_json["Name"],
          "docker_image" => docker_json["Config"]["Image"]
        }
      }
    }
  end

  def req(headers, params, path) do
    socket_path = Application.fetch_env!(:docker_consul_agent, :docker_socket_path)

    Req.get(
      "http://localhost/#{path}",
      params: params,
      unix_socket: socket_path,
      headers: headers
    )
  end
end
