# 🕵️‍♂️ SubSpy – Automated Subdomain Monitoring

A bash script to automatically discover and monitor subdomains for multiple domains. It sends notifications directly to your Discord channel whenever new subdomains or subdomain takeover vulnerabilities are identified.

## ⚙️ Requirements

- [subfinder](https://github.com/projectdiscovery/subfinder)
- [jq](https://stedolan.github.io/jq/download/)
- [nuclei](https://github.com/projectdiscovery/nuclei)
- `curl` (pre-installed in most Linux distros)

Install quickly with Go:

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
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

The primary way to configure SubSpy is through the `domains.txt` file and a `config.sh` file for more advanced settings.

### 1. `domains.txt`

- Create a file called `domains.txt` in the same directory as the script.
- Add your target domains line-by-line:

```
example.com
testsite.com
```

### Setting Up Discord Notifications

- Create a Discord channel.

- Create a webhook in your Discord channel:

  - Go to `Channel Settings` → `Integrations` → `Webhooks`
  - Click `New Webhook`, give it a name, and copy the URL.

- On the first run, the script will prompt you to enter your Discord webhook URL. This URL is then stored in a hidden file (`.discord_webhook`) in the script's directory for future runs.

### 2. `config.sh` (Advanced Configuration)

For more fine-grained control, SubSpy uses a `config.sh` file.

- **Creation**: If `config.sh` does not exist when you run `subspy.sh`, the script will automatically copy `config.sh.example` to `config.sh`. You should review and customize this file to suit your needs.
- **Variables**: The following variables can be set in `config.sh`:
    - `GOPATH_BIN`: Specifies the path to your Go binaries (like `subfinder` and `nuclei`).
        - Default: `~/go/bin`
        - Example: `GOPATH_BIN="/custom/path/go/bin"`
    - `LOG_FILE`: Defines the path where the script's log file will be stored.
        - Default: `subspy.log` (in the script's directory)
        - Example: `LOG_FILE="/var/log/subspy/activity.log"`
    - `SUBFINDER_FLAGS`: Allows you to pass custom flags to the `subfinder` command.
        - Default: None
        - Example: `SUBFINDER_FLAGS="-recursive -all -timeout 30"`
    - `NUCLEI_FLAGS`: Allows you to pass custom flags to the `nuclei` command (for takeover checks).
        - Default: None
        - Example: `NUCLEI_FLAGS="-retries 3 -severity critical,high"`
    - `NUCLEI_SCAN_NEW_ONLY`: Determines if Nuclei should scan only newly discovered subdomains or all subdomains.
        - Default: `false` (scans all subdomains in `today_list`)
        - Set to `true` to scan only subdomains present in `diff_file` (newly found ones). If no new subdomains are found, it will scan `today_list` as a fallback and notify you.
        - Example: `NUCLEI_SCAN_NEW_ONLY="true"`

### 3. Webhook Verification

**Webhook Verification**:

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

Add this line (ensure `/path/to/subspy.sh` is correct and consider using the configured `LOG_FILE` if you change it from the default `subspy.log` in the script's directory):

```cron
0 8 * * * /path/to/subspy.sh # Script now handles its own logging via LOG_FILE in config.sh
```
If you want to capture cron's own output (e.g., if `subspy.sh` itself cannot be executed), you can still redirect:
```cron
0 8 * * * /path/to/subspy.sh >> /path/to/your/cron_specific.log 2>&1
```

## 📝 Logging

SubSpy now features more robust logging:

- **Log File**: All operations, informational messages, warnings, and errors are logged to a file.
    - Default location: `subspy.log` in the script's directory.
    - Configurable via the `LOG_FILE` variable in `config.sh`.
- **Log Format**: Entries are timestamped and include a log level:
    `[YYYY-MM-DD HH:MM:SS] [LEVEL] Log message content`
    - Example: `[2023-10-27 10:00:00] [INFO] SubSpy started by user.`
    - Levels include `INFO`, `WARN` (for non-critical issues or important notices), and `ERROR`.

## ⚠️ Error Handling & Dependency Checks

- **Dependency Check**:
    - At startup, SubSpy verifies that all required tools (`subfinder`, `nuclei`, `jq`, `curl`) are installed and accessible in your PATH.
    - If any dependency is missing, the script will:
        - Log an error message.
        - Send a Discord notification (if `curl` is available and webhook is configured).
        - Print the error to the console.
        - Exit immediately.
- **Tool Failures**:
    - If `subfinder` or `nuclei` commands fail during a scan for a specific domain (e.g., due to an invalid flag or tool error), SubSpy will:
        - Log the error.
        - Send a Discord notification detailing the failure (e.g., "❌ ERROR: subfinder failed for domain example.com...").
        - Skip processing for the current domain and move to the next one, ensuring the script doesn't halt completely.

## 📌 How it Works

- **Initialization**:
    - Sets up its environment and loads configuration from `config.sh` (or creates one from `config.sh.example`).
    - Performs a dependency check for `subfinder`, `nuclei`, `jq`, and `curl`. Exits if any are missing.
    - Verifies Discord webhook connectivity.
- **Domain Processing**: For each domain in `domains.txt`:
    - Performs subdomain enumeration using `subfinder` (with custom flags if provided in `config.sh`).
    - Compares the current scan's results (`today_list`) against the previous scan's results (`backup_list`).
    - If new subdomains are found, they are stored in `diff_file`.
- **Vulnerability Scanning**:
    - Runs `nuclei` (with custom flags if provided) to check for subdomain takeovers.
    - By default, scans all subdomains found in the current scan (`today_list`).
    - If `NUCLEI_SCAN_NEW_ONLY` is set to `true` in `config.sh` and new subdomains were found, `nuclei` will only scan these new subdomains (`diff_file`). If `NUCLEI_SCAN_NEW_ONLY` is `true` but no new subdomains are found, it scans `today_list` and notifies about this behavior.
- **Notifications**:
    - Immediately sends alerts to your Discord channel for:
        - Newly discovered subdomains.
        - Detected subdomain takeover vulnerabilities.
        - Errors during tool execution (e.g., `subfinder` or `nuclei` failing).
    - Provides clear updates about scan initiation, completion, and individual domain scanning.
- **Logging**: All actions, errors, and notifications are logged to the file specified by `LOG_FILE` in `config.sh` (default `subspy.log`), with timestamps and log levels.

## 🖥️ Example Discord Notifications

- **Webhook Verified:**

```
✅ Webhook configured successfully! (Webhook verification)
```

- **Scanning Started:**

```
🔄 Subdomain Monitoring Scan Started!
```

- **Scanning Domain:**

```
🟡 Scanning: example.com
```

- **Initial Scan Completed:**

```
✅ Initial scan completed for example.com: Found 42 subdomains.
```

- **New Subdomains Discovered:**

```
🚨 New subdomains detected for example.com (2):

domain1.example.com
domain2.example.com
```

- **Subdomain Takeover Detected:**

```
🔥 Takeover detected!
Subdomain: vulnerable.example.com
Vulnerability: AWS Bucket Takeover
```

- **No New Subdomains:**

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
