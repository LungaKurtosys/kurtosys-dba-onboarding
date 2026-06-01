# Zabbix Monitoring - SQL Server Always On

Local Zabbix setup to monitor SQL Server Primary and Secondary nodes.

## Architecture
```
sql-primary   ──→ Zabbix Agent ──→ Zabbix Server ──→ Zabbix Web UI (port 8080)
sql-secondary ──→ Zabbix Agent ──/                         ↓
                                                      Alerts/Triggers
                                                      (like incident.io at Katosis)
```

## Access
- URL: http://localhost:8080
- Username: `Admin`
- Password: `<YOUR_ZABBIX_PASSWORD>`

## Setup Steps

### 1. Start monitoring stack
```bash
cd monitoring
docker compose up -d
```

### 2. Install Zabbix Agent on SQL Server containers
```bash
# Primary
docker exec -u root sql-primary bash -c "
apt-get update -qq && apt-get install -y zabbix-agent
echo 'Server=zabbix-server
ServerActive=zabbix-server
Hostname=sql-primary
LogType=system' > /etc/zabbix/zabbix_agentd.conf
zabbix_agentd"

# Secondary
docker exec -u root sql-secondary bash -c "
apt-get update -qq && apt-get install -y zabbix-agent
echo 'Server=zabbix-server
ServerActive=zabbix-server
Hostname=sql-secondary
LogType=system' > /etc/zabbix/zabbix_agentd.conf
zabbix_agentd"
```

### 3. Add Hosts in Zabbix UI
1. `Configuration` → `Hosts` → `Create Host`
2. Fill in:
   - Host name: `sql-primary`
   - Host groups: `Linux servers`
   - Interfaces → `Add` → `Agent`
   - Click `DNS` radio button
   - DNS: `sql-primary`
   - Port: `10050`
3. Templates tab → add `Linux by Zabbix agent`
4. Click `Add`

Repeat same steps for `sql-secondary`

### 4. Create Alert Trigger
1. `Configuration` → `Hosts` → click host → `Triggers` → `Create trigger`
2. Fill in:
   - Name: `SQL Server Down Alert`
   - Severity: `Disaster`
   - Expression: `last(/sql-primary/agent.ping)=0`
   - Description: `SQL Server primary node is down - immediate action required`
3. Click `Add`

## Testing Alerts

### Simulate server going down
```bash
docker stop sql-primary sql-secondary
```

Go to `Monitoring` → `Problems` — DISASTER alerts appear for both nodes.

### Bring servers back up
```bash
docker start sql-primary sql-secondary
```

Alerts clear automatically — servers back to normal.

## How This Relates to Katosis
- Katosis uses Zabbix to monitor SQL Server VMs
- When a server goes down Zabbix fires an alert
- Alert goes to incident.io
- incident.io calls the on-call DBA on their phone
- DBA investigates and fixes the issue
- Alert clears when server is back online
