# SPDX-License-Identifier: MIT
# Shared helpers for the synthetic zedlet suites. The library hands every event
# and metric to the local Agent as one DogStatsD datagram on loopback UDP, so
# suites record what a stubbed `nc` received on stdin and decode it here.
#
# Event datagram: _e{<title-bytes>,<text-bytes>}:<title>|<text>|p:<prio>|t:<alert>|s:zfs[|#tag,tag]
# Metric datagram: <name>:<value>|<g|c|h|d>[|#tag,tag]
# Event text keeps the two characters backslash-n exactly as the zedlet wrote
# them; the Agent, not the sender, turns them into newlines.

# Decode an event datagram into {title, text, priority, alert_type, source, tags}.
export def "datagram event" [packet: string]: nothing -> record {
    let framing = ($packet | parse --regex '^_e\{(?<tl>[0-9]+),(?<xl>[0-9]+)\}:' | first)
    let tl = ($framing.tl | into int)
    let xl = ($framing.xl | into int)
    let prefix = ($framing | get tl | str length) + ($framing | get xl | str length) + 6
    let bytes = ($packet | into binary)
    let title = ($bytes | bytes at $prefix..<($prefix + $tl) | decode utf-8)
    let text = ($bytes | bytes at ($prefix + $tl + 1)..<($prefix + $tl + 1 + $xl) | decode utf-8)
    let rest = ($bytes | bytes at ($prefix + $tl + 1 + $xl)..<($bytes | bytes length) | decode utf-8)
    let fields = ($rest | split row '|' | skip 1)
    let tag_field = ($fields | where {|f| $f | str starts-with '#' } | get 0? | default '#')
    {
        title: $title
        text: $text
        priority: ($fields | where {|f| $f | str starts-with 'p:' } | get 0 | str substring 2..)
        alert_type: ($fields | where {|f| $f | str starts-with 't:' } | get 0 | str substring 2..)
        source: ($fields | where {|f| $f | str starts-with 's:' } | get 0 | str substring 2..)
        tags: ($tag_field | str substring 1.. | split row ',' | where {|t| $t != '' })
    }
}

# True for the event datagram a suite's nc stub received (metrics never start with _e{).
export def "datagram is-event" [packet: string]: nothing -> bool {
    $packet | str starts-with '_e{'
}
