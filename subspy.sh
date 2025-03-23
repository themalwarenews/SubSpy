#!/usr/bin/env bash

cd "$(dirname "$0")"

if [[ ! -f "domains.txt" ]]; then
    echo "domains.txt not found in the current directory."
    exit 1
fi

if [[ -z "$DISCORD_WEBHOOK" ]]; then
    echo "Please set your Discord webhook URL as an environment variable:"
    echo "export DISCORD_WEBHOOK='your_webhook_url'"
    exit 1
fi

# Discord notification function
notify_discord() {
    local message="$1"
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK" >/dev/null
}

# Test webhook on first run only
if [[ ! -f ".webhook_verified" ]]; then
    notify_discord "✅ **Webhook configured successfully!** _(Webhook verification)_"
    touch ".webhook_verified"
fi

notify_discord "🔄 **Subdomain Monitoring Scan Started!**"

while IFS= read -r domain || [[ -n "$domain" ]]; do
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    notify_discord "🟡 **Scanning:** \`$domain\`"

    today_list="${domain}-list.txt"
    backup_list="${domain}-list.txt.bak"
    json_file="${domain}.json"
    diff_file="${domain}-diff.txt"

    if [ ! -e "$today_list" ]; then
        subfinder -d "$domain" -silent -o "$json_file" -oJ >/dev/null
        jq '.host' "$json_file" -r | sort -u > "$today_list"

        subdomain_count=$(wc -l < "$today_list")
        notify_discord "✅ **Initial scan completed for \`$domain\`: Found $subdomain_count subdomains.**"
        continue
    fi

    cp "$today_list" "$backup_list"
    > "$diff_file"

    subfinder -d "$domain" -silent -o "$json_file" -oJ >/dev/null
    jq '.host' "$json_file" -r | sort -u > "$today_list"

    anew -d "$backup_list" < "$today_list" > "$diff_file"

    new_count=$(wc -l < "$diff_file")

    if [[ "$new_count" -gt 0 ]]; then
        domains_found=$(sed ':a;N;$!ba;s/\n/\\n/g' "$diff_file")
        notify_discord "🚨 **New subdomains detected for \`$domain\` ($new_count):**\n\`\`\`\n${domains_found}\n\`\`\`"
    else
        notify_discord "✅ **No new subdomains found for \`$domain\`.**"
    fi

    rm -f "$backup_list" "$diff_file"

done < "domains.txt"

notify_discord "🏁 **Subdomain Monitoring Scan Completed for all domains!**"
