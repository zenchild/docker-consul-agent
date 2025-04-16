defmodule DockerConsulAgent.ConsulClient do
  @moduledoc """
  A basic HTTP client for interacting with the Consul API. It only supports
  the catalog API for registering and deregistering services.
  """
  require Logger

  @doc """
  Creates a new Req request with the base URL and headers set from the
  application environment.
  You can configure the Consul Client using the same variables as the consul command line.
  You should set env vars for:

  ## Required:
  * CONSUL_HTTP_ADDR - The address of the Consul agent without the protocol, but with the port if not at 80 or 443
  * CONSUL_HTTP_TOKEN - The token to use for authentication
  ## Optional:
  * CONSUL_HTTP_SSL
  * CONSUL_HTTP_SSL_VERIFY
  """
  def new() do
    consul_opts =
      Application.get_env(:docker_consul_agent, __MODULE__) |> Map.new()

    Req.new(
      base_url: consul_opts.base_url,
      headers: [{"X-Consul-Token", consul_opts.token}],
      connect_options: [transport_opts: consul_opts.transport_opts]
    )
  end

  @doc """
  Registers an entity with the Consul catalog.
  This is a wrapper around the Consul API endpoint
  `/v1/catalog/register`.
  """
  def register!(%{} = service) do
    new() |> put!("/v1/catalog/register", service)
  end

  @doc """
  Deregisters an entity from the Consul catalog.
  This is a wrapper around the Consul API endpoint
  `/v1/catalog/deregister`.
  """
  def deregister!(node_id) when is_binary(node_id) do
    deregister!(%{Node: node_id})
  end

  def deregister!(%{Node: node_id}) do
    new() |> put!("/v1/catalog/deregister", %{Node: node_id})
  end

  @doc """
  Registers a service with the Consul agent.

  This is a wrapper around the Consul API endpoint
  `/v1/agent/service/register`.
  """
  def register_agent_service!(%{} = service) do
    new() |> put!("/v1/agent/service/register", service)
  end

  @doc """
  Deregisters a service from the Consul agent.

  This is a wrapper around the Consul API endpoint.
  `/v1/agent/service/deregister/:service_id`.
  """
  def deregister_agent_service!(service_id) when is_binary(service_id) do
    new() |> req(:put, "/v1/agent/service/deregister/#{service_id}")
  end

  def deregister_agent_service!(%{ID: service_id}) do
    deregister_agent_service!(service_id)
  end

  def get_current_docker_nodes() do
    new()
    |> Req.get(
      url: "/v1/catalog/nodes",
      params: [filter: ~s(Meta["docker-consul-agent"] == true)]
    )
    |> handle_response()
  end

  def get!(%Req.Request{} = req, path) do
    Req.get(req, url: path)
    |> handle_response()
  end

  def put!(path, body) do
    new() |> put!(path, body)
  end

  def put!(%Req.Request{} = req, path, body) do
    Req.put(req, url: path, body: Jason.encode!(body))
    |> handle_response()
  end

  defp handle_response({_, %Req.Response{}} = resp) do
    case resp do
      {:ok, %Req.Response{status: 200, body: %{} = body}} ->
        body

      {:ok, %Req.Response{status: 200, body: [_ | _] = body}} ->
        body

      {:ok, %Req.Response{status: 200, body: [] = body}} ->
        body

      {:ok, %Req.Response{status: 200}} ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        Logger.error("Error: #{inspect(resp)}")
        raise "Request failed with status: #{status}"

      {:error, reason} ->
        Logger.error("Error: #{inspect(reason)}")
        raise "Request failed with error: #{inspect(reason)}"
    end
  end

  # -------------------------------------------------------------------------- #
  # The below functions are lower-level Req wrappers. They are for advanced uses.
  # -------------------------------------------------------------------------- #

  @doc """
  Makes a request to the Consul API using the specified HTTP method and path.
  This is a raw request and does not use the response handler. It is up to the
  end-user to handle the HTTP response.
  """
  def req(client, method, path, opts \\ [])
  def req(%Req.Request{} = client, :get, path, opts), do: do_req(client, :get, path, opts)
  def req(%Req.Request{} = client, :put, path, opts), do: do_req(client, :put, path, opts)
  def req(%Req.Request{} = client, :post, path, opts), do: do_req(client, :post, path, opts)

  def req(_client, method, _path, _opts) do
    raise ArgumentError, "Unsupported method: #{inspect(method)}"
  end

  defp do_req(client, method, path, opts) do
    Req.request(client, [method: method, url: path] ++ opts)
  end
end
