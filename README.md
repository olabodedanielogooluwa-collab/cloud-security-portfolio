# cloud-security-portfolio
Hands-on cloud security projects | Networking | AWS | Terraform | security+

---

## Week 4 — Tracert Analysis
**Command:** `tracert google.com`
<img width="720" height="1280" alt="WhatsApp Image 2026-06-04 at 8 11 14 PM" src="https://github.com/user-attachments/assets/bfac40db-6baa-4a20-a42b-96e6f233c8d7" />

**Findings:**
- Trace reached 15 hops into Google's network (142.250.x.x / 192.178.x.x)
- Hop 1: `10.245.181.x` — default gateway, healthy (1-2ms)
- Hop 2: `10.232.6.v` — latency spike (2375ms), ISP-side slowness
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
## ARP Analysis
**Command:** `arp -a`

**Findings:**
- Router: `10.245.181.99` — only dynamic entry, MAC `c6-64-97-7b-d1-b2`
- `10.245.181.255` — broadcast address, static, normal
- `224.0.0.x` entries — multicast traffic, normal background activity
- `255.255.255.255` — limited broadcast, normal

**Security Observations:**
- Clean ARP cache — only one dynamic entry (router)
- ARP poisoning would show two IPs sharing the same MAC address
- If router MAC changes unexpectedly, suspect man-in-the-middle attack

---

## Route Print Analysis
**Command:** `route print`

**Findings:**
- Default route: `0.0.0.0` via gateway `10.245.181.99` — all unknown traffic goes here
- Local network: `10.245.181.0/24` — on-link, no gateway needed
- Loopback: `127.0.0.0` — internal machine traffic only
- Metric 55 on default route — lower metric means preferred path
- No persistent routes present

**Security Observations:**
- Clean routing table — no suspicious persistent routes
- Malware can add persistent routes to silently redirect traffic
- Default route is single point of control — if gateway is compromised, all traffic is exposed

## claring arp cache
**command:**  `arp -d*`

**findings:**
- command prompt must run as admistrator before successful clearing
  
**security observation:**
- non-administrator cmd prompt results in "elevation required" output
- why: security feature to prevent unauthorized ARP table modification
- Windows restricts modification to admin users only
  
## Week 4 — Gateway Misconfiguration & Recovery
**Scenario:** Deliberate default gateway break and recovery

**Commands Used:**
- `ipconfig /all` — confirm network configuration
- `ping 8.8.8.8` — verify internet connectivity
- `route print` — diagnose routing table
- `Win + R → ncpa.cpl` — access network adapter settings

**What I Did:**
1. Deliberately misconfigured the default gateway on my network adapter
2. Ran `ping 8.8.8.8` — returned `General Failure`, confirming no internet  <img width="1080" height="607" alt="WhatsApp Image 2026-06-04 at 7 59 01 PM" src="https://github.com/user-attachments/assets/0495e9cf-d853-4ff3-958b-9a79e2fc4274" />

3. Ran `route print` — identified the incorrect gateway entry <img width="1080" height="607" alt="WhatsApp Image 2026-06-04 at 7 59 01 PM (1)" src="https://github.com/user-attachments/assets/28b2d515-d7a5-43a1-88d5-7a950cf36023" />

4. Reverted adapter settings to automatic (DHCP)
5. Ran `ping 8.8.8.8` again — successful, connectivity restored

**Security Observations:**
- A compromised router can silently change your default gateway
- If `route print` shows an unexpected or unfamiliar gateway IP, 
  investigate immediately — traffic could be redirected to an attacker
- Always verify gateway matches your known router IP after 
  any connectivity issue

## Week 4 — DNS Misconfiguration & Recovery
**Scenario:** Deliberate DNS misconfiguration causing full network disconnection

**Commands Used:**
- `nslookup google.com` — verify DNS resolution
- `ipconfig /all` — confirm DNS server settings
- `ping 8.8.8.8` — test connectivity independent of DNS
- `Win + R → ncpa.cpl` — access network adapter settings

**What I Did:**
1. Navigated to IPv4 settings via `ncpa.cpl`
2. Manually set DNS server to fake address `10.0.0.x`
3. Ran `nslookup google.com` — returned 'no response from server'
4. <img width="1080" height="607" alt="WhatsApp Image 2026-06-05 at 10 57 30 PM" src="https://github.com/user-attachments/assets/647a7668-c33e-41b5-85a7-1ba00c7e425a" />

5. Observed full network disconnection — not just DNS failure
6. Ran `ipconfig /all` — confirmed wrong DNS server active
7. Reverted to "Obtain DNS server address automatically"
8. Ran `nslookup google.com` — resolved successfully
9. vvv<img width="1080" height="607" alt="WhatsApp Image 2026-06-05 at 11 00 31 PM" src="https://github.com/user-attachments/assets/8dfb8c09-0156-4ace-9e3c-da219fae3e9d" />

10. Ran `ping 8.8.8.8` — confirmed full connectivity restored

**Key Finding:**
Misconfiguring DNS caused complete network disconnection, not 
just name resolution failure. This is because the router handles 
DNS, DHCP, and gateway simultaneously — one misconfiguration 
disrupts all three services.

**Security Observations:**
- DNS poisoning or misconfiguration can silently redirect all 
  web traffic to attacker-controlled servers
- A single DNS change can take down full network connectivity
  when router handles multiple roles
- Always verify DNS server matches known router IP via `ipconfig /all`
- Use `ping 8.8.8.8` to test connectivity independent of DNS —
  if ping succeeds but `nslookup` fails, DNS is the problem
- If ping also fails, issue is gateway or deeper

## Week 4 — Tracert Failure & Recovery
**Scenario:** Deliberate gateway misconfiguration causing 
tracert and connectivity failure

**Commands Used:**
- `tracert google.com` — trace packet path to destination
- `route print` — diagnose routing table
- `ping 8.8.8.8` — test connectivity independent of DNS

**What I Did:**
1. Misconfigured default gateway to fake address `10.254.181.x`
2. Ran `tracert google.com` — returned `Unable to resolve 
   target system name` — packets couldn't leave machine
3. <img width="1080" height="232" alt="WhatsApp Image 2026-06-06 at 11 00 39 PM" src="https://github.com/user-attachments/assets/16b6b0a5-2750-41dd-b461-651303cd1bfc" />

4. Ran `ping 8.8.8.8` — returned `Destination host 
   unreachable` confirming no connectivity
5. Ran `route print` — identified fake gateway `10.254.181.x` 
   in both active and persistent routes
6. Reverted adapter settings to automatic (DHCP)
7. Ran `tracert google.com` — successfully traced 23 hops 
   to Google
8. <img width="1080" height="522" alt="WhatsApp Image 2026-06-06 at 11 03 34 PM" src="https://github.com/user-attachments/assets/2116a99e-9986-4bef-97ae-44bbdbcaf10a" />

9. Ran `ping 8.8.8.8` — 4/4 packets received, connectivity 
   fully restored

**Key Finding:**
Wrong gateway entry appeared in both active AND persistent 
routes — meaning it would survive a reboot. This is a 
critical distinction from a temporary misconfiguration.

**Security Observations:**
- A misconfigured or malicious gateway silently drops 
  all outbound traffic
- Persistent routes survive reboots — malware uses this 
  to maintain traffic redirection permanently
- `ping 8.8.8.8` bypasses DNS — if ping fails but DNS 
  works, gateway is the problem
- Always check persistent routes section in `route print` 
  — not just active routes
- `Destination host unreachable` means packet died locally,
  never reached the internet
