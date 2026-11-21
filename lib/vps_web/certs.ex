defmodule VpsWeb.Certs do
  @moduledoc """
  The site_encrypt certificates.

  `VpsWeb.Endpoint` holds the main certificate, covering every domain in
  `:site_encrypt_domains` except the isolated ones. Each isolated hostname gets a
  certificate of its own from a dedicated cert endpoint, so a hostname that fails
  validation (e.g. its DNS isn't set up) can't block renewal of the main
  certificate. `VpsWeb.MyProxy` routes each isolated hostname's ACME challenges to
  its cert endpoint and serves its certificate via SNI.
  """

  # {app in :endpoint_configs, cert endpoint}
  @isolated_apps [file_hosting: VpsWeb.FilesCertEndpoint]

  @doc "`{cert_endpoint, hostname}` for each isolated app present in `:endpoint_configs`."
  @spec isolated() :: [{module(), String.t()}]
  def isolated do
    endpoint_configs = Application.fetch_env!(:vps, :endpoint_configs)

    for {app, cert_endpoint} <- @isolated_apps,
        {^app, _endpoint, hostname} <- endpoint_configs,
        do: {cert_endpoint, hostname}
  end

  @doc "The isolated hostname a cert endpoint certifies."
  @spec hostname(module()) :: String.t()
  def hostname(cert_endpoint) do
    {^cert_endpoint, hostname} = List.keyfind(isolated(), cert_endpoint, 0)
    hostname
  end

  @doc "Domains on the main certificate."
  @spec main_domains() :: [String.t()]
  def main_domains do
    isolated_hostnames = Enum.map(isolated(), &elem(&1, 1))
    Application.fetch_env!(:vps, :site_encrypt_domains) -- isolated_hostnames
  end

  @doc """
  `SiteEncrypt.configure/1` options shared by every certificate. `name` selects
  the certificate's `:site_encrypt_db_folder` subfolder (`nil` for the main one)
  and, in local mode, its internal ACME server port from `:site_encrypt_internal_ports`.
  """
  @spec configure_opts(atom() | nil, [String.t()]) :: keyword()
  def configure_opts(name, domains) do
    db_folder = Application.fetch_env!(:vps, :site_encrypt_db_folder)

    [
      client: :native,
      domains: domains,
      emails: ["contact@jasonaxelson.com"],
      db_folder: if(name, do: Path.join(db_folder, to_string(name)), else: db_folder),
      directory_url:
        case Application.get_env(:vps, :cert_mode, "local") do
          "local" -> {:internal, port: internal_port(name)}
          "staging" -> "https://acme-staging-v02.api.letsencrypt.org/directory"
          "production" -> "https://acme-v02.api.letsencrypt.org/directory"
        end
    ]
  end

  defp internal_port(nil), do: Application.fetch_env!(:vps, :site_encrypt_internal_port)

  defp internal_port(name),
    do: Application.fetch_env!(:vps, :site_encrypt_internal_ports) |> Keyword.fetch!(name)
end
