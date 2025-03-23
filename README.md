# 🕵️‍♂️ SubSpy – Automated Subdomain Monitoring

A bash script to automatically discover and monitor subdomains for multiple domains daily. It sends notifications directly to your Discord channel whenever new subdomains are identified.

## ⚙️ Requirements

- [subfinder](https://github.com/projectdiscovery/subfinder)
- [jq](https://stedolan.github.io/jq/download/)
- [anew](https://github.com/tomnomnom/anew)
- `curl` (pre-installed in most Linux distros)

Install quickly with Go:

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/anew@latest
sudo apt install jq
```

Ensure Go binaries are added to your PATH:

```bash
export PATH=$PATH:~/go/bin
```

## 🚀 Installation

```bash
git clone https://github.com/themalwarenews/SubSpy/
cd SubSpy
chmod +x subspy.sh
```

## 🛠️ Configuration

- Create a file called `domains.txt` in the same directory as the script.
- Add your domains line-by-line:

```
example.com
testsite.com
```

### Setting Up Discord Notifications

- Create a Discord channel.

- Create a webhook in your Discord channel:

  - Go to `Channel Settings` → `Integrations` → `Webhooks`
  - Click `New Webhook`, give it a name, and copy the URL.

- Set your Discord webhook URL as an environment variable:

```bash
export DISCORD_WEBHOOK="your_discord_webhook_url_here"
```

**Verify Webhook**:

- The first time you run the script, it sends a test notification automatically.

## ▶️ Running the Script

To run manually:

```bash
./subspy.sh
```

### Automate with Cron Job

Run the scan daily at 8:00 AM:

```bash
crontab -e
```

Add this line:

```cron
0 8 * * * /path/to/subspy.sh >> /var/log/subspy.log 2>&1
```

## 📌 How it Works

- Performs daily subdomain enumeration.
- Compares the results against the previous run.
- Immediately sends new findings to your Discord channel.
- Provides clear updates about each scan.

## 🖥️ Example Discord Notifications

- **Webhook Verified:**

```
✅ Webhook configured successfully! (Webhook verification)
```

- **Scanning Started:**

```
🔄 Subdomain Monitoring Scan Started!
```

- **Scanning domain:**

```
🟡 Scanning: example.com
```

- **Initial scan completed:**

```
✅ Initial scan completed for example.com: Found 42 subdomains.
```

- **New subdomains discovered:**

```
🚨 New subdomains detected for example.com (2):

domain1.example.com
domain2.example.com
```

- **No new subdomains:**

```
✅ No new subdomains found for example.com.
```

- **Scan Completed:**

```
🏁 Subdomain Monitoring Scan Completed for all domains!
```

## 🧑‍💻 Contributions

Contributions are welcome! Feel free to open issues, submit pull requests, and improve documentation.

---

**Happy Monitoring! 🔎**
