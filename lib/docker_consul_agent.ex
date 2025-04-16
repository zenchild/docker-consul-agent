defmodule DockerConsulAgent do
  use GenServer

  require Logger

  alias DockerConsulAgent.Reconciler
  alias DockerConsulAgent.ConsulClient
  alias DockerConsulAgent.DockerClient
  alias DockerConsulAgent.ServiceFormatter

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Logger.debug("#{inspect(node())}: init(:ok)")
    Logger.debug("Running Reconciler...")
    Reconciler.run()
    Logger.debug("Running Reconciler... done")
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

  defp connect_to_docker_socket() do
    DockerClient.watch_events()

    :ok
  end

  defp manage_event(%{"id" => id} = ev) do
    case ev["status"] do
      "start" ->
        Logger.info("Container started: #{id} - #{ev["Actor"]["Attributes"]["image"]}")

        DockerClient.get_container_info!(id)
        |> register!()

        Logger.info("Service registered: #{id}")

      "die" ->
        Logger.info("Container killed: #{id} - #{ev["Actor"]["Attributes"]["image"]}")

        DockerClient.get_container_info!(id)
        |> deregister!()

        Logger.info("Service deregistered: #{id}")

      _ ->
        Logger.info("Unknown event: #{inspect(ev)}")
    end
  end

  defp register!(%{} = docker_info) do
    ServiceFormatter.format(docker_info)
    |> Enum.each(&ConsulClient.register!/1)
  end

  defp deregister!(%{} = docker_info) do
    ServiceFormatter.format(docker_info)
    |> Enum.at(0)
    |> ConsulClient.deregister!()
  end
end
