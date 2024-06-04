#!/usr/bin/env bash
set -e

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
 <id>https://rdivyanshu.github.io/</id>
 <title>Blogs</title>
 <link href="https://rdivyanshu.github.io/feed.xml" rel="self"/>
 <link href="https://rdivyanshu.github.io/"/>
EOF
echo " <updated>$(date --iso-8601=seconds)</updated>"
echo " <author><name>Divyanshu Ranjan</name></author>"
for f in $(find mds/ -type f | sort -r | head -n 10); do
    link=$(echo $f | sed 's/\.md$/.html/' | sed 's/mds/posts/')
    date=$(awk 'NR == 3 {print substr($0, 12)}' $f)
    echo " <entry>"
    echo "  <id>https://rdivyanshu.github.io/${link}</id>"
    echo "  <title>$(awk 'NR == 2 {print substr($0, 8)}' $f)</title>"
    echo "  <link href=\"https://rdivyanshu.github.io/${link}\"/>"
    echo "  <updated>$(date --date=$date --iso-8601=seconds)</updated>"
    echo "  <summary>$(awk ' NR == 4 {print substr($0, 19)}' $f)</summary>"
    echo  " </entry>"
done
cat <<EOF
</feed>
EOF
