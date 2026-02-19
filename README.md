# cf-ddns - Cloudflare Dynamic DNS Updater

Bash script that automatically updates all **A records** in a Cloudflare DNS zone to match your current public IPv4 address. Useful for home servers or any machine with a dynamic IP.

---

## Dependencies

You need both of these installed before running the script:

- `curl` - for making HTTP requests
- `jq` - for parsing JSON responses

---

## Setup

### 1. Download the script

```bash
curl -O https://raw.githubusercontent.com/nixietab/cf-ddns/refs/heads/main/cf-ddns.sh
```


### 1. Make the script executable

```bash
chmod +x cf-ddns.sh
```

### 2. Get your Cloudflare credentials

You need two things from Cloudflare:

**Zone ID**
- Log in to the [Cloudflare dashboard](https://dash.cloudflare.com)
- Select your domain
- Scroll down on the **Overview** tab — the Zone ID is in the right-hand sidebar

**API Token**
- Go to **My Profile → API Tokens → Create Token**
- Use the **Edit zone DNS** template, or create a custom token with:
  - Permissions: `Zone > DNS > Edit`
  - Zone Resources: Include the specific zone you want to update
- Copy the token

---

## Usage

Run the script by passing your Zone ID and API token as arguments:

```bash
./cf-ddns.sh -z <zone_id> -t <api_token>
```

**Example:**
```bash
./cf-ddns.sh -z 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d -t your_cloudflare_api
```
---

## Automating with Cron

To run the script automatically (e.g. every 5 minutes), add it to your crontab:

```bash
crontab -e
```

Add a line like:
```
*/5 * * * * /path/to/cf-ddns.sh -z <zone_id> -t <api_token> >> /var/log/cf-ddns.log 2>&1
```

## Notes

- Only **A records** (IPv4) are updated - AAAA and other record types are left untouched
- The script updates **all** A records in the zone, not just a specific subdomain
- TTL and proxy settings on each record are preserved
