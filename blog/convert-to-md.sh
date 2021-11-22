# https://gist.github.com/cheungnj/38becf045654119f96c87db829f1be8e

asciidoctor -R _posts/* -D _posts-xml -b docbook

for f in _posts-xml/*.xml; do pandoc "$f" -f docbook -t gfm -o "${f%.xml}.md"; done

mkdir _posts-md && mv _posts-xml/*.md _posts-md/

