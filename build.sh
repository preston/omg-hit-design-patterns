#!/bin/bash
pandoc -f markdown_mmd -t docx --toc -o build/paper.docx README.md
#pandoc -f markdown_mmd -t epub --toc -o build/index.epub README.md
#pandoc -f markdown_mmd -t html --toc -o build/index.html README.md
#pandoc -f markdown_mmd -t pdf --toc -o build/paper.pdf README.md
