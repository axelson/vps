# VPS

This Elixir project is a meta-project that ties together 4 different Phoenix applications and runs them all on a single instead of the BEAM that is running on [Vultr](https://www.vultr.com/?ref=8764184) (affiliate link).

It powers the following Phoenix sites:
- https://depviz.jasonaxelson.com (git repo: https://github.com/axelson/dep_viz)
- https://makeuplive.jasonaxelson.com (git repo: https://github.com/axelson/makeup_live_format/)
- https://sketch.jasonaxelson.com (git repo: https://github.com/axelson/sketchpad/)
- http://jamroom.hassanshaikley.jasonaxelson.com (git repo: https://github.com/hassanshaikley/jamroom/)

## Why Vultr

Honestly it's primarily because [nerves_system_vultr](https://github.com/nerves-project/nerves_system_vultr) exists and is the only maintained way to run a nerves instance on a cloud provider. But I have found Vultr to be a good and cost-effective host for my hobby projects.

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

Note: you can change te port away from the default of 4102 by setting `config :master_proxy, http: [:inet6, port: <a new port>]`
