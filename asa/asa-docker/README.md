TODO- finish read me, add discord link
# ASA Server for Unraid

A Docker image for hosting **ARK: Survival Ascended** dedicated servers designed for unraid.

---

# Installation

1. 
2. 
3.  
4. 
5. 
6. Start the container.

---

# Directory Layout


Only `/cluster` is shared.

---

# INI Edits

```

```

---

# Clustering

Every server in the cluster must use:

- the same Cluster ID
- the same `/cluster` directory

Each server should have:

- its own `/data`
- unique game port
- unique RCON port

---

# Troubleshooting

ARK Survival Ascended Server has specific system requirements that must be met for the container to run properly:

## The vm.max_map_count parameter MUST be increased to at least 262144

Temporary Setting (resets after system reboot):
`sudo sysctl -w vm.max_map_count=262144`
Permanent Setting (recommended):
`echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf sudo sysctl -p`
⚠️ IMPORTANT NOTE: Without this setting, your ARK server container WILL fail to start. typically with "Allocator Stats" errors in the logs.

If changes were made to the template after the first launch you might need to delete the proton folder and let it regenerate the needed prefixes, This will NOT delete any of your ark data or saves.

# Support

First enable debug mode in the template advanced options to capture logs into `/debug `
Collect the log file and provide it when requesting support

---

# License

MIT