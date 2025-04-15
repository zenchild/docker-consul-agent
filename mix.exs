defmodule DockerConsulAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :docker_consul_agent,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # extra_applications: [:logger, :wx, :observer, :runtime_tools],
      extra_applications: [:logger],
      mod: {DockerConsulAgent.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.10"}
    ]
  end
end
