find /remotelogs -type f -size +256M -name "syslog" -exec ls -al {} \; | awk -F ' ' '{ print $5, $9 }' | sort -n -r | numfmt --field=1 --to=iec --format "%8f" | sed 's/^[ ][ ]*//g'
