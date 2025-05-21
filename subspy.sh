#!/usr/bin/env bash

cd "$(dirname "$0")"

# Default configuration values
GOPATH_BIN_DEFAULT="$HOME/go/bin"
LOG_FILE_DEFAULT="subspy.log"

# Configuration file
CONFIG_FILE="config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    # Source the existing config file
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    echo "[INFO] Loaded configuration from $CONFIG_FILE"
else
    # Create a default config file from the example
    if [[ -f "config.sh.example" ]]; then
        cp "config.sh.example" "$CONFIG_FILE"
        echo "config.sh not found. Created a default one from config.sh.example. Please review and customize it."
        # Source the newly created default config file
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        echo "[WARNING] config.sh.example not found. Using default values for GOPATH_BIN and LOG_FILE."
    fi
fi

# Use configured values or defaults
GOPATH_BIN_ACTUAL="${GOPATH_BIN:-$GOPATH_BIN_DEFAULT}"
LOG_FILE_ACTUAL="${LOG_FILE:-$LOG_FILE_DEFAULT}"
NUCLEI_SCAN_NEW_ONLY_ACTUAL="${NUCLEI_SCAN_NEW_ONLY:-false}" # Default to false if not set

# Set proper environment for Go-based tools
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH="$GOPATH_BIN_ACTUAL:$SYSTEM_PATH"

# Ensure log directory exists (if LOG_FILE_ACTUAL includes a path)
LOG_DIR=$(dirname "$LOG_FILE_ACTUAL")
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" # This will create parent dirs as needed
fi

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    # Appends to LOG_FILE_ACTUAL which is globally defined by this point
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE_ACTUAL"
}

# Dependency check function
check_dependencies() {
    log_message "INFO" "Starting dependency check..."
    local required_tools=("subfinder" "nuclei" "jq" "curl")
    local missing_tools=()
    local tools_found_msg="" # For INFO log if all present
    local tools_missing_msg="" # For ERROR log and Discord notification

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            tools_found_msg+=" $tool"
        else
            missing_tools+=("$tool")
            tools_missing_msg+=" $tool"
        fi
    done

    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        local error_message="Dependency check failed. Missing required tools:${tools_missing_msg}."
        log_message "ERROR" "$error_message"
        
        # Check if curl is one of the missing tools OR if DISCORD_WEBHOOK is not set.
        # If so, Discord notification for this specific error is not possible or not configured.
        local curl_is_missing=false
        for missing_tool in "${missing_tools[@]}"; do
            if [[ "$missing_tool" == "curl" ]]; then
                curl_is_missing=true
                break
            fi
        done

        if [[ "$curl_is_missing" == "true" ]] || [[ -z "$DISCORD_WEBHOOK" ]]; then
            log_message "WARN" "Cannot send Discord notification for dependency error because curl is missing or Discord webhook is not configured."
        else
            # Only attempt to notify if curl is present and webhook is configured
            notify_discord "❌ **Dependency Error!** Missing required tools:${tools_missing_msg}. Please install them for SubSpy to function."
        fi
        
        echo -e "\n[ERROR] $error_message\nPlease install the missing tools and try again." >&2 # To stderr
        exit 1
    else
        log_message "INFO" "Dependency check passed. All required tools are installed:${tools_found_msg}."
    fi
}

log_message "INFO" "SubSpy started by $(whoami)."

# Dependency check function
check_dependencies() {
    log_message "INFO" "Starting dependency check..."
    local required_tools=("subfinder" "nuclei" "jq" "curl")
    local missing_tools=()
    local tool_found_msg=""
    local tool_not_found_msg=""

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            tool_found_msg+=" $tool" # Accumulate found tools for a single log message if needed
        else
            missing_tools+=("$tool")
            tool_not_found_msg+=" $tool" # Accumulate not found tools
        fi
    done

    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        local error_message="Dependency check failed. Missing required tools:${tool_not_found_msg}."
        log_message "ERROR" "$error_message"
        # Attempt to notify via Discord if curl is available, otherwise, this will gracefully fail or be logged by notify_discord itself.
        # If curl itself is missing, this specific notification won't go out, but the script will exit.
        notify_discord "❌ **Dependency Error!** Missing required tools:${tool_not_found_msg}. Please install them for SubSpy to function."
        echo -e "\n[ERROR] $error_message\nPlease install the missing tools and try again." >&2 # To stderr
        exit 1
    else
        log_message "INFO" "Dependency check passed. All required tools found:${tool_found_msg}."
    fi
}

