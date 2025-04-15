import Config

config :docker_consul_agent, DockerConsulAgent.DockerClient,
  base_url: "http://localhost",
  socket_path: System.get_env("DOCKER_SOCKET", "/var/run/docker.sock")

consul_proto = (System.get_env("CONSUL_HTTP_SSL") == "true" && "https") || "http"
verify_ssl = if System.get_env("CONSUL_HTTP_SSL_VERIFY") == "false", do: false, else: true

config :docker_consul_agent, DockerConsulAgent.ConsulClient,
  base_url: consul_proto <> "://" <> System.get_env("CONSUL_HTTP_ADDR"),
  token: System.get_env("CONSUL_HTTP_TOKEN"),
  transport_opts: (verify_ssl && []) || [verify: :verify_none]
