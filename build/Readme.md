# Generating the docs: 

This directory uses [pandoc]() a universal document converter to build the markdown files into a pdf. Due to regulatory concerns we cannot release a pdf here directly, but you can utilize the following script to build the markdown docs into a pdf so you can use them offline if desired.

In our testing we utilized the macos package manager [homebrew](https://brew.sh/) to install our packages.

## Installing pandoc

After you have homebrew make sure to install mactex:
```bash
brew install mactex
```
Its a huge file but makes compiling everything super easy. Theres probably an equivalent on linux, but idk what it is

Finally install pandoc: [link](https://pandoc.org/installing.html)  
```bash
brew install pandoc
```

### Installing on other platforms
Other operating systems adn their respecitve latex/pandoc packages have not been tested nor will they be supported by LME. Since not every organization will have access to a MacOS operating system, but might wish to compile the docs anyway, please reachout and the team will attempt to help you compile the docs into a pdf. Any operating system with a latex package and pandoc executable should be able to accomplish the job.  There are also many other ways to convert github flavored markdown to pdf if you google for them, and want to compile using a different method than we've provided here.

## Compiling: 
This command below will compile the markdown docs on macos from the homebrew install pandoc/mactex packages:
```bash
pandoc --from gfm --pdf-engine=lualatex -H ./build/setup.tex -V geometry:margin=1in --highlight-style pygments -o docs.pdf -V colorlinks=true -V linkcolor=blue --lua-filter=./build/emoji-filter.lua --lua-filter=./build/makerelativepaths.lua --lua-filter=./build/parse_breaks.lua --table-of-contents --number-sections --wrap=preserve --quiet -s $(cat ./build/includes.txt)
```

On a successful compilation it will output the `docs.pdf` file, a pdf of all the docs. There is a small bug where the `troubleshooting.md` table does not display as expected, so if you want the notes in the table offline, we suggest you record the information manually, OR submit a pull request that fixes this bug :smile:.

### Compiling .docx:
.docx doesn't support emojis, so thats removed from the command
```bash
pandoc --from gfm --pdf-engine=lualatex -H ./build/setup.tex -V geometry:margin=1in --highlight-style pygments -o docs.docx -V colorlinks=true -V linkcolor=blue  --lua-filter=./build/makerelativepaths.lua --lua-filter=./build/parse_breaks.lua --table-of-contents --number-sections --wrap=preserve --quiet -s $(cat ./build/includes.txt)
```