# Initial setup calls
cd "$(dirname "$0")" # Moved here as it's fundamental

# Default configuration values (defined before sourcing config, in case config is missing)
GOPATH_BIN_DEFAULT="$HOME/go/bin"
LOG_FILE_DEFAULT="subspy.log" # Default log file in script's directory
NUCLEI_SCAN_NEW_ONLY_DEFAULT="false"

# Configuration file
CONFIG_FILE="config.sh"

# Use configured values or defaults - Initialize with defaults first
GOPATH_BIN_ACTUAL="${GOPATH_BIN_DEFAULT}"
LOG_FILE_ACTUAL="${LOG_FILE_DEFAULT}"
NUCLEI_SCAN_NEW_ONLY_ACTUAL="${NUCLEI_SCAN_NEW_ONLY_DEFAULT}"
# SUBFINDER_FLAGS and NUCLEI_FLAGS will be whatever is in the sourced config, or empty if not set.

# Ensure log directory exists (if LOG_FILE_ACTUAL includes a path)
# This needs LOG_FILE_ACTUAL to be set, so config sourcing must happen first.
# Moved this block after config sourcing.

# Logging function (defined after LOG_FILE_ACTUAL is potentially set by config)
# log_message() is defined above, this is fine.

# Load configuration (must happen before setting up PATH with GOPATH_BIN_ACTUAL and before check_dependencies which might use curl)
if [[ -f "$CONFIG_FILE" ]]; then
    # Source the existing config file
    # shellcheck disable=SC1090
    source "$CONFIG_FILE" # This will overwrite defaults if they are set in config.sh
    log_message "INFO" "Loaded configuration from $CONFIG_FILE."
else
    # Create a default config file from the example
    if [[ -f "config.sh.example" ]]; then
        cp "config.sh.example" "$CONFIG_FILE"
        echo "config.sh not found. Created a default one from config.sh.example. Please review and customize it."
        log_message "INFO" "config.sh not found. Created a default one from config.sh.example. User notified via console to review and customize."
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" # Source the newly created config
    else
        echo "[WARNING] config.sh.example not found. Using default values for GOPATH_BIN, LOG_FILE, and NUCLEI_SCAN_NEW_ONLY."
        log_message "WARN" "config.sh.example not found. Using default values for GOPATH_BIN_DEFAULT, LOG_FILE_DEFAULT, and NUCLEI_SCAN_NEW_ONLY default (false)."
    fi
fi

# Re-apply defaults if variables are empty after sourcing config (e.g. user deleted a line from config.sh)
GOPATH_BIN_ACTUAL="${GOPATH_BIN:-$GOPATH_BIN_DEFAULT}"
LOG_FILE_ACTUAL="${LOG_FILE:-$LOG_FILE_DEFAULT}"
NUCLEI_SCAN_NEW_ONLY_ACTUAL="${NUCLEI_SCAN_NEW_ONLY:-$NUCLEI_SCAN_NEW_ONLY_DEFAULT}"

# Now that LOG_FILE_ACTUAL is definitively set, ensure log directory exists
LOG_DIR=$(dirname "$LOG_FILE_ACTUAL")
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" # This will create parent dirs as needed
fi
# And re-log the script start with the potentially correct log file.
# This is a bit tricky. The first log_message "SubSpy started..." might go to a default log file if config changes it.
# For simplicity, we'll accept this. The crucial logs (dependencies, errors) will go to the correct one.

# Set proper environment for Go-based tools (needs GOPATH_BIN_ACTUAL)
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH="$GOPATH_BIN_ACTUAL:$SYSTEM_PATH"
log_message "INFO" "PATH set to: $PATH"

# Now call dependency check
check_dependencies # This needs to be after config load (for potential GOPATH_BIN changes affecting tool paths) and PATH setup.

# Webhook file and verification
WEBHOOK_FILE=".discord_webhook" # Define WEBHOOK_FILE path

if [[ ! -f "$WEBHOOK_FILE" ]]; then
    # Prompt user for webhook ONLY if the file doesn't exist.
    read -rp "Enter your Discord webhook URL: " user_webhook
    if [[ -n "$user_webhook" ]]; then
        echo "$user_webhook" > "$WEBHOOK_FILE"
        log_message "INFO" "Discord webhook URL saved to $WEBHOOK_FILE."
    else
        log_message "WARN" "No Discord webhook URL entered. Notifications will not be sent."
    fi
