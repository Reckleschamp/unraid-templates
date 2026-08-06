# ASA Server for Unraid

A Unraid Docker image for hosting **ARK: Survival Ascended** dedicated servers with multi-map cluster support.

---

# Installation

1. Install the template from Community Apps.
2. Select a server directory.
3. Select a configuration directory.
4. Select a shared cluster directory (optional).
5. Configure your map and session name.
6. Start the container.

---

# Directory Layout

Each map has its own installation.

```
Island
/server
/config

Scorched
/server
/config
```

Only `/cluster` is shared.

---

# Configuration

Edit

```
/config/Game.ini
/config/GameUserSettings.ini
/config/Engine.ini
```

These files are copied into the server installation every time the container starts.

---

# Clustering

Every server in the cluster must use:

- the same Cluster ID
- the same `/cluster` directory

Each server should have:

- its own `/server`
- its own `/config`
- unique game port
- unique RCON port

---

# Support

Please include:

- Container logs
- Docker image version
- Unraid version
- XML configuration (without passwords)

when opening an issue.

---

# License

MIT