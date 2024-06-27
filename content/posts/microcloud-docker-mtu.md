+++
title = 'MicroCloud, Docker, and Networking'
date = 2024-06-25T20:50:45-04:00
draft = false
+++

I am running Canonical's MicroCloud in my homelab and use it to host a number of different services. As part of deploying those services, I have been creating Ansible roles and playbooks to manage the configuration of each service. The services are a variety of things that I use, such as a Git server (Gitea), a reverse proxy for web applications (Nginx Proxy Manager), and a Minecraft server (Crafty Controller), among several others. I've learned quite a bit about using Ansible and running services that other people access. In this post, I want to describe a particular technical issue I ran into when running Docker inside a LXD VM that resulted in abysmal network performance.

# High-level overview

When I set out to create my homelab I wanted to use Ansible to deploy everything. However, in certain cases, the "recommended deployment method" was to run Docker. This resulted in some trade-offs in my original design. One goal I had was to isolate each service as much as possible. This started out as running a LXD container per service. When Docker entered the design, I toyed with some different options. One option was to run a physical server as a Docker host. Another was to get Docker working inside of LXD containers. Finally, I could run a LXD virtual machine and then run Docker inside of that.

I decided pretty quickly that I did not want to run a separate physical server for all of my Docker containers, as that would make maintenance trickier. I couldn't easily migrate services to another host when I needed to reboot for things like kernel updates. I briefly toyed with the idea of running two hosts for Docker for that reason and three hosts for MicroCloud, but ultimately, I felt like this limited my flexibility.

The next avenue I explored was running Docker inside of a LXD container. This could work, and there are plenty of places that document getting this working. I tested this out and it does work, but in my opinion, it complicated some of the deployment and configuration as certain containers required special options. While Ansible can easily handle this, I got kind of lazy and didn't want to figure out an easy way to apply that configuration to specific containers.

This left me with running virtual machines to host Docker. My first thought was to run two virtual machines with Docker, allowing me to migrate services as needed. However, I also think about the security side of things and decided to provide stronger isolation by running Docker in a VM per service. This also simplified some of the Ansible things, as I could create a role for Docker hosts and apply that to any system that I manage with Ansible[^1].

# Observered issues

With the deployment sorted out, I set about getting everything deployed and configured. Almost immediately I noticed that the networking performance was terrible. I would try and run simple commands like `apt update` and it would take several minutes per network request, often with timeouts, requiring several retries to get through a single `apt update`. Other times, I was left with odd error messages as services would complain about not being able to connect to a remote resource, or not finding a specific package to install.

What was most confusing about this was those same issues were not seen on my laptop where I do local testing for things I plan to deploy to my homelab. I would spin up containers, or virtual machines, on my laptop using LXD and everything would work flawlessly. This caused a lot of head scratching and trying various things.

# Research

I started my research by testing Docker in several different environments:

1. My laptop (not in a VM/container)
2. My laptop with a KVM VM
3. My laptop with a LXD VM
4. My laptop with a LXD container
5. A homelab node (not in a VM/container)
6. A homelab node with a KVM VM
7. A homelab node with a LXD VM
8. A homelab node with a LXD container

I also tested the first four configurations with both wired and wireless connections as the underlying physical connection. Ultimately, I narrowed it down to configurations 7 and 8 being the problematic configurations.

This led me to start comparing and contrasting the various deployment scenarios in order to determine what was causing Docker container networking to work well in 3/4 of the deployments and not in the other 1/4. I checked all of the various configuration options I could think of and ultimately, I realized the difference between 1-6 and 7-8. It was that 7 and 8 were using MicroOVN for networking, while 1-6 were using Linux bridges without OVN.

With that tidbit of knowledge, I started looking at the network configurations in more detail. I spent a lot of time looking at various outputs of `ip` commands to see if I could find any differences. Finally, I noticed a small difference that would trigger the vaguest of memories from my days in college when I took my networking classes. The MTU size of the various interfaces was different. While I am not, nor will I ever claim to be, a networking expert, I remember my professor saying that fragmentation is bad and having a smaller MTU on an interface than the rest of the network pipeline can result in fragmentation.

With this knowledge in hand, I had new keywords to search for, which led me to the [following blog post](https://www.civo.com/learn/fixing-networking-for-docker). As I read the post, I realized that Docker was defaulting to an MTU size of 1,500 bytes. My OVN deployment was using an MTU size of 1,442 bytes. I did also notice that the MTU size of my Tailscale interface was 1,280 bytes, but that has yet to pose an issue. I started looking at how to reconfigure Docker to use a smaller MTU setting.

# Solution

The first step in getting a smaller MTU size for Docker was to change the `systemd` unit file for Docker to launch the Docker daemon with a smaller MTU size. This led me down a whole other rabbit hole about getting overrides to work for `systemd` unit files. Specifically, I was getting errors about having multiple `ExecStart` lines in a unit file that wasn't a `OneShot` unit. This resulted in the following file to override the Docker unit file in `/etc/systemd/system/docker.service.d/override.conf` 

```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --mtu 1400 -H fd:// --containerd=/run/containerd/containerd.sock
```

You might notice the `ExecStart=` followed by the actual `ExecStart` line. The reason for this is that `systemd` will execute each of the `ExecStart` lines. For service types other than `OneShot`, only one `ExecStart` is allowed [^2]. The only addition to the default `ExecStart` line is `--mtu 1400`. The value of 1,400 bytes was chosen since OVN sets an MTU of 1,442 bytes. I could have chosen 1,442 bytes, but this ensures that I will never run into issues if OVN further reduces their MTU setting.

The other change that was required was to modify my `docker-compose.yml` file for my deployed services. I added the following to each of the compose files to ensure that the maximum MTU was always 1,400 bytes.

```
networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 1400
```

With all of these changes deployed, I was able to successfully run network commands without issue. In future posts, I'll describe more about my homelab and how things are deployed and the things I have learned.

[^1]: In the future, I can expand this role to detect running in a LXD container and apply the appropriate configurations. (Adding this to my ever expanding TODO list)
[^2]: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#ExecStart=