fi

# Read webhook URL if file exists
if [[ -f "$WEBHOOK_FILE" ]]; then
    DISCORD_WEBHOOK=$(cat "$WEBHOOK_FILE")
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        log_message "WARN" "$WEBHOOK_FILE is empty. Discord notifications will not be sent."
    else
        log_message "INFO" "Discord webhook URL loaded from $WEBHOOK_FILE."
        # Verify webhook only if it's loaded and .webhook_verified does not exist
        if [[ ! -f ".webhook_verified" ]]; then
            log_message "INFO" "Verifying Discord webhook..."
            notify_discord "✅ **Webhook configured successfully!** _(Webhook verification)_"
            # Only touch .webhook_verified if the notification attempt was made (not necessarily succeeded, but curl ran)
            # and DISCORD_WEBHOOK was not empty.
            touch ".webhook_verified"
            log_message "INFO" ".webhook_verified file created."
        else
            log_message "INFO" "Discord webhook already verified (found .webhook_verified)."
        fi
    fi
else
    log_message "INFO" "$WEBHOOK_FILE not found. Discord notifications will be skipped."
    DISCORD_WEBHOOK="" # Ensure it's empty if no file
fi

if [[ ! -f "domains.txt" ]]; then
    # Critical error, log and exit. Console message is also important.
    echo "domains.txt not found in the current directory." 
    log_message "ERROR" "domains.txt not found in the current directory. SubSpy is exiting."
    # If DISCORD_WEBHOOK is already set, we could try to notify. But it might not be.
    # For now, console + log file is the primary notification for this early critical error.
    exit 1
fi

WEBHOOK_FILE=".discord_webhook"

if [[ ! -f "$WEBHOOK_FILE" ]]; then
    read -rp "Enter your Discord webhook URL: " user_webhook
    echo "$user_webhook" > "$WEBHOOK_FILE"
fi

DISCORD_WEBHOOK=$(cat "$WEBHOOK_FILE")

