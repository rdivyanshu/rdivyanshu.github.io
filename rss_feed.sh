#!/usr/bin/env bash
set -e

cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
 <title>Blogs</title>
 <link>https://rdivyanshu.github.io</link>
 <description>Divyanshu Ranjan's blog</description>
EOF
echo " <lastBuildDate>$(date --iso-8601=seconds)</lastBuildDate>"
echo " <pubDate>$(date --iso-8601=seconds)</pubDate>"
echo " <ttl>1800</ttl>"
for f in $(find mds/ -type f | sort -r | head -n 3); do
  echo " <item>"
  echo "  <title>$(awk 'NR == 2 { print substr($0, 8) }' $f)</title>"
  echo "  <description><![CDATA[$(pandoc -s -f markdown+fenced_code_blocks --lua-filter ./rss.lua --to=html5 --css=../../../style.css --template default-rss.html5 $f)]]></description>"
  echo " </item>"
done
cat <<EOF
</channel>
</rss>
EOF
