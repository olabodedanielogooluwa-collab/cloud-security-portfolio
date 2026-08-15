# Cloud Security Portfolio

Hands-on cloud security projects — networking, Linux administration, 
SSH hardening, incident response, and AWS infrastructure via Terraform. 
Self-directed 12-week program, building toward a Junior Cloud Security 
Engineer role.

Every entry follows the same loop: break something deliberately (or 
find something already broken) → diagnose the root cause → fix it → 
verify externally rather than trusting the tool's own success message.

## Skills demonstrated
- **Networking diagnostics** — tracert, ARP, DHCP, DNS, routing
- **Linux administration** — permissions, processes, filesystem
- **SSH hardening** — key auth, sshd_config, validation
- **Incident response** — rogue devices, suspicious processes, misconfig recovery
- **AWS / IaC** — Terraform EC2, IAM setup, Free Tier troubleshooting

## Navigation
- [Week 4 — Networking](#week-4--tracert-analysis)
- [Week 5 — Linux & SSH](#week-5--file-navigation)
- [Week 6 — Terraform + EC2](#week-6--terraform--ec2-basics)
- [Week 6–7 — AWS Setup](#aws-account-setup--terraform-ec2-deployment-week6-7)
- [Week 7 — AWS Core Services](#week-7--aws-core-services--billing-control)

  
## Week 4 — Tracert Analysis
**Command:** `tracert google.com`
<img width="687" height="496" alt="WhatsApp Image 2026-07-14 at 3 40 29 PM" src="https://github.com/user-attachments/assets/efc9931e-79eb-433c-9a4a-c0063a6c4f5c" />



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
- Machine IP: `10.245.181.x` — assigned by DHCP
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
- Router: `10.245.181.99` — only dynamic entry, MAC `c6-64-97-xx-xx-xx`
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

## Week 4 — Rogue Device Detection via ARP
**Scenario:** Simulating and detecting an unauthorised device 
on the network using ARP cache analysis

**Commands Used:**
- `arp -a` — view ARP cache
- `arp -s [IP] [MAC]` — add static ARP entry (simulate rogue device)
- `arp -d *` — clear ARP cache

**What I Did:**
1. Ran `arp -a` — captured clean baseline, one dynamic 
   entry (router at `10.76.79.x`)
2. Added fake static entry to simulate rogue device:
   `arp -s 10.245.181.x aa-bb-cc-dd-ee-ff`
3. Ran `arp -a` — confirmed rogue device appeared as 
   static entry with unknown MAC `aa-bb-cc-dd-ee-ff`
4. Cleared ARP cache with `arp -d *`
5. Ran `arp -a` — confirmed rogue entry removed, 
   only legitimate router entry remained

**Key Finding:**
Rogue device appeared as a `static` entry — manually added 
entries are always static. On a real network, an unexpected 
static entry is an immediate red flag requiring investigation.

**Security Observations:**
- Only `dynamic` entries are legitimately learned by the network
- An unexpected `static` entry indicates manual manipulation 
  — investigate immediately
- On a corporate network, compare ARP cache against known 
  device inventory — any unknown MAC is a potential threat
- ARP cache poisoning would show a `dynamic` entry where 
  an attacker's MAC replaces the router's MAC for the 
  same IP address
- `arp -d *` requires administrator privileges — 
  Windows restricts ARP modification as a security control
  
   ## Week 4 — Blocked Port Identification
**Scenario:** Identifying open and blocked ports using 
netstat and Windows Firewall

**Commands Used:**
- `netstat -an` — view all active connections and listening ports
- `netstat -an | findstr [port]` — filter for specific port
- `wf.msc` — Windows Firewall management console

**What I Did:**
1. Ran `netstat -an` — captured all active connections 
   and listening ports
2. Identified key listening ports on the machine:
   - Port `135` — RPC (Remote Procedure Call)
   - Port `445` — SMB (Windows file sharing)
   - Port `5040` — Windows system service
3. Ran `netstat -an | findstr 8080` — returned nothing, 
   port not open or listening
4. Created inbound block rule for port `8080` via `wf.msc`
5. Confirmed port `8080` still returns no results — blocked
6. Verified port `445` active: `netstat -an | findstr 445` 
   returned two LISTENING entries
7.  <img width="1728" height="1066" alt="WhatsApp Image 2026-06-10 at 10 39 05 PM" src="https://github.com/user-attachments/assets/4fad085c-e5a4-4941-82f4-1cef938773c6" />
8. Removed test firewall rule after verification

**Key Finding:**
Port `8080` returned no results before AND after blocking — 
confirming nothing was listening on it.
<img width="1574" height="580" alt="WhatsApp Image 2026-06-10 at 10 41 49 PM" src="https://github.com/user-attachments/assets/7a33df21-299f-4498-9875-85742471893e" />
Port `445` (SMB) 
is actively listening on this machine.

**Security Observations:**
- Port `445` (SMB) listening is a known attack vector — 
  responsible for WannaCry ransomware propagation in 2017
- Any unexpected `LISTENING` port is a potential backdoor 
  — investigate the process behind it
- `TIME_WAIT` connections are normal — socket closing after 
  completed session
- `ESTABLISHED` connections show active communication — 
  verify all foreign addresses are legitimate
- Use `netstat -an | findstr [port]` to quickly confirm 
  whether a specific port is open or blocked
8. Removed test firewall rule after verification

**Key Finding:**
Port `8080` returned no results before AND after blocking — 
confirming nothing was listening on it. Port `445` (SMB) 
is actively listening on this machine.

**Security Observations:**
- Port `445` (SMB) listening is a known attack vector — 
  responsible for WannaCry ransomware propagation in 2017
- Any unexpected `LISTENING` port is a potential backdoor 
  — investigate the process behind it
- `TIME_WAIT` connections are normal — socket closing after 
  completed session
- `ESTABLISHED` connections show active communication — 
  verify all foreign addresses are legitimate
- Use `netstat -an | findstr [port]` to quickly confirm 
  whether a specific port is open or blocked

## Week 4 — DHCP Failure Simulation & Recovery
**Scenario:** Simulating DHCP failure by disabling network 
adapter and observing complete connectivity loss

**Commands Used:**
- `ipconfig /all` — verify IP assignment and DHCP lease
- `ping 8.8.8.8` — test connectivity independent of DNS
- `Win + R → ncpa.cpl` — disable/enable network adapter

**What I Did:**
1. Ran `ipconfig /all` — confirmed active DHCP lease:
   - IP: `10.230.128.x`
   - DHCP Server: `10.230.128.x`
   - Lease obtained and expiry timestamps visible
2. Disabled WiFi adapter via `ncpa.cpl`
3. Ran `ipconfig /all` — WiFi adapter disappeared from 
   output, no IP assigned
4. <img width="1280" height="844" alt="WhatsApp Image 2026-06-11 at 10 44 22 PM" src="https://github.com/user-attachments/assets/04d1c861-9dac-48bb-a664-e4d42d71fec6" />
5. Ran `ping 8.8.8.8` — returned `General Failure` 
   on all 4 packets, 100% loss
6. <img width="1280" height="844" alt="WhatsApp Image 2026-06-11 at 10 44 22 PM" src="https://github.com/user-attachments/assets/1c3e015b-4ace-485a-8ad0-27412b989d18" />
7. Re-enabled WiFi adapter via `ncpa.cpl`
8. Windows automatically contacted DHCP server and 
   obtained fresh lease
9. Ran `ipconfig /all` — confirmed new lease obtained 
   at `17:51:28`, expiring `18:51:27`
10. <img width="607" height="1080" alt="WhatsApp Image 2026-06-11 at 10 49 08 PM" src="https://github.com/user-attachments/assets/2e565411-d110-4ade-9b60-678323cec201" />
11. Ran `ping 8.8.8.8` — 4/4 packets received, 
   full connectivity restored

**Key Finding:**
When adapter was disabled, machine had no IP whatsoever — 
not even an APIPA fallback. Full DHCP recovery happened 
automatically within seconds of re-enabling the adapter, 
confirming DHCP server was healthy and responsive.

**What APIPA Looks Like in a Real DHCP Failure:**
If DHCP server is unreachable, Windows assigns a 
self-generated fallback IP in the `169.254.x.x` range. 
This is called APIPA (Automatic Private IP Addressing). 
Any device showing `169.254.x.x` cannot reach the internet 
or communicate outside the local subnet.

**Security Observations:**
- DHCP starvation attack floods the DHCP server with 
  fake requests, exhausting the IP pool — legitimate 
  devices get no IP assigned
- Rogue DHCP server attack — attacker sets up their own 
  DHCP server, assigns themselves as default gateway, 
  intercepting all traffic
- `169.254.x.x` on any device is an immediate red flag — 
  investigate DHCP server health immediately
- DHCP lease timestamps in `ipconfig /all` cofirm when 
  IP was assigned — useful for incident timeline reconstruction
- Always check lease obtained time during incident response 
  — it places a device on the network at a specific time


# cloud-security-portfolio
Hands-on cloud security projects | Networking | Linux | SSH Hardening | Security+

---

## Week 5 — File Navigation

**Commands:**
- `pwd` — print current working directory
- `cd /path` — navigate using absolute path
- `cd folder` — navigate using relative path
- `ls` — list directory contents
- `ls -a` — show hidden files
- `ls -l` — detailed listing with permissions, owner, size, timestamp
- `ls -la` — hidden files with full detail combined

**Security Observations:**
- `ls -la /etc` reveals hidden files and permission levels on critical config files
- Hidden files (prefixed with `.`) are commonly used to conceal attacker tools
- Always check ownership and permissions when auditing an unfamiliar system

---

## Week 5 — File Operations

**Commands:**
- `touch filename` — create new empty file
- `touch file1 file2` — create multiple files simultaneously
- `cp source dest` — copy file to destination
- `cp -r dir/ ~/documents` — copy entire directory recursively
- `cp -i source dest` — prompt before overwriting existing file
- `mv oldname newname` — rename a file
- `mv file ~/documents` — move file to directory
- `mkdir documents` — create single directory
- `mkdir -p a/b/c` — create nested directories in one command
- `rm filename` — delete file
- `rm -r directory/` — delete directory and all contents
- `file filename` — identify file type and content

**Security Observations:**
- `rm -r` is irreversible — always confirm path before running
- `file` command identifies true file type regardless of extension — attackers rename malicious files to bypass filters
- `cp -i` flag prevents silent overwrites — useful when handling evidence files during incident response

---

## Week 5 — Text Viewing and Searching

**Commands:**
- `cat filename` — display full file contents
- `cat -n filename` — display file with line numbers
- `less filename` — scroll through large files page by page
- `head filename` — view first 10 lines of a file
- `head -n 20 filename` — view first 20 lines
- `tail filename` — view last 10 lines of a file
- `tail -f /var/log/auth.log` — stream file live as it updates
- `grep "pattern" filename` — search for pattern inside file
- `grep -i "pattern" filename` — case-insensitive search
- `grep -c "pattern" filename` — count matching lines
- `grep "Failed password" /var/log/auth.log` — find failed SSH login attempts
- `sort filename` — sort file contents alphabetically
- `sort -r filename` — sort in reverse order

**Security Observations:**
- `tail -f /var/log/auth.log` monitors SSH login attempts in real time — active threat detection
- `grep "Failed password" /var/log/auth.log` is one of the first commands run during an SSH brute force investigation
- Hundreds of failed attempts from a single IP within minutes is a confirmed brute force pattern
- `grep "Accepted" /var/log/auth.log` confirms which login attempts succeeded — critical during post-incident review

---

## Week 5 — Vim Text Editor

**Key Concept:** Vim is the standard editor on remote servers accessed via SSH. GUI editors are unavailable on locked-down machines — vim proficiency is non-negotiable for cloud and SOC work.

**Mode Switching:**
- `i` — enter insert mode (start typing)
- `Esc` — return to normal mode
- `:` — enter command mode (save, quit, search)

**Navigation (Normal Mode):**
- `h` `j` `k` `l` — move left, down, up, right

**Editing:**
- `dd` — delete entire current line
- `3dd` — delete three lines
- `u` — undo last action
- `Ctrl-R` — redo last undone action
- `cw` — change word from cursor position
- `x` — delete character under cursor

**Searching:**
- `/searchterm` — search forward through file
- `?searchterm` — search backward through file
- `n` — jump to next occurrence
- `N` — jump to previous occurrence

**Saving and Exiting:**
- `:w` — save file
- `:q` — quit (only if no unsaved changes)
- `:wq` — save and quit
- `:q!` — quit and discard all unsaved changes
- `ZZ` — shortcut for save and quit

**Security Observations:**
- Vim is how you edit `sshd_config`, `sudoers`, and other critical config files over SSH
- `:q!` exits without saving — always confirm you saved before exiting a config file
- `/searchterm` lets you locate specific directives inside long config files like `sshd_config` instantly

---

## Week 5 — User Management

**Key Files:**
- `/etc/passwd` — maps usernames to UIDs, lists every user account on the system
- `/etc/shadow` — stores encrypted passwords, most sensitive user file on the system
- `/etc/group` — defines group memberships
- `/etc/sudoers` — controls who can run commands as root

**Commands:**
- `cat /etc/passwd` — view all user accounts
- `sudo cat /etc/shadow` — view encrypted passwords (requires root)
- `cat /etc/group` — view all group definitions
- `sudo useradd username` — create new user
- `sudo userdel -r username` — delete user and their home directory
- `passwd username` — change a user's password
- `visudo` — safely edit the sudoers file

**Findings:**
- Root has UID 0 — only legitimate root account present, no red flags
- All non-login accounts end with `/usr/sbin/nologin` — no unexpected shell access
- `x` in password field confirms passwords stored securely in `/etc/shadow`

<img width="1080" height="118" alt="WhatsApp Image 2026-07-16 at 3 58 49 PM" src="https://github.com/user-attachments/assets/08c3cf2b-9d68-4adb-ba6b-82a612261d70" />


**Key Findings:**
- Root always has UID 0 — any other account with UID 0 is a critical red flag
- `*` or `!` in `/etc/shadow` means account is locked and cannot login
- Blank password field in `/etc/shadow` means user has no password set

**Security Observations:**
- `/etc/passwd` is readable by all users — attackers use it to enumerate accounts immediately after gaining access
- `/etc/shadow` is a primary target — offline password cracking requires extracting this file
- On a compromised system, check for unexpected new accounts in `/etc/passwd` — attacker persistence technique
- Group misconfiguration is a common privilege escalation vector — verify `/etc/group` for unexpected sudo or admin group members

---

## Week 5 — File Permissions

**Command:** `ls -l`

**Reading Permission Strings:**
- First character indicates file type — `d` directory, `-` regular file, `l` symbolic link
- Next 9 characters are permissions split into three groups of three
- Format: `[type][owner][group][others]` — example: `-rwxr-xr--`
- `r` — read (value 4)
- `w` — write (value 2)
- `x` — execute (value 1)
- `-` — no permission (value 0)

**Example decoded:**
- `-rwxr-xr--` — regular file, owner can read/write/execute, group can read/execute, others can only read

**chmod — Modifying Permissions:**
- `chmod u+x filename` — add execute permission for owner
- `chmod g-w filename` — remove write permission from group
- `chmod 755 filename` — rwxr-xr-x (owner full, group and others read/execute)
- `chmod 644 filename` — rw-r--r-- (owner read/write, others read only)
- `chmod 600 filename` — rw------- (owner read/write only — used for private keys)

**chown — Changing Ownership:**
- `sudo chown user filename` — change file owner
- `sudo chgrp group filename` — change group owner
- `sudo chown user:group filename` — change both simultaneously
- `sudo chown root:root /etc/ssh/sshd_config` — correct ownership for SSH config

**Security Observations:**
- `/etc/ssh/sshd_config` should always be owned by `root:root` with permissions `644` — any deviation is a finding
- Private key files must be `chmod 600` — SSH refuses to use keys with open permissions
- `chmod 777` on any file is a critical misconfiguration — grants full access to every user on the system
- On a compromised system, check for world-writable files — attackers use them as staging areas

---

## Week 5 — Process Management

**Commands:**
- `ps` — snapshot of current session processes
- `ps aux` — all processes, all users, including those with no terminal
- `ps -ef` — full listing including UID, PPID, CPU usage, and start time
- `top` — real-time process monitor showing CPU and memory usage
- `cat /proc/[PID]/status` — kernel's live view of a specific process
- `ls /proc` — lists all running process IDs as numbered directories

**Process State Codes (STAT column in ps aux):**
- `R` — running, actively executing or in run queue
- `S` — interruptible sleep, waiting for an event
- `D` — uninterruptible sleep, in I/O operation
- `Z` — zombie, finished but not yet reaped by parent process
- `T` — stopped, suspended by Ctrl+Z

**Kill Signals:**
- `kill 1234` — send SIGTERM (15), polite termination request
- `kill -15 1234` — SIGTERM explicitly
- `kill -9 1234` — SIGKILL, force kill, cannot be blocked or ignored
- `kill -0 1234` — check if process exists without sending a signal

**Incident Response Sequence — Suspicious Process:**
1. `top` — identify suspicious resource usage
2. `ps aux` — full process listing, look for unknown names or root processes
3. `cat /proc/[PID]/status` — inspect process via kernel
4. `kill -15 [PID]` — attempt polite termination first
5. `kill -9 [PID]` — force kill if process does not respond
6. `ps aux | grep [PID]` — confirm process is gone

**Findings:**
- 26 total processes, 0 zombie, 0 stopped — clean system
- sshd running as root PID 35 — SSH daemon active
- VS Code processes consuming highest CPU at 2.4% — no anomalies detected
- No suspicious or unaccounted processes identified

<img width="1280" height="720" alt="WhatsApp Image 2026-07-16 at 4 00 14 PM" src="https://github.com/user-attachments/assets/30e08091-1360-45b7-aef8-0471f0f1bcc2" />


**Key Finding:**
- `/proc` is not a real filesystem — it is created in memory by the kernel and contains live data only
- Data in `/proc` does not persist after reboot — it cannot be used as forensic disk evidence

**Security Observations:**
- `ps aux` is one of the first commands run on a suspected compromised server — look for processes with unusual names or unexpected root ownership
- A zombie process (`Z`) cannot be killed directly — the parent process must be terminated
- Attackers sometimes disguise malicious processes with names similar to system processes — compare against known process list
- `/proc/[PID]/status` gives the kernel's direct view — harder to spoof than standard tools

---

## Week 5 — Package Management

**Ubuntu/Debian — apt:**
- `sudo apt update` — refresh package index from repositories
- `sudo apt upgrade` — apply all available updates and security patches
- `sudo apt install package_name` — install a package
- `sudo apt remove package_name` — remove a package
- `apt show package_name` — display package details

**Red Hat/CentOS — yum:**
- `sudo yum update` — update all packages
- `sudo yum install package_name` — install a package
- `sudo yum erase package_name` — remove a package
- `yum info package_name` — display package details

**Key Finding:**
- Debian-based systems (Ubuntu) use `.deb` packages managed by `apt`
- Red Hat-based systems (RHEL, CentOS, Fedora) use `.rpm` packages managed by `yum`

**Security Observations:**
- `sudo apt update && sudo apt upgrade` is a hardening action, not routine maintenance — unpatched packages are one of the most common real-world breach vectors
- Always run update before installing new software — ensures latest secure version is pulled
- Package repositories are defined in `/etc/apt/sources.list` — a malicious repository entry here is a supply chain attack vector

---

## Week 5 — Filesystem Hierarchy

**Command:** `ls -l /`

**Essential System Directories:**
- `/` — root directory, starting point of entire filesystem
- `/bin` — essential user binaries (`ls`, `cp`, `mv`)
- `/sbin` — system binaries, root only (`fdisk`, `iptables`)
- `/etc` — system configuration files — primary hardening target
- `/lib` — shared libraries required by `/bin` and `/sbin`
- `/boot` — kernel and bootloader files

**User and Application Data:**
- `/home` — personal directories for each user
- `/root` — home directory for root user, separate from `/home`
- `/usr` — user-installed software and utilities (`/usr/bin`, `/usr/local`)
- `/opt` — optional or third-party software packages

**Dynamic and Temporary Data:**
- `/var` — variable data, changes during operation (`/var/log` for logs)
- `/tmp` — temporary files, world-writable, often cleared on reboot
- `/run` — runtime data since last boot, PIDs and process info

**System Information:**
- `/proc` — virtual filesystem, live kernel and process data
- `/sys` — kernel and hardware interface

**Findings:**
- `/etc` contains 130+ config files all owned by root — confirms system integrity
- `/var/log` present with active log files including dpkg, bootstrap, and system logs
- No world-writable files detected outside of `/tmp` — clean system

<img width="1280" height="318" alt="WhatsApp Image 2026-07-15 at 11 10 07 PM" src="https://github.com/user-attachments/assets/d74f5be1-64e3-4225-b855-885b42723eff" />


**Security Observations:**
- `/etc` is the primary attacker target on any Linux system — `sshd_config`, `passwd`, and `sudoers` all live here
- `/tmp` is world-writable — commonly used by attackers to stage malware and exploit scripts
- `/var/log` is your evidence trail — always check here first during incident response
- `/home/username/.ssh/authorized_keys` controls SSH access — an attacker adding their public key here establishes persistent access
- `/proc` data is live and cannot be tampered with on disk — reliable for real-time process investigation

---

## Week 5 — Logging

**Key Log Files:**
- `/var/log/auth.log` — all authentication events, SSH logins and failures
- `/var/log/syslog` — comprehensive system events, excludes authentication messages
- `/var/log/messages` — general system messages from kernel and daemons
- `/var/log/kern.log` — persistent kernel log
- `/var/log/dmesg` — kernel ring buffer, boot and hardware events

**Commands:**
- `tail -f /var/log/auth.log` — stream authentication events live as they happen
- `grep "Failed password" /var/log/auth.log` — find all failed SSH login attempts
- `grep "Accepted" /var/log/auth.log` — find all successful SSH logins
- `dmesg` — view kernel log for hardware and boot issues
- `logger -s "Test entry"` — manually send a log entry to syslog

**Log Rotation:**
- Managed by `logrotate` — prevents logs from filling disk
- Renames current log, creates new empty log, compresses old entries, deletes oldest
- Config: `/etc/logrotate.conf` — main settings
- Config: `/etc/logrotate.d/` — per-application rotation settings

**Security Observations:**
- `/var/log/auth.log` is the first file checked during an SSH brute force investigation
- Hundreds of failed login attempts from one IP in minutes is a confirmed brute force attack pattern
- A successful login immediately following many failures indicates a successful brute force — critical finding
- Attackers often clear or tamper with log files to cover tracks — absence of expected log entries is itself a red flag
- Log rotation means old evidence may be compressed or deleted — always export logs early in an investigation

---

## Week 5 — SSH Key Authentication

**Key Concept:** SSH key authentication replaces passwords with a cryptographic key pair, eliminating the entire category of brute force and credential stuffing attacks.

**How It Works:**
- Private key stays on your machine — never leaves, never shared
- Public key is deployed to the server's `~/.ssh/authorized_keys`
- Server issues a cryptographic challenge — only the holder of the correct private key can solve it
- No password is ever sent over the network

**Commands:**
- `ssh-keygen -t ed25519 -C "label"` — generate ed25519 key pair
- `cat ~/.ssh/id_ed25519.pub` — view public key for deployment
- `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server` — deploy public key to server
- `ssh -i ~/.ssh/id_ed25519 user@server` — connect using key authentication
- `chmod 600 ~/.ssh/id_ed25519` — set correct private key permissions
- `chmod 700 ~/.ssh/` — set correct SSH directory permissions

**Findings:**
- ed25519 key pair generated successfully with passphrase protection
- `~/.ssh/` directory created automatically with correct permissions `700`
- Private key `id_ed25519` permissions confirmed at `600` — owner read/write only
- Public key `id_ed25519.pub` permissions at `644` — readable, safe to distribute

<img width="1080" height="142" alt="WhatsApp Image 2026-07-16 at 4 05 48 PM" src="https://github.com/user-attachments/assets/b1805f88-8878-4a2a-b59a-a4748c638349" />

<img width="1080" height="142" alt="WhatsApp Image 2026-07-16 at 4 05 48 PM" src="https://github.com/user-attachments/assets/8462af6f-8e26-4be0-bd76-ed2a54f639f3" />


**Key Finding:**
- `ssh-keygen` creates two files — `id_ed25519` (private) and `id_ed25519.pub` (public)
- ed25519 is preferred over RSA — stronger cryptography, shorter key, current standard
- SSH refuses to use private keys with permissions more open than `600`

**Security Observations:**
- Private key is only as secure as the machine it lives on — disk encryption and key passphrase are both required protections
- If the machine holding the private key is stolen, immediately remove the corresponding public key from `~/.ssh/authorized_keys` on all servers
- A passphrase on the private key means the stolen file is useless without it — always set one during `ssh-keygen`
- The public key can be distributed freely — only the private key must be protected

---

## Week 5 — SSH Hardening

**File:** `/etc/ssh/sshd_config`

**Pre-Hardening State — Security Findings:**
- `PermitRootLogin yes` — root login enabled, critical vulnerability
- `PasswordAuthentication yes` — password auth enabled by default, brute force risk
- `PubkeyAuthentication` — commented out, not explicitly enabled

<img width="1280" height="318" alt="WhatsApp Image 2026-07-15 at 11 10 07 PM" src="https://github.com/user-attachments/assets/4357c846-edf8-4672-99c2-4e251628b140" />


**Changes Made:**

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

**Commands:**
- `sudo vim /etc/ssh/sshd_config` — open SSH daemon config for editing
- `sudo service ssh restart` — apply configuration changes
- `sudo service ssh status` — confirm daemon is running after restart

**Result:**
- SSH daemon restarted successfully with hardened configuration
- `sshd is running` confirmed — all three changes accepted without errors

<img width="1080" height="122" alt="WhatsApp Image 2026-07-16 at 4 14 13 PM" src="https://github.com/user-attachments/assets/8a8fbc6e-5595-4bd2-8105-1c7e30801c94" />


**Why Each Setting Matters:**
- `PermitRootLogin no` — root has no login audit trail and gives instant full system access if compromised. Disabling forces attackers to compromise a limited user first then escalate — adding a detectable step
- `PasswordAuthentication no` — eliminates brute force and credential stuffing entirely. A 256-bit ed25519 key cannot be guessed. Removes the whole attack category
- `PubkeyAuthentication yes` — must be explicitly confirmed when disabling passwords. Failing to include this locks everyone out including yourself

**Critical Sequence — Never Skip:**
1. Generate key pair
2. Deploy public key to server
3. Test key login in a **separate terminal** — confirm it works
4. Edit `sshd_config`
5. Restart sshd
6. Test login **again** before closing your existing session

**Key Finding:**
Closing your working SSH session before confirming the new configuration allows you in will lock you out of the server permanently. Step 3 and Step 6 are non-negotiable.

**Security Observations:**
- `sshd_config` should be owned by `root:root` with permissions `644` — verify with `ls -la /etc/ssh/sshd_config`
- Disabling password auth without first deploying a key leaves the server permanently inaccessible
- Moving SSH off port 22 reduces automated scan noise but is not a real security control — never treat it as one
- After hardening, test from a different machine or terminal before closing any existing sessions

---

## week 5 - Suspicious Process Detection ad Termination 

**scenario:** Simulating a planted background process and execution incident response sequence to detect and terminate it

**commands used:** 
`sleep 1000 &` - plant bacground process simulating and attacker persistence 
`ps aux | grep sleep` - locate the suspicious process by name 
`cat /proc/[PID]/status` - inspect process directly via kernel filesystem 
`kill -15 [PID]` - send SIGTERM, polite ermination request 
`ps aux | grep sleep` - confirm process is gone 

**What i did:**
- Planted background process using `sleep 1000 &` - process assigned PID 2630
  <img width="1080" height="65" alt="WhatsApp Image 2026-07-25 at 6 19 32 PM" src="https://github.com/user-attachments/assets/d1edfee2-5c63-4d7f-9178-5f8641642e99" />
  
- Ran `ps aux | grep sleep` - confirmed process visible in process table with PID 2630
  <img width="1080" height="176" alt="WhatsApp Image 2026-07-25 at 6 20 19 PM" src="https://github.com/user-attachments/assets/d33b7d88-d255-4e19-81bb-3e4c64729871" />
  
- Ran `cat /proc/2630/status` - inspected process directly via kernel filesystem, confirmed state, owner, and resource usage
  <img width="1080" height="494" alt="WhatsApp Image 2026-07-25 at 6 22 33 PM" src="https://github.com/user-attachments/assets/aa56560e-d8c3-42bb-aac9-991487de60fa" />
  <img width="1080" height="437" alt="WhatsApp Image 2026-07-25 at 6 23 45 PM" src="https://github.com/user-attachments/assets/34373708-187e-43b8-a584-23fa1013861b" />
  <img width="1080" height="244" alt="WhatsApp Image 2026-07-25 at 6 24 47 PM" src="https://github.com/user-attachments/assets/9c62d911-f018-4e9e-9ada-403b352a3726" />
  
- Ran `kill -15 2630` - sent SIGTERM polite termination request
  <img width="1080" height="44" alt="WhatsApp Image 2026-07-25 at 6 25 28 PM" src="https://github.com/user-attachments/assets/49c4532a-7675-4ba4-919d-f8c510bd8310" />
  
- Ran `ps aux | grep sleep` - confirmed process no longer present in process table
  <img width="1080" height="213" alt="WhatsApp Image 2026-07-25 at 6 26 23 PM" src="https://github.com/user-attachments/assets/451fcf58-937b-4401-acdc-a64922f99a67" />

**key findings:** 
- `Sleep 1000 &` creates a background process that maintains presence without consuming resources-mirrors how attacker persistence tools behave
- Process was immediately visible in both `ps aux` and `/proc` after planting
- SIGTERM was sufficient for termination - no SIGKILL required
- /proc/[PID]/status confirmed process state, ownership, and resource usage before termination

**Security Observations:**
- Real attacker processes disguise themselves with names similar to system processes - always verify unknown process names before terminating
- `ps aux | grep [NAME]` is the fastest way to locate a specific suspicious process
- Always attempt kill -15 before kill -9 - SIGTERM allows the process to clean up, SIGKILL does not
- A process that ignores SIGTERM and requires SIGKILL is a red flag - legitimate processes respond o polite termination
- `/proc/[PID]/status` gives the kernel's direct view - harder to spoof than standard process listing tools

## Week 5 — sshd_config Misconfiguration and Recovery
 
**Scenario:** Deliberately introducing an invalid value into sshd_config, diagnosing the failure using sshd -t, and recovering the service
 
**Commands Used:**
- `sudo vim /etc/ssh/sshd_config` — open SSH daemon config for editing
- `sudo sshd -t` — test config file for errors without restarting the service
- `sudo service ssh restart` — apply corrected configuration
- `sudo service ssh status` — confirm daemon is running after recovery
  
**What I Did:**
1. Opened `/etc/ssh/sshd_config` using `sudo vim /etc/ssh/sshd_config`
2. Changed `PermitRootLogin no` to `PermitRootLogin BROKEN` — deliberate invalid value introduced on line 41
   <img width="1080" height="607" alt="WhatsApp Image 2026-07-25 at 6 40 11 PM" src="https://github.com/user-attachments/assets/2629fcf2-045e-4c2f-ad62-f40461d18a96" />

3. Ran `sudo sshd -t` — config test returned error without restarting the service:
```
/etc/ssh/sshd_config line 41: unsupported option "BROKEN".
```
 <img width="1206" height="117" alt="WhatsApp Image 2026-07-25 at 6 37 19 PM" src="https://github.com/user-attachments/assets/7cf0ae2e-fb0e-41ac-88e9-bb52f08b2e3d" />
 
4. Reopened `sshd_config` and corrected `BROKEN` back to `no`
   <img width="1080" height="194" alt="WhatsApp Image 2026-07-25 at 6 37 25 PM" src="https://github.com/user-attachments/assets/130262a4-65ed-4300-a795-50798ec829f3" />

5. Ran `sudo service ssh restart` — returned `[ OK ]`
6. Ran `sudo service ssh status` — returned `sshd is running`, service fully recovered
  <img width="1256" height="133" alt="WhatsApp Image 2026-07-25 at 6 37 35 PM" src="https://github.com/user-attachments/assets/40047215-1160-4945-8a22-85aea48971c4" />


**Key Finding:**
- `sudo sshd -t` identified the exact line number of the misconfiguration — line 41 — without restarting the service or causing any disruption
- Invalid value `BROKEN` triggered `unsupported option` error — sshd rejects unrecognised directives immediately
- Always run `sudo sshd -t` before restarting sshd — it catches errors before they cause lockout
**What Would Happen on a Real Server:**
- If sshd failed to restart after a bad config edit and the existing session was closed, the server would be permanently inaccessible via SSH
- `sudo sshd -t` is the correct diagnostic tool — test config first, restart second, always
- A deliberate sshd_config misconfiguration by an attacker is a known lockout technique — administrators lose SSH access to their own server
**Security Observations:**
- A single invalid line in `sshd_config` can take down SSH access entirely — every config change must be tested before applying
- `sudo sshd -t` validates the full config file and reports exact line numbers of errors — no guesswork required
- Always keep an existing SSH session open while editing `sshd_config` — close it only after confirming the new config works
- Log the before and after state of any config change during incident response — establishes timeline and intent
- In a real incident, a misconfigured sshd_config could be an attacker's deliberate move to lock administrators out permanently
 

---

## Hands-On Checklist

- [x] Navigate filesystem — `ls -la` on `/etc`, `/var/log`, `/home`, `/proc`
- [x] Create, edit, and delete files using nano and vim
- [x] Decode live permission strings from `ls -la` output
- [x] Run `ps aux` and identify process states on a real system
- [x] Execute full incident response sequence on a suspicious process
- [x] Generate ed25519 key pair with `ssh-keygen`
- [x] Inspect `~/.ssh/` directory and confirm file permissions
- [x] Edit `sshd_config` and apply all hardening changes
- [x] Restart sshd and confirm with `systemctl status`
- [x] Plant suspicious process - detect with `ps aux`, terminate with `kill`, document
- [x] Delibrately break `sshd_config` - diagnose with `sshd -t`, recover, document
- [ ]  Complete OverTheWire Bandit levels 0-10

---

*Week 05 of 12 — Cloud Security Self-Study Program*
*Repository: cloud-security-portfolio*




Week6 terraform ec2 basics · MD
# Week 6 — Terraform + EC2 Basics
 
**Status:** Complete
**Environment:** Google Cloud Shell (pivoted from GitHub Codespaces mid-week)
 
---
 
## Environment Notes
 
This week didn't start where the plan said it would. My AWS root account was suspended within a day of creating it — before I'd even added a payment method — and I don't currently have a card of my own or family access to one, so live deployment against AWS is on hold pending that getting sorted out.
 
Rather than block the whole week on that, I moved everything else forward in Google Cloud Shell instead. Two things about that environment are worth documenting, because they cost me real debugging time and are the kind of thing worth knowing going in rather than discovering by accident:
 
- **Cloud Shell containers don't run systemd.** Any command that goes through `systemctl` (start, enable, status) fails with `Failed to connect to bus: Host is down`. The fix is to use `service <name> start` or `apachectl start` instead — these talk to the process directly instead of through the init system.
- **Only the home directory persists between sessions.** Anything installed system-wide via `apt-get` (Apache, in this case) has to be reinstalled every time a new session starts. Scripts, SSH keys, and repo files survive; installed packages don't. This actually turned out to be a decent stand-in lesson for how ephemeral environments behave in real CI/CD and container-based infra — write scripts assuming nothing persists except what you explicitly put in version control.
---
 
## chmod / chown
 
Worked through octal notation on three test files, predicting the permission string before applying each one, then checked with `ls -l`.
 
- `700` — owner full access, nothing for anyone else. Used this for scripts and anything with potential secrets in it.
- `644` — standard default for non-sensitive files: owner read/write, everyone else read-only.
- `600` — owner read/write only. Right call for config files, since they often hold credentials.
The one correction worth noting: I initially assumed `755`/`555` meant "owner only" — they don't. `755` opens execute to everyone, just restricts write to the owner. `700` is the actual "nobody else can touch this at all" setting.
 
---
 
## Process Management
 
Practiced `ps aux`, `top`, `htop`, and `kill` on a real (harmless) background process:
 
```bash
sleep 300 &
ps aux | grep sleep
kill [PID]
```
 
Also used this later as the basis for Incident 2 below, using `yes > /dev/null &` to simulate genuine CPU load instead of a passive sleeping process.
 
---
 
## Bash Scripts (5 total)
 
All five written, made executable (`chmod 700`), and tested individually.
 
- **`update_system.sh`** — runs `apt-get update && apt-get upgrade`.
- **`install_apache.sh`** — installs Apache and starts it via `service` (not `systemctl`, for the reason above). Verified with `curl http://localhost` rather than trusting the install command's own "success" output.
- **`create_user.sh`** — prompts for a username, creates the user with `useradd -m -s /bin/bash`, sets a password, confirms with `id`.
- **`log_checker.sh`** — reads Apache's `access.log`, prints the last 10 entries, and counts 404s/500s with `grep | wc -l`.
- **`port_scanner.sh`** — loops over a list of ports (22, 80, 443, 3306, 8080) and checks each with the `/dev/tcp` bash trick, correctly reporting 22 and 80 open and the rest closed.
---
 
## Terraform
 
Installed Terraform (v1.9.8) manually into `~/bin` since it isn't preinstalled in Cloud Shell, and added it to `PATH` via `.bashrc`.
 
Wrote `main.tf` defining a `t2.micro` EC2 instance under the AWS provider. Ran:
 
```bash
terraform init      # pulled the AWS provider plugin, created .terraform.lock.hcl
terraform validate  # "Success! The configuration is valid."
```
<img width="1080" height="607" alt="image" src="https://github.com/user-attachments/assets/95a8d4e0-ef3b-41e3-bb51-2b33197fc037" />

 
`terraform apply` is intentionally not run yet — it needs working AWS credentials, which are blocked by the account suspension noted above. The config itself is validated and ready to deploy the moment that's resolved.
 
---
 
## Incident Queue
 
Three simulated breaks this week, each worked the same way: break it → confirm the break from outside (not just trust the tool's own output) → check whether the process itself is even still alive → read the actual logs for the specific cause → fix that exact cause, not a symptom → re-verify externally.
 
**Incident 1 — Wrong file permissions break Apache**
`chmod 000` on `/var/www/html/index.html` (not the log file — that one didn't affect anything, since Apache had it open already). `curl` returned 403. `tail` on `error.log` showed a permission-denied error naming the file directly. Fixed with `chmod 644`, re-verified with `curl`.
 <img width="1080" height="311" alt="WhatsApp Image 2026-08-04 at 3 07 59 PM" src="https://github.com/user-attachments/assets/4b345bd6-da6f-4126-83d3-97a1f73d4984" />

**Incident 2 — Runaway process consuming CPU**
Started `yes > /dev/null &` as a stand-in for a real hung process. Found it with `ps aux --sort=-%cpu`, noted the PID, killed it, confirmed it was gone with a second `ps aux | grep`.
 <img width="1080" height="183" alt="WhatsApp Image 2026-08-04 at 3 09 37 PM" src="https://github.com/user-attachments/assets/4c2ae20b-a16e-4eae-bdbd-f565f7f15cdc" />

**Incident 3 — Bash script fails silently**
Wrote a backup script that ran `cp` into a directory that didn't exist yet, but printed "Backup complete."<img width="1080" height="89" alt="WhatsApp Image 2026-08-04 at 3 12 04 PM" src="https://github.com/user-attachments/assets/4d3881e5-8dd0-4ec0-9aa0-57ca88a909d8" />

regardless of whether the copy actually succeeded. Confirmed the failure by checking the destination directory directly rather than trusting the script's message — it was empty. Rewrote the script to `mkdir -p` the destination first and wrap the `cp` in an `if/else` so it only reports success when the copy genuinely worked, and exits with an error code and a real message when it doesn't.
 
---
 
## Takeaway
 
The most useful thing this week wasn't any single command — it was the incident loop itself: don't trust a tool's self-reported success, verify independently, check the process is alive before assuming the whole system is down, and go to the logs for the actual cause before attempting a fix. That loop is the same one used in a live incident with an unknown cause, just practiced here on ones I set up myself.
 
*Week 06 of 12 — Cloud Security Self-Study Program*
*Repository: cloud-security-portfolio*



# AWS Account Setup & Terraform EC2 Deployment (week6-7)

**Date:** August 8, 2026
**Environment:** Google Cloud Shell (`~/week6-work`)

## Summary

Original AWS root account was suspended shortly after signup, before a payment method was added, blocking the Week 6 Terraform deployment. Opened a fresh AWS account, resolved the blocker, and successfully deployed the EC2 instance defined in `main.tf`.

## AWS Account Setup

- Opened a new AWS account after the original root account was suspended pre-payment-method
- Selected the **Free plan** (Nigeria billing) — no upfront charge, up to $200 in credits over 6 months
- **Payment note:** Verve cards are not accepted by AWS; a Visa or Mastercard is required for account verification
- Enabled **root account MFA** using an authenticator app (AWS enforces MFA for root within 35 days of account creation)
- Configured a **zero-spend billing budget** alert to receive email notification of any charge above $0.01

## IAM Setup

- Created a dedicated IAM user (`terraform-cli`) with `AdministratorAccess`, rather than using root credentials for CLI/Terraform work — standard least-privilege practice for infrastructure tooling
- Generated an access key pair (Access Key ID + Secret Access Key) for CLI authentication

## Cloud Shell / AWS CLI Configuration

- AWS CLI was not preinstalled in this Cloud Shell session; installed manually:
  ```bash
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  ```
- Authenticated Cloud Shell to the AWS account:
  ```bash
  aws configure
  ```
- Verified identity:
  ```bash
  aws sts get-caller-identity
  ```
  Confirmed authentication as `arn:aws:iam::478769829434:user/terraform-cli`

## Terraform Deployment Issue & Fix

- Initial `terraform apply` failed with:
  ```
  InvalidParameterValue: The specified instance type is not eligible for Free Tier
  ```
- **Root cause:** AWS accounts created on or after July 15, 2025 have a different Free Tier eligible instance list than legacy accounts. `t2.micro` — the default used in most tutorials and in the original `main.tf` — is **not** eligible for new accounts.
- **Free Tier eligible instance types for new accounts:** `t3.micro`, `t3.small`, `t4g.micro`, `t4g.small`, `c7i-flex.large`, `m7i-flex.large`
- **Fix:** updated `main.tf`, changing:
  ```hcl
  instance_type = "t2.micro"
  ```
  to:
  ```hcl
  instance_type = "t3.micro"
  ```

## Deployment Result

- Re-ran `terraform plan` to confirm the corrected instance type, then `terraform apply`
- Deployment succeeded:
  ```
  aws_instance.week6_ec2: Creation complete after 14s [id=i-08e94c69d389f70ea]
  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  ```

## Key Takeaway

The Free Tier eligible instance list depends on **AWS account creation date**, not just region. This is a common gap in existing tutorials/guides, most of which still default to `t2.micro`. Worth checking `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true` before writing any `main.tf` for a new account going forward.


# Week 7 — AWS Core Services + Billing Control

## Overview
This week focused on provisioning real AWS infrastructure through Terraform, securing it properly, and practicing incident response against live resources. Everything below was built, broken, diagnosed, and fixed on an active AWS account — not simulated.

---

**date:** August 15,2026

---

## Environment
- **Working directory:** `~/week7-work` (Google Cloud Shell)
- **IaC tool:** Terraform, AWS provider `~> 6.0` (with `tls` and `local` providers for key generation)
- **Region:** `us-east-1`
- **EC2 instance:** `t3.micro`, Amazon Linux 2023
- **S3 bucket:** `week7-portfolio-olabodedaniel`
- **Access:** AWS CLI configured locally (`~/.local/bin`, persisted across Cloud Shell sessions), SSH via generated key pair

---

## EC2 Deployment (Terraform)

Deployed a live EC2 instance via Terraform, including:
- Security group with scoped SSH access (restricted to my IP) and open HTTP (port 80)
- Key pair generated through Terraform (`tls_private_key` + `aws_key_pair`), private key written locally with `0400` permissions
- EC2 instance wired to both the security group and key pair
- Apache installed and enabled via SSH, confirmed serving the default page at the instance's public IP

**Issues hit along the way (and fixed):**
- Duplicate `aws_instance` resource block from a bad paste — traced and removed
- AWS provider version mismatch between `required_providers` and the version that had actually created the resource — resolved with `terraform init -upgrade`
- Cloud Shell disk filled to 100% mid-deploy from repeated provider downloads — cleared with `du`/`rm`, redeployed cleanly
- SSH key filename typo (`week7-keypem` vs `week7-key.pem`) — caught before wasting a cycle
- Cloud Shell's public IP rotates between sessions, which repeatedly broke the SSH security group rule — learned to check `curl ifconfig.me` and update the rule whenever a connection times out unexpectedly

**Result:** Live webpage served from EC2, fully provisioned via Terraform, goal met.

---

## S3 Bucket Setup (Terraform)

Provisioned an S3 bucket with a security-first configuration:
- Bucket created with `BucketOwnerEnforced` ownership controls (disables legacy ACLs entirely)
- Test file uploaded via `aws_s3_object`
- Bucket policy scoped to my AWS account root ARN only — no public access granted

**Issues hit along the way (and fixed):**
- Bucket policy JSON rejected by AWS twice — first for a lowercase `Aws` key instead of `AWS`, then for smart/curly quotes silently introduced by copy-paste, invisible in the terminal but invalid to AWS's JSON parser. Rebuilt the block using a direct heredoc (`cat >> file << EOF`) to guarantee clean ASCII characters.
- Bucket policy `Principal` initially referenced a mistyped AWS account ID — corrected after cross-checking `aws sts get-caller-identity`

**Result:** Bucket is private and correctly scoped — no public read/write access exists.

---

## Incident Queue

### Incident 1: S3 Bucket Returns 403
**Symptom:** Anonymous HTTPS request to the uploaded object returns 403 Forbidden.

**Trace:**
1. Verified bucket policy — access scoped to account root ARN only, no public principal.
2. Verified Public Access Block settings — all four flags enabled (blocking public access at the bucket level regardless of policy content).
3. Verified object ownership — `BucketOwnerEnforced`, ACLs disabled by design.

**Root cause:** Expected behavior. The bucket is intentionally private; no public read access was ever configured.

**Resolution:** No fix needed. Confirmed authenticated access succeeds (`aws s3 cp` using account credentials returns the file correctly), proving the policy works as intended for the authorized principal.

**Decision:** Bucket stays private — reflects secure-by-default practice.

---

### Incident 2: EC2 Apache Not Reachable
**Symptom:** Site fails to load; connection refused.

**Trace:**
1. Checked service status — journal showed a clean, deliberate stop (not a crash): "Stopping" → "Deactivated successfully" → "Stopped."
2. Checked listening ports — nothing bound to port 80, consistent with Apache being down.
3. Checked error logs — no crash traces. Only routine bot traffic probing for directory listing, correctly denied.

**Root cause:** Apache service was manually stopped to simulate a real outage.

**Resolution:** Restarted the service using `sudo systemctl...httpd`, confirmed `active (running)`, verified the page loads again externally.

**Observation worth noting:** The logs also showed ongoing automated scanning traffic from external IPs — all correctly blocked. No misconfiguration, but a good reminder that a live server is public the moment it's up.

---

### Incident 3: Billing Alert Investigation
**Symptom:** Simulated billing alert — investigate for unexpected charges.

**Trace:**
1. Checked running EC2 instances — one instance, t3.micro, free-tier eligible.
2. Checked EBS volumes — one 8GB gp3 volume (instance root disk), within the 30GB/month free allowance.
3. Checked Elastic IPs — none allocated, ruling out the common "unattached EIP billing hourly" trap.

**Root cause:** No misconfiguration found. All active resources fall within AWS Free Tier limits.

**Resolution:** No termination necessary. Investigation confirmed legitimate near-zero spend rather than assuming a problem existed and cutting resources unnecessarily.

**Decision:** Resources remain running. This incident reinforced the diagnostic order for billing investigations — instances, then storage, then IPs — before taking any destructive action.

---

## Key Takeaways
- Every incident this week followed the same discipline: reproduce the symptom, trace through the relevant layers in order, only then decide on a fix. Two of the three incidents concluded "this is working correctly" rather than "here's what I broke" — proving a system is healthy is as much a real skill as fixing one that isn't.
- Most of the week's actual friction wasn't AWS concepts — it was environment mechanics: Cloud Shell's ephemeral IP and disk quota, invisible characters from copy-paste, and small typos. Learning to diagnose *those* systematically was arguably the bigger lesson than any single AWS service.
- Terraform errors are almost always exactly what they say — duplicate resources, version mismatches, invalid syntax. Reading the error carefully before guessing at a fix saved more time than any shortcut would have.

---

## CLF-C02 Study
- Completed FreeCodeCamp CLF-C02 video, hours 1-4
- completed daily practice questions (20/day)
