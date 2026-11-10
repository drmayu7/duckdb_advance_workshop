#!/usr/bin/env bash
# deck_content_id <root>: the Content id handouts/refresher.pptx shows, so a test
# builds its release with the id the committed decks carry and keeps passing after
# the decks are rebuilt for the next release (docs/agents/releasing-content.md).
deck_content_id() {
  unzip -p "$1/handouts/refresher.pptx" 'ppt/slides/*.xml' 2>/dev/null | perl -pe 's/<[^>]+>//g' \
    | grep -oE 'Content [0-9]{8}-[0-9]{4}' | awk '{ print $2; exit }'
}
