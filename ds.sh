#!/bin/sh

APPINFO="/tmp/webos_menu.json"

# Collect installed apps
apps=$(luna-send -n 1 -w 2000 -a com.webos.applicationManager \
  luna://com.webos.applicationManager/listApps '{}')

# Extract IDs and Titles
ids=$(echo "$apps" | grep -oE '"id":"[^"]*"' | sed -E 's/.*"id":"([^"]+)".*/\1/')
titles=$(echo "$apps" | grep -oE '"title":"[^"]*"' | sed -E 's/.*"title":"([^"]+)".*/\1/')

system_core=""
system_tools=""
official=""
homebrew=""

i=1
while :; do
  id=$(echo "$ids" | sed -n "${i}p")
  title=$(echo "$titles" | sed -n "${i}p")
  [ -z "$id" ] && break

  esc_title=$(printf '%s' "$title" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

  entry=$(cat <<EOF
{
  "label":"$esc_title",
  "onclick":"luna://com.webos.service.applicationManager/launch",
  "params":{"id":"$id"}
}
EOF
)

  case "$id" in
    com.webos.app.settings|com.webos.app.notification*)
      system_tools="$system_tools${system_tools:+,}$entry"
      ;;
    com.webos.*)
      system_core="$system_core${system_core:+,}$entry"
      ;;
    org.webosbrew.*)
      homebrew="$homebrew${homebrew:+,}$entry"
      ;;
    *)
      official="$official${official:+,}$entry"
      ;;
  esac

  i=$((i+1))
done

make_submenu() {
  title="$1"
  buttons="$2"
  [ -z "$buttons" ] && return
  cat <<EOF
{
  "label":"$title",
  "onclick":"luna://com.webos.notification/createAlert",
  "params":{
    "sourceId":"com.webos.service.secondscreen.gateway",
    "title":"$title",
    "message":"Choose an app from $title:",
    "buttons":[
      $buttons,
      { "label":"Back" }
    ]
  }
}
EOF
}

submenu_system_core=$(make_submenu "System Apps" "$system_core")
submenu_system_tools=$(make_submenu "Settings / Tools" "$system_tools")
submenu_official=$(make_submenu "Official Apps" "$official")
submenu_homebrew=$(make_submenu "Homebrew Apps" "$homebrew")

# Final payload -> write to /tmp/webos_menu.json
cat > "$APPINFO" <<EOF
{
  "sourceId":"com.webos.service.secondscreen.gateway",
  "title":"Main Menu",
  "message":"Choose one below:",
  "buttons":[
    {
      "label":"Show Toast",
      "onclick":"luna://com.webos.notification/createToast",
      "params":{"message":"This is a test toast"}
    }
EOF

[ -n "$submenu_system_core" ] && printf ",\n%s" "$submenu_system_core" >> "$APPINFO"
[ -n "$submenu_system_tools" ] && printf ",\n%s" "$submenu_system_tools" >> "$APPINFO"
[ -n "$submenu_official" ] && printf ",\n%s" "$submenu_official" >> "$APPINFO"
[ -n "$submenu_homebrew" ] && printf ",\n%s" "$submenu_homebrew" >> "$APPINFO"

cat >> "$APPINFO" <<EOF
  ]
}
EOF

# Push to TV
luna-send-pub -f -n 1 luna://com.webos.notification/createAlert "$(cat "$APPINFO")"
