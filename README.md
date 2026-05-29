# cloud-security-portfolio
Hands-on cloud security projects | Networking | AWS | Terraform | security+

---

## Week 4 — Tracert Analysis
**Command:** `tracert google.com`

**Findings:**
- Trace reached 15 hops into Google's network (142.250.x.x / 192.178.x.x)
- Hop 1: `10.245.181.99` — default gateway, healthy (1-2ms)
- Hop 2: `10.232.6.130` — latency spike (2375ms), ISP-side slowness
- Hop 4 & 8: Request timed out — routers blocking ICMP, normal behaviour
- Hop 16: Destination unreachable — routing restriction on local network

**Security Observations:**
- Hops 1 and 3 are private IPs — internal network boundary visible
- Traffic transitions from private to public at Hop 5
- Timed out hops indicate firewall presence — useful for network mapping


## IPConfig Analysis
**Command:** `ipconfig /all`

**Findings:**
- Machine IP: `10.245.181.179` — assigned by DHCP
- Subnet Mask: `255.255.255.0` — /24 network, 254 usable hosts
- Default Gateway: `10.245.181.99` — all external traffic routes here
- DHCP Server: `10.245.181.99` — router handling IP assignment
- DNS Server: `10.245.181.99` — router also resolving DNS queries
- Ethernet: disconnected — running on WiFi only

**Security Observations:**
- Router is acting as gateway, DHCP, and DNS simultaneously
- Single point of failure — if compromised, attacker controls all three
- WiFi only — no wired connection, higher interception risk
