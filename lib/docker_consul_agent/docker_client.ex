defmodule DockerConsulAgent.DockerClient do
  @moduledoc """
  A basic HTTP client for interacting with the Docker API. It only supports
  the events API for receiving events from Docker.
  """

  def new() do
    docker_opts =
      Application.get_env(:docker_consul_agent, __MODULE__) |> Map.new()

    # The base_url can just be "localhost." It won't be used because we are
    # setting `unix_socket` in the request. The request will use the socket in
    # it's place and append the path and params to the unix socket path.
    Req.new(
      base_url: docker_opts.base_url,
      unix_socket: docker_opts.socket_path,
      headers: [
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ]
    )
  end

  def watch_events() do
    filter = %{
      type: ["container"],
      event: ["start", "die"],
      label: ["consul.enabled=true"]
    }

    new()
    |> Req.get(
      url: "/events",
      params: [
        filters: Jason.encode!(filter)
      ],
      receive_timeout: :infinity,
      into: :self
    )
  end

  def get_container_info!(container_id) do
    new()
    |> Req.get(url: "/containers/#{container_id}/json")
    |> handle_response()
  end

  def handle_response({:ok, %Req.Response{body: body}}) do
    case body do
      %{} = body ->
        body

      err ->
        raise "Failed to decode JSON response: #{inspect(err)}"
    end
  end
end
