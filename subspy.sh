#!/usr/bin/env bash

# Set proper environment for Go-based tools
export PATH="/home/bloxer/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_FILE="/home/bloxer/.subspy-debug.log"
echo "[INFO] SubSpy started by $(whoami) at $(date)" >> "$LOG_FILE"

cd "$(dirname "$0")"

if [[ ! -f "domains.txt" ]]; then
    echo "domains.txt not found in the current directory."
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
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK" >/dev/null
}

if [[ ! -f ".webhook_verified" ]]; then
    notify_discord "✅ **Webhook configured successfully!** _(Webhook verification)_"
    touch ".webhook_verified"
fi

notify_discord "🔄 **Subdomain Monitoring Scan Started!**"

while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    notify_discord "🟡 **Scanning:** \`$domain\`"

    output_dir="subspy_results"
    mkdir -p "$output_dir"

    today_list="$output_dir/${domain}-list.txt"
    backup_list="$output_dir/${domain}-list.txt.bak"
    diff_file="$output_dir/${domain}-diff.txt"

    if [ ! -e "$today_list" ]; then
        subfinder -d "$domain" -silent | sort -u > "$today_list"
        subdomain_count=$(wc -l < "$today_list")
        notify_discord "✅ **Initial scan completed for \`$domain\`: Found $subdomain_count subdomains.**"
    else
        cp "$today_list" "$backup_list"
        subfinder -d "$domain" -silent | sort -u > "$today_list"

        comm -13 "$backup_list" "$today_list" > "$diff_file"

        new_count=$(wc -l < "$diff_file")

        if [[ "$new_count" -gt 0 ]]; then
            domains_found=$(sed ':a;N;$!ba;s/\n/\\n/g' "$diff_file")
            notify_discord "🚨 **New subdomains detected for \`$domain\` ($new_count):**\n\`\`\`\n${domains_found}\n\`\`\`"
        else
            notify_discord "✅ **No new subdomains found for \`$domain\`.**"
        fi

        rm -f "$backup_list" "$diff_file"
    fi

    nuclei_output="$output_dir/${domain}-takeover.jsonl"
    nuclei -silent -t http/takeovers/ -jsonl -l "$today_list" -o "$nuclei_output" >/dev/null 2>&1

    if [ -s "$nuclei_output" ]; then
        jq -c '.' "$nuclei_output" | while IFS= read -r takeover; do
            subdomain=$(echo "$takeover" | jq -r '.host // empty')
            vulnerability=$(echo "$takeover" | jq -r '.info.name // "Unknown vulnerability"')

            if [[ -n "$subdomain" && -n "$vulnerability" ]]; then
                notify_discord "🔥 **Takeover detected!**\n**Subdomain:** \`$subdomain\`\n**Vulnerability:** $vulnerability"
            fi
        done
    else
        notify_discord "✅ **No subdomain takeover vulnerabilities found for \`$domain\`.**"
    fi

done < "domains.txt"

notify_discord "🏁 **Subdomain Monitoring Scan Completed for all domains!**"

echo "[INFO] SubSpy completed at $(date)" >> "$LOG_FILE"
