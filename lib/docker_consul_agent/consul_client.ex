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
      Application.get_env(:docker_consul_agent, DockerConsulAgent.ConsulClient) |> Map.new()

    Req.new(
      base_url: consul_opts.base_url,
      headers: [{"X-Consul-Token", consul_opts.token}],
      connect_options: [transport_opts: consul_opts.transport_opts]
    )
  end

  @doc """
  Deregisters a node from the Consul catalog.
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
  Registers a service with the Consul catalog.
  This is a wrapper around the Consul API endpoint
  `/v1/catalog/register`.
  """
  def register!(service) do
    new() |> put!("/v1/catalog/register", service)
  end

  def get!(path) do
    new() |> get!(path)
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
end
