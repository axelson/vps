# VPS

This Elixir project is a meta-project that ties together 4 different Phoenix
applications and runs them all on a single instance of the BEAM that is running
[Nerves](https://www.nerves-project.org) on a
[Vultr](https://www.vultr.com/?ref=8764184) (affiliate link) VM.

It powers the following Phoenix sites:
- https://depviz.jasonaxelson.com ([git repo](https://github.com/axelson/dep_viz))
- https://makeuplive.jasonaxelson.com ([git repo](https://github.com/axelson/makeup_live_format/))
- https://sketch.jasonaxelson.com ([git repo](https://github.com/axelson/sketchpad/))
- https://jamroom.hassanshaikley.jasonaxelson.com ([git repo](https://github.com/hassanshaikley/jamroom/))

# How does it work?

The base system runs on Vultr via
[nerves_system_vultr](https://github.com/nerves-project/nerves_system_vultr).
[MasterProxy](https://github.com/jesseshieh/master_proxy) allows for multiple
Phoenix applications to run on a single BEAM instance on the same port (443 in
this case). The domain name on the incoming request is what ties a request to a
specific Phoenix Endpoint.

Note: I'm currently using my own branch, but I plan to re-integrate that into
master_proxy https://github.com/axelson/master_proxy/tree/flexiblity-1

[Site Encrypt](https://github.com/sasa1977/site_encrypt) provides automated
https certificate management via LetsEncrypt.

It's important to me to not store secrets inside the repository so I use a
simple `Config.Provider` to load `/data/.target.secret.exs` at runtime. I manage
that file on the VM so I can deploy from multiple computers.

[SSHSubsystemFwup](https://github.com/nerves-project/ssh_subsystem_fwup) allows
for easy deploys over SSH with a simple `mix upload` command.

## Why Vultr

Honestly it's primarily because
[nerves_system_vultr](https://github.com/nerves-project/nerves_system_vultr)
exists and is the only maintained way to run a nerves instance on a cloud
provider. But I have found Vultr to be a good and cost-effective host for my
hobby projects.

# Running locally

Run locally with:

``` sh
mix deps.get
iex -S mix phx.server
```

Then add the following lines to your `/etc/hosts` file:

```
127.0.0.1 depviz.localhost
127.0.0.1 makeuplive.localhost
127.0.0.1 sketch.localhost
127.0.0.1 jamroom.localhost
```

Then you can open the following in a web browser:
- http://depviz.localhost:4102
- http://makeuplive.localhost:4102
- http://sketch.localhost:4102
- http://jamroom.localhost:4102

Note: you can change the port away from the default of 4102 by setting `config
:master_proxy, http: [:inet6, port: <a new port>]`

In your `~/.ssh/config` file I recommend setting:

``` ssh-config
Host vultr
HostName <your-vultr-server-ip-address>
```

Maybe try this locally (nginx SSL passthrough)
https://sxi.io/how-to-configure-nginx-ssl-tls-passthrough-with-tcp-load-balancing/

# Deployment

See the [Development instructions](./DEVELOPMENT.md)