notify_discord() {
    local message="$1"
    # Log only a snippet of the message to keep log lines from becoming too long.
    local log_snippet
    log_snippet=$(echo "$message" | head -c 100) # First 100 characters
    log_message "INFO" "Attempting to send Discord notification (first 100 chars): ${log_snippet}..."
    
    local temp_curl_out
    temp_curl_out=$(mktemp) # Create a temporary file to store curl's response body
    
    local http_code
    # Use --fail-with-body: curl exits non-zero on HTTP errors (>=400) AND writes response body.
    # -s for silent, -w "%{http_code}" to get status code on stdout.
    # -o "$temp_curl_out" to write actual response body to the temp file.
    http_code=$(curl --silent --fail-with-body \
         -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK" \
         -w "%{http_code}" \
         --output "$temp_curl_out")
    
    local curl_rc=$? # Capture curl's exit code.
    local response_body 
    response_body=$(cat "$temp_curl_out") # Get the response body
    rm -f "$temp_curl_out" # Clean up the temporary file

    if [[ $curl_rc -ne 0 ]]; then
        # curl failed (network error, or HTTP error >= 400 due to --fail-with-body)
        log_message "ERROR" "Discord notification failed. curl exit code: $curl_rc. HTTP Code: $http_code. Response Body: $response_body. Message snippet: ${log_snippet}..."
    # Check for 2xx success codes. Discord usually sends 204 (No Content) on success.
    elif [[ "$http_code" -ge 200 && "$http_code" -le 299 ]]; then
        log_message "INFO" "Discord notification sent successfully. HTTP Code: $http_code. Message snippet: ${log_snippet}..."
    else
        # Should be rare if --fail-with-body is used, but as a fallback.
        log_message "ERROR" "Discord notification encountered an issue. HTTP Code: $http_code. Response Body: $response_body. Message snippet: ${log_snippet}..."
    fi
}

if [[ ! -f ".webhook_verified" ]]; then
    notify_discord "✅ **Webhook configured successfully!** _(Webhook verification)_"
    if [[ -f "$WEBHOOK_FILE" ]]; then # Check if webhook was actually set
      touch ".webhook_verified"
    fi
fi

notify_discord "🔄 **Subdomain Monitoring Scan Started!**"

while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    notify_discord "🟡 **Scanning:** \`$domain\`"
    log_message "INFO" "Starting scan for domain: $domain."

    output_dir="subspy_results"
    mkdir -p "$output_dir"

    today_list="$output_dir/${domain}-list.txt"
    backup_list="$output_dir/${domain}-list.txt.bak"
    diff_file="$output_dir/${domain}-diff.txt"

    if [ ! -e "$today_list" ]; then
        # Initial scan
        subfinder -d "$domain" -silent ${SUBFINDER_FLAGS} | sort -u > "$today_list"
        subfinder_exit_code=$?
        if [[ $subfinder_exit_code -ne 0 ]]; then
            error_msg="subfinder failed for domain $domain with exit code $subfinder_exit_code." # No "ERROR:" prefix needed, log_message adds it.
            log_message "ERROR" "$error_msg"
            notify_discord "❌ ERROR: $error_msg" # Discord message can have it for emphasis
            continue # Skip to next domain
        fi
        subdomain_count=$(wc -l < "$today_list")
        log_message "INFO" "Initial scan for $domain found $subdomain_count subdomains."
        notify_discord "✅ **Initial scan completed for \`$domain\`: Found $subdomain_count subdomains.**"
    else
        # Subsequent scans
        cp "$today_list" "$backup_list"
        subfinder -d "$domain" -silent ${SUBFINDER_FLAGS} | sort -u > "$today_list"
        subfinder_exit_code=$?
        if [[ $subfinder_exit_code -ne 0 ]]; then
            error_msg="subfinder failed for domain $domain with exit code $subfinder_exit_code."
            log_message "ERROR" "$error_msg"
            notify_discord "❌ ERROR: $error_msg"
            rm -f "$backup_list" # Clean up backup file
            continue # Skip to next domain
        fi

        comm -13 "$backup_list" "$today_list" > "$diff_file"

        new_count=$(wc -l < "$diff_file")

        if [[ "$new_count" -gt 0 ]]; then
            # Log concise list of new domains
            domains_found_loggable=$(tr '\n' ',' < "$diff_file" | sed 's/,$//')
            log_message "INFO" "Found $new_count new subdomains for $domain: $domains_found_loggable."
            
            domains_found_discord=$(sed ':a;N;$!ba;s/\n/\\n/g' "$diff_file") # Keep original format for Discord
            notify_discord "🚨 **New subdomains detected for \`$domain\` ($new_count):**\n\`\`\`\n${domains_found_discord}\n\`\`\`"
        else
            log_message "INFO" "No new subdomains found for $domain."
            notify_discord "✅ **No new subdomains found for \`$domain\`.**"
        fi

        rm -f "$backup_list" "$diff_file"
    fi

    nuclei_output="$output_dir/${domain}-takeover.jsonl"
    nuclei_input_list_log_msg=""

    # Determine which list to use for Nuclei
    nuclei_target_list="$today_list" # Default to all subdomains

    if [[ "$NUCLEI_SCAN_NEW_ONLY_ACTUAL" == "true" && -f "$backup_list" && "$new_count" -gt 0 ]]; then
        # Condition: Scan only new, it's not an initial scan, and there are new subdomains
        nuclei_target_list="$diff_file"
        log_message "INFO" "Nuclei target list for $domain (new only): $nuclei_target_list."
    elif [[ "$NUCLEI_SCAN_NEW_ONLY_ACTUAL" == "true" && -f "$backup_list" && "$new_count" -eq 0 ]]; then
        # Condition: Scan only new is true, not initial scan, but NO new subdomains.
        log_message "INFO" "NUCLEI_SCAN_NEW_ONLY is true for $domain, but no new subdomains were found. Nuclei will scan all current subdomains from $today_list."
        notify_discord "ℹ️ **No new subdomains found for \`$domain\` to scan with Nuclei (NUCLEI_SCAN_NEW_ONLY=true). Scanning all current subdomains instead.**"
        nuclei_target_list="$today_list" # Fall back to today_list
    else
        # Default behavior: initial scan, or NUCLEI_SCAN_NEW_ONLY is false
        nuclei_target_list="$today_list"
        log_message "INFO" "Nuclei target list for $domain (all/initial): $nuclei_target_list."
    fi

    # Run Nuclei only if there are subdomains in the determined target list
    if [[ -s "$nuclei_target_list" ]]; then
        log_message "INFO" "Running Nuclei for $domain with input list $nuclei_target_list."
        nuclei -silent -t http/takeovers/ -jsonl -l "$nuclei_target_list" -o "$nuclei_output" ${NUCLEI_FLAGS} >/dev/null 2>&1
        nuclei_exit_code=$?
        if [[ $nuclei_exit_code -ne 0 ]]; then
            error_msg="nuclei failed for domain $domain (input list: $nuclei_target_list) with exit code $nuclei_exit_code."
            log_message "ERROR" "$error_msg"
            notify_discord "⚠️ ERROR: $error_msg (Potential takeovers might have been missed)"
        else
            log_message "INFO" "Nuclei scan completed for $domain (input list: $nuclei_target_list)."
        fi
    else
        # This case handles when the target list (either today_list or diff_file, if it was chosen) is empty.
        if [[ "$nuclei_target_list" == "$diff_file" ]]; then
            log_message "INFO" "No new subdomains found in $diff_file for domain $domain (NUCLEI_SCAN_NEW_ONLY=true). Skipping Nuclei scan for new subdomains."
            notify_discord "ℹ️ **No new subdomains in \`$diff_file\` for \`$domain\` to scan with Nuclei.**" 
        else # This implies today_list was empty (either initially, or as fallback if NUCLEI_SCAN_NEW_ONLY=true and no new domains)
            log_message "INFO" "No subdomains found in target list $nuclei_target_list for domain $domain. Skipping Nuclei scan."
            # Avoid double notification if NUCLEI_SCAN_NEW_ONLY=true and new_count=0 (already notified)
            if ! ([[ "$NUCLEI_SCAN_NEW_ONLY_ACTUAL" == "true" && -f "$backup_list" && "$new_count" -eq 0 ]]); then
                 notify_discord "ℹ️ **Skipped takeover scan for \`$domain\` as no subdomains were found in the target list ($nuclei_target_list).**"
            fi
        fi
        # Ensure nuclei_output is empty if not run or if the list was empty
        rm -f "$nuclei_output"
        touch "$nuclei_output" # Create empty file so -s check below doesn't fail
    fi

    if [ -s "$nuclei_output" ]; then
        jq -c '.' "$nuclei_output" | while IFS= read -r takeover; do
            subdomain=$(echo "$takeover" | jq -r '.host // empty')
            vulnerability=$(echo "$takeover" | jq -r '.info.name // "Unknown vulnerability"')
            matched_at=$(echo "$takeover" | jq -r '.matched-at // empty') # For more detailed notification

            if [[ -n "$subdomain" && -n "$vulnerability" ]]; then
                log_message "WARN" "Takeover detected: Subdomain: $subdomain, Vulnerability: $vulnerability, Matched-at: $matched_at (Domain: $domain, Input list: $nuclei_target_list)"
                notify_discord "🔥 **Takeover detected!**\n**Domain:** \`$domain\`\n**Subdomain:** \`$subdomain\`\n**Vulnerability:** $vulnerability\n**Matched URL:** \`$matched_at\`"
            fi
        done
    else
        # This block handles when nuclei_output is empty (no takeovers found).
        # Only notify "no vulnerabilities" if Nuclei actually ran successfully AND was supposed to scan something.
        if [[ $nuclei_exit_code -eq 0 ]]; then # Nuclei ran successfully
            if [[ -s "$nuclei_target_list" ]]; then # And it had a non-empty list to scan
                log_message "INFO" "No subdomain takeover vulnerabilities found by Nuclei for $domain (input list: $nuclei_target_list)."
                if [[ "$nuclei_target_list" == "$diff_file" ]]; then
                    notify_discord "✅ **No subdomain takeover vulnerabilities found among NEW subdomains for \`$domain\` (after Nuclei scan on diff).**"
                else # Scanned today_list
                    notify_discord "✅ **No subdomain takeover vulnerabilities found for \`$domain\` (after Nuclei scan on all/existing).**"
                fi
            # else: If nuclei_target_list was empty, specific notifications about skipping were already sent when the list was determined.
            # No need for another "no takeovers found" if nothing meaningful was scanned.
            fi
        # else: If nuclei_exit_code != 0, an error was already logged and notified regarding Nuclei's failure.
        fi
    fi
    log_message "INFO" "Finished scan for domain: $domain."
done < "domains.txt"

log_message "INFO" "Subdomain Monitoring Scan Completed for all domains."
notify_discord "🏁 **Subdomain Monitoring Scan Completed for all domains!**"

log_message "INFO" "SubSpy finished."